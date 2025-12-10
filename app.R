# ==============================================================================
# Title:        Bellwether Copyeditor Shiny App
# Description:  Interactive web interface for the Bellwether Copyeditor tool.
# ==============================================================================

# Load dependencies ------------------------------------------------------------
 # shiny app tools
library(shiny)
library(DT)
library(shinycssloaders)
library(bslib)
  # required tools
library(here)
library(pdftools)      # PDF extraction
library(tibble)        # Data frames
library(dplyr)         # Data manipulation
library(purrr)         # Functional programming
library(glue)          # String formatting
library(ellmer)        # OpenAI API
library(jsonlite)      # JSON parsing
library(rtiktoken)     # Token counting
library(tools)         # File utilities
  # manually set timeout to 15 minutes (900 seconds) to give reasoning time
options(httr2_timeout = 900)

# Source all required files (skip dependencies.R - packages loaded above)
readRenviron(".Renviron") # sets environment variables
source("config/model_config.R")
source("helpers/01_load_context.R")
source("helpers/02_extract_documents.R")
source("helpers/03_build_prompt_text.R")
source("helpers/03_build_prompt_images.R")
source("helpers/04_call_openai_api.R")
source("helpers/05_process_results.R")

# UI ---------------------------------------------------------------------------

ui <- page_sidebar(
  title = "BW Copyeditor",
  theme = bs_theme(version = 5, bootswatch = "flatly"),

  # Sidebar with inputs
  sidebar = sidebar(
    width = 350,

    h4("Document Upload"),
    fileInput(
      "pdf_file",
      "Select PDF File:",
      accept = c(".pdf", "application/pdf"),
      placeholder = "No file selected"
    ),

    hr(),

    h4("Document Context"),
    textInput(
      "doc_type",
      "Document Type:",
      placeholder = "e.g., client-facing grant report, case study for publication"
    ),

    textInput(
      "audience",
      "Target Audience:",
      placeholder = "e.g., CMO leaders, state policymakers"
    ),

    hr(),

    h4("Processing Mode"),
    radioButtons(
      "mode",
      NULL,
      choices = c(
        "Text Mode (reports, publications)" = "text",
        "Image Mode (slide decks, visuals)" = "images"
      ),
      selected = "text"
    ),

    hr(),

    actionButton(
      "process",
      "Process Document",
      class = "btn-primary btn-lg",
      width = "100%"
    ),

    br(), br(),

    uiOutput("file_info")
  ),

  # Main panel with tabbed interface
  navset_card_tab(
    id = "main_tabs",

    # Tab 1: Instructions
    nav_panel(
      "Instructions",
      includeMarkdown("app_instructions.md")
    ),

    # Tab 2: Copyeditor
    nav_panel(
      "Copyeditor",
      uiOutput("status_message"),

      # Collapsible process log
      accordion(
        accordion_panel(
          "Processing Log",
          tags$div(
            id = "process_log",
            style = "white-space: pre-wrap; font-family: monospace; max-height: 400px; overflow-y: auto; padding: 10px; background-color: #f8f9fa;"
          ),
          icon = icon("list-check")
        ),
        id = "log_accordion",
        open = TRUE  # Start open so user can see processing immediately
      ),

      # JavaScript to handle real-time log updates
      tags$script(HTML("
        Shiny.addCustomMessageHandler('append_log', function(message) {
          var logDiv = document.getElementById('process_log');
          logDiv.innerHTML += message;
          // Auto-scroll to bottom
          logDiv.scrollTop = logDiv.scrollHeight;
        });

        Shiny.addCustomMessageHandler('clear_log', function(message) {
          var logDiv = document.getElementById('process_log');
          logDiv.innerHTML = '';
        });

        Shiny.addCustomMessageHandler('open_log_accordion', function(message) {
          // Find the accordion button and collapse element
          var accordionButton = document.querySelector('#log_accordion .accordion-button');
          var accordionCollapse = document.querySelector('#log_accordion .accordion-collapse');

          if (accordionButton && accordionCollapse) {
            // If not already open, open it
            if (!accordionCollapse.classList.contains('show')) {
              accordionButton.click();
            }
          }
        });

        Shiny.addCustomMessageHandler('switch_to_copyeditor', function(message) {
          // Find and click the Copyeditor tab
          var copyeditorTab = document.querySelector('a[data-value=\"Copyeditor\"]');
          if (copyeditorTab) {
            copyeditorTab.click();
          }
        });
      ")),

      br(),

      # Results table
      withSpinner(
        DTOutput("results_table"),
        type = 6,
        color = "#007bff"
      ),

      br(),
      downloadButton("download_csv", "Download Results as CSV", class = "btn-success")
    )
  )
)

# Server -----------------------------------------------------------------------

server <- function(input, output, session) {

  # Reactive values
  results_data <- reactiveVal(NULL)
  processing_status <- reactiveVal("Upload a PDF to begin")

  # Helper function to add message to log in real-time
  add_log_message <- function(msg) {
    timestamp <- format(Sys.time(), "[%H:%M:%S]")
    formatted_msg <- paste0(timestamp, " ", msg, "\n")
    # Send to JavaScript for immediate display
    session$sendCustomMessage("append_log", formatted_msg)
  }

  # File info display
  output$file_info <- renderUI({
    req(input$pdf_file)

    file_info <- input$pdf_file
    file_size_mb <- round(file_info$size / 1024 / 1024, 2)

    div(
      style = "padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
      h5("Uploaded File"),
      p(strong("Name: "), basename(file_info$name)),
      p(strong("Size: "), paste0(file_size_mb, " MB"))
    )
  })

  # Validation happens in observeEvent with req()

  # Process document when button clicked
  observeEvent(input$process, {
    req(input$pdf_file)
    req(input$doc_type)
    req(input$audience)

    # Switch to Copyeditor tab using JavaScript (bypasses Shiny batching)
    session$sendCustomMessage("switch_to_copyeditor", TRUE)

    # Clear previous results and messages
    results_data(NULL)
    session$sendCustomMessage("clear_log", "")

    # Show progress
    withProgress(message = "Processing document...", value = 0, {

      tryCatch({
        # Get file path from upload
        file_path <- input$pdf_file$datapath

        # Validate it's a PDF
        file_ext <- tolower(tools::file_ext(input$pdf_file$name))
        if (file_ext != "pdf") {
          add_log_message("⚠️ Error: Only PDF files are supported")
          showNotification(
            "Only PDF files are supported. Please upload a PDF file.",
            type = "error",
            duration = 5
          )
          return(NULL)
        }

        # Extract document
        incProgress(0.1, detail = "Extracting document content...")
        add_log_message("⏳ Extracting document content...")

        extracted_doc <- if (input$mode == "text") {
          extract_to_text(file_path)
        } else {
          extract_to_images(file_path)
        }

        total_pages <- nrow(extracted_doc)
        add_log_message(sprintf("📄 Document extracted: %d pages", total_pages))

        # Build prompts
        incProgress(0.2, detail = paste("Preparing", total_pages, "pages..."))
        add_log_message(sprintf("⏳ Preparing %d pages to send to AI model", total_pages))

        # Capture stdout and stderr from build_prompt functions
        message_output <- capture.output({
          user_message_chunks <- if (input$mode == "text") {
            build_prompt_text(
              extracted_document = extracted_doc,
              document_type = input$doc_type,
              audience = input$audience
            )
          } else {
            build_prompt_images(
              extracted_document = extracted_doc,
              document_type = input$doc_type,
              audience = input$audience
            )
          }
        }, type = "message")

        # Add captured messages to log
        for (msg in message_output) {
          if (nchar(trimws(msg)) > 0) {
            add_log_message(msg)
          }
        }

        # Process chunks
        num_chunks <- nrow(user_message_chunks)
        all_suggestions <- list()

        for (i in seq_len(num_chunks)) {
          chunk <- user_message_chunks[i, ]

          incProgress(
            0.6 / num_chunks,
            detail = sprintf("Processing chunk %d/%d (pages %d-%d)...",
                           i, num_chunks, chunk$page_start, chunk$page_end)
          )

          # Log chunk processing
          if (num_chunks > 1) {
            add_log_message(sprintf("⏳ [Chunk %d/%d] Sending pages %d-%d...",
                                   i, num_chunks, chunk$page_start, chunk$page_end))
          } else {
            add_log_message(sprintf("⏳ Sending pages %d-%d...",
                                   chunk$page_start, chunk$page_end))
          }

          # Call API based on mode
          result <- if (input$mode == "text") {
            call_openai_api_text(user_message = chunk$user_message)
          } else {
            call_openai_api_images(user_content = chunk$user_message[[1]])
          }

          # Collect suggestions and log results
          if (!is.null(result$suggestions) && length(result$suggestions) > 0) {
            all_suggestions <- c(all_suggestions, result$suggestions)
            add_log_message(sprintf("   ✓ %d suggestion(s) found", length(result$suggestions)))
          } else {
            add_log_message("   ✓ No issues found")
          }
        }

        # Format results
        incProgress(0.1, detail = "Formatting results...")
        add_log_message("⏳ Formatting results...")
        results_df <- format_results(all_suggestions)

        # Store results
        results_data(results_df)

        # Show success message
        if (nrow(results_df) > 0) {
          add_log_message(sprintf("✅ Processing complete! Found %d suggestions", nrow(results_df)))
          processing_status(sprintf("✅ Found %d suggestion(s)", nrow(results_df)))
          showNotification(
            sprintf("Processing complete! Found %d suggestions.", nrow(results_df)),
            type = "message",
            duration = 5
          )
        } else {
          add_log_message("🎉 Processing complete! No issues found")
          processing_status("🎉 No issues found!")
          showNotification(
            "Processing complete! No copyediting issues found.",
            type = "message",
            duration = 5
          )
        }

      }, error = function(e) {
        add_log_message(sprintf("⚠️ Error: %s", e$message))
        processing_status(paste("⚠️ Error:", e$message))
        showNotification(
          paste("Error:", e$message),
          type = "error",
          duration = 10
        )
      })
    })
  })

  # Display status message
  output$status_message <- renderUI({
    div(
      style = "padding: 15px; margin-bottom: 15px; background-color: #f8f9fa; border-radius: 5px;",
      h5(processing_status())
    )
  })

  # Display results table
  output$results_table <- renderDT({
    req(results_data())

    df <- results_data()

    # Format severity column with colors
    df$severity <- factor(df$severity, levels = c("critical", "recommended", "optional"))

    # Columns: page_number(0), issue(1), original_text(2), suggested_edit(3),
    #          rationale(4), severity(5), confidence(6), is_valid(7)
    datatable(
      df,
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        order = list(list(0, "asc"), list(5, "desc")), # Sort by page, then severity
        columnDefs = list(
          list(visible = FALSE, targets = 7) # Hide is_valid column (0-indexed)
        )
      ),
      rownames = FALSE,
      filter = "top"
    ) %>%
      formatStyle(
        "severity",
        backgroundColor = styleEqual(
          c("critical", "recommended", "optional"),
          c("#f8d7da", "#fff3cd", "#d1ecf1")
        )
      )
  })

  # Download handler
  output$download_csv <- downloadHandler(
    filename = function() {
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      paste0("copyedit_results_", timestamp, ".csv")
    },
    content = function(file) {
      req(results_data())
      write.csv(results_data(), file, row.names = FALSE)
    }
  )

}

# ==============================================================================
# Run App
# ==============================================================================

shinyApp(ui, server)
