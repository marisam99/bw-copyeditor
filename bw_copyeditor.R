# ==============================================================================
# Title:        Document Processor
# Description:  Main orchestrator function for the copyediting pipeline.
#               Supports both text and image modes. Extracts PDF documents,
#               builds prompts with automatic chunking, calls OpenAI API,
#               and returns structured copyediting suggestions.
# ==============================================================================

# Configurations -------------------------------------------------------------
source("config/dependencies.R")
source("config/model_config.R")
source("helpers/01_load_context.R")
source("helpers/02_extract_documents.R")
source("helpers/03_build_prompt_text.R")
source("helpers/03_build_prompt_images.R")
source("helpers/04_call_openai_api.R")
source("helpers/05_process_results.R")

# Main Function ---------------------------------------------------------------

#' Process Document for Copyediting
#'
#' Main function that processes a PDF through the copyediting pipeline.
#' Opens a file picker, extracts content, sends to API, and returns results.
#'
#' @param mode Processing mode: "text" (default) or "images".
#'   Text mode: For reports and publications.
#'   Images mode: For slide decks with visuals.
#' @param document_type Type of document (e.g., "external client-facing", "internal").
#' @param audience Target audience description.
#' @return Table with page_number, issue, original_text, suggested_edit, rationale, severity, confidence, and is_valid.
#'
#' @examples
#' \dontrun{
#'   # Process a report
#'   results <- process_document(
#'     mode = "text",
#'     document_type = "external client-facing",
#'     audience = "Healthcare executives"
#'   )
#'
#'   # Process a slide deck
#'   results <- process_document(
#'     mode = "images",
#'     document_type = "internal",
#'     audience = "Leadership team"
#'   )
#' }
#'
#' @export
copyedit_document <- function(mode = c("text", "images"),
                             document_type,
                             audience) {

  # Match and validate mode argument
  mode <- match.arg(mode)

  # Validate inputs
  if (missing(document_type) || is.null(document_type) || nchar(trimws(document_type)) == 0) {
    stop("document_type is required. For more information, see the README.md.")
  }

  if (missing(audience) || is.null(audience) || nchar(trimws(audience)) == 0) {
    stop("audience is required. For more information, see the README.md.")
  }

  message(sprintf("\n=== Bellwether Copyeditor ===\n"))
  message(sprintf("Mode: %s", mode))
  message(sprintf("Document type: %s", document_type))
  message(sprintf("Audience: %s\n", audience))

  # Extract document (file picker opens in extract_document)
  message("⏳ Waiting for file upload...\n")
  extracted_doc <- extract_document(mode = mode)

  # Extract file path from extracted document
  file_path <- attr(extracted_doc, "file_path")

  total_pages <- nrow(extracted_doc)
  message(sprintf("\nDocument extracted: %d pages\n", total_pages))

  # Build user messages (with automatic chunking if needed)
  message(sprintf("⏳ Preparing %d pages to send to API\n", total_pages))
  if (mode == "text") {
    user_message_chunks <- build_prompt_text(
      extracted_document = extracted_doc,
      document_type = document_type,
      audience = audience
    )
  } else {
    user_message_chunks <- build_prompt_images(
      extracted_document = extracted_doc,
      document_type = document_type,
      audience = audience
    )
  }

  # Initialize results list
  all_suggestions <- list()
  api_metadata <- list()

  # Process each chunk
  num_chunks <- nrow(user_message_chunks)
  for (i in seq_len(num_chunks)) {
    chunk <- user_message_chunks[i, ]

    # Show different messages for single vs multi-chunk
    if (num_chunks > 1) {
      message(sprintf("\n⏳ [Chunk %d/%d] Sending pages %d-%d...",
                  i, num_chunks,
                  chunk$page_start, chunk$page_end))
    } else {
      message(sprintf("\n⏳ Sending pages %d-%d...",
                  chunk$page_start, chunk$page_end))
    }

    # Call API based on mode
    tryCatch({
      if (mode == "text") {
        result <- call_openai_api_text(
          user_message = chunk$user_message
        )
      } else {
        # Use [[1]] to unwrap the list from the tibble list-column
        result <- call_openai_api_images(
          user_content = chunk$user_message[[1]]
        )
      }

      # Store suggestions
      if (!is.null(result$suggestions) && length(result$suggestions) > 0) {
        all_suggestions <- c(all_suggestions, result$suggestions)
        message(sprintf(" %d suggestion(s) found", length(result$suggestions)))
      } else {
        message(" No issues found")
      }

      # Store metadata
      api_metadata[[length(api_metadata) + 1]] <- list(
        chunk_id = chunk$chunk_id,
        page_start = chunk$page_start,
        page_end = chunk$page_end,
        usage = result$usage
      )

    }, error = function(e) {
      warning(sprintf("⚠️ Failed to process chunk %d (pages %d-%d): %s",
                     i, chunk$page_start, chunk$page_end, e$message))
    })
  }

  message(sprintf("\n✅ Processing complete!\n"))

  # Convert to data frame
  results_df <- format_results(all_suggestions)

  # Add metadata as attributes
  attr(results_df, "file_path") <- file_path
  attr(results_df, "mode") <- mode
  attr(results_df, "document_type") <- document_type
  attr(results_df, "audience") <- audience
  attr(results_df, "pages_processed") <- seq_len(total_pages)
  attr(results_df, "num_chunks") <- num_chunks
  attr(results_df, "model") <- if (mode == "text") MODEL_TEXT else MODEL_IMAGES
  attr(results_df, "api_metadata") <- api_metadata
  attr(results_df, "processed_at") <- Sys.time()

  print_summary(results_df)

  # Auto-export results to CSV
  if (nrow(results_df) > 0) {
    base_name <- file_path_sans_ext(basename(file_path))
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    output_filename <- sprintf("%s_copyedit_%s.csv", base_name, timestamp)

    export_results(results_df, output_filename = output_filename)
  }

  return(results_df)
}
