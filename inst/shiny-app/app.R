# ==============================================================================
# BW Copyeditor Shiny App
# ==============================================================================
# Interactive web interface for the BW Copyeditor package

# Load dependencies
# Note: In deployed app, packages are loaded from the package itself
# For local development, ensure dependencies.R is sourced
if (!requireNamespace("shiny", quietly = TRUE)) {
  stop("Please install required packages. Run: install.packages(c('shiny', 'DT', 'shinycssloaders', 'bslib'))")
}

library(shiny)
library(DT)
library(shinycssloaders)
library(bslib)

# Load package functions
# When running from installed package, these will be available
# For development, we'll source them directly
pkg_root <- system.file(package = "bwcopyeditor")
if (pkg_root == "") {
  # Development mode - find project root
  # When Shiny runs the app, it may set different working directories
  # Try to find the project root by looking for the DESCRIPTION file

  # Start from current working directory and go up
  current_dir <- getwd()
  project_root <- NULL

  # Try up to 5 levels up
  for (i in 0:5) {
    test_dir <- normalizePath(file.path(current_dir, paste(rep("..", i), collapse = "/")))
    if (file.exists(file.path(test_dir, "DESCRIPTION")) &&
        file.exists(file.path(test_dir, "config", "system_prompt.txt"))) {
      project_root <- test_dir
      break
    }
  }

  if (is.null(project_root)) {
    stop("Could not find project root. Please ensure you're running from within the bw-copyeditor project.")
  }

  pkg_root <- project_root

  # Save current directory and change to project root for sourcing
  original_wd <- getwd()
  setwd(pkg_root)

  source("config/dependencies.R")
  source("config/model_config.R")
  source("R/load_context.R")
  source("R/extract_documents.R")
  source("R/build_prompt_text.R")
  source("R/build_prompt_images.R")
  source("R/call_openai_api.R")
  source("R/process_results.R")

  # Restore original directory
  setwd(original_wd)
}

# ==============================================================================
# UI
# ==============================================================================

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
      placeholder = "e.g., External client-facing report"
    ),

    textInput(
      "audience",
      "Target Audience:",
      placeholder = "e.g., Healthcare executives"
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

  # Main panel with results
  card(
    card_header("Copyediting Suggestions"),
    card_body(
      uiOutput("status_message"),
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

# ==============================================================================
# Server
# ==============================================================================

server <- function(input, output, session) {

  # Reactive values
  results_data <- reactiveVal(NULL)
  processing_status <- reactiveVal("Upload a PDF to begin")

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

    # Clear previous results
    results_data(NULL)

    # Show progress
    withProgress(message = "Processing document...", value = 0, {

      tryCatch({
        # Get file path from upload
        file_path <- input$pdf_file$datapath

        # Validate it's a PDF
        file_ext <- tolower(tools::file_ext(input$pdf_file$name))
        if (file_ext != "pdf") {
          showNotification(
            "Only PDF files are supported. Please upload a PDF file.",
            type = "error",
            duration = 5
          )
          return(NULL)
        }

        # Extract document
        incProgress(0.1, detail = "Extracting document content...")
        extracted_doc <- if (input$mode == "text") {
          extract_to_text(file_path)
        } else {
          extract_to_images(file_path)
        }

        total_pages <- nrow(extracted_doc)

        # Build prompts
        incProgress(0.2, detail = paste("Preparing", total_pages, "pages..."))
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

          # Call API based on mode
          result <- if (input$mode == "text") {
            call_openai_api_text(user_message = chunk$user_message)
          } else {
            call_openai_api_images(user_content = chunk$user_message[[1]])
          }

          # Collect suggestions
          if (!is.null(result$suggestions) && length(result$suggestions) > 0) {
            all_suggestions <- c(all_suggestions, result$suggestions)
          }
        }

        # Format results
        incProgress(0.1, detail = "Formatting results...")
        results_df <- format_results(all_suggestions)

        # Store results
        results_data(results_df)

        # Show success message
        if (nrow(results_df) > 0) {
          processing_status(sprintf("✅ Found %d suggestion(s)", nrow(results_df)))
          showNotification(
            sprintf("Processing complete! Found %d suggestions.", nrow(results_df)),
            type = "message",
            duration = 5
          )
        } else {
          processing_status("🎉 No issues found!")
          showNotification(
            "Processing complete! No copyediting issues found.",
            type = "message",
            duration = 5
          )
        }

      }, error = function(e) {
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

    datatable(
      df,
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        order = list(list(0, "asc"), list(6, "desc")), # Sort by page, then severity
        columnDefs = list(
          list(visible = FALSE, targets = 8) # Hide is_valid column
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
