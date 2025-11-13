# ==============================================================================
# Title:        Document Processor
# Last Updated: 2025-11-13
# Description:  Main orchestrator function for the copyediting pipeline.
#               Supports both text and image modes. Parses PDF documents,
#               builds prompts with automatic chunking, calls OpenAI API,
#               and returns structured copyediting suggestions.
# ==============================================================================

# Load configuration ----------------------------------------------------------
source(file.path("config", "model_config.R"))


# Main Function ---------------------------------------------------------------

#' Process Document for Copyediting
#'
#' Main orchestrator function that processes an entire document through the
#' copyediting pipeline. Parses the document, builds prompts with automatic
#' chunking if needed, sends to OpenAI API, and returns a structured data frame.
#'
#' @param mode Character. Processing mode: "text" (default) or "images".
#'   Use "text" for text-heavy documents (reports, publications).
#'   Use "images" for visual-heavy documents (slide decks, presentations).
#' @param document_type Character. Type of document (e.g., "external field-facing",
#'   "external client-facing", "internal").
#' @param audience Character. Description of the target audience.
#'
#' @return A data frame with columns:
#'   \item{page_number}{Integer. Page number where issue was found}
#'   \item{issue}{Character. Brief description of the issue}
#'   \item{original_text}{Character. The problematic text}
#'   \item{suggested_edit}{Character. Proposed correction}
#'   \item{rationale}{Character. Explanation of why edit is needed}
#'   \item{severity}{Character. Importance level (critical, recommended, optional)}
#'   \item{confidence}{Numeric. Confidence score (0-1)}
#'   \item{is_valid}{Logical. TRUE if row has required fields}
#'
#' @examples
#' \dontrun{
#'   # Text mode (default) - for reports/publications
#'   results <- process_document(
#'     mode = "text",
#'     document_type = "external client-facing",
#'     audience = "Healthcare executives"
#'   )
#'
#'   # Image mode - for slide decks
#'   results <- process_document(
#'     mode = "images",
#'     document_type = "external client-facing",
#'     audience = "Healthcare executives"
#'   )
#'
#'   # Export results
#'   export_results(results, "copyedit_results.csv")
#' }
#'
#' @export
process_document <- function(mode = c("text", "images"),
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

  cat(sprintf("\n=== Bellwether Copyeditor ===\n"))
  cat(sprintf("Mode: %s\n", mode))
  cat(sprintf("Document type: %s\n", document_type))
  cat(sprintf("Audience: %s\n", audience))

  # Parse document (file picker opens in parse_document)
  cat("\nWaiting for file upload...\n")
  parsed_doc <- parse_document(mode = mode)

  # Extract file path from parsed document
  file_path <- attr(parsed_doc, "file_path")

  total_pages <- nrow(parsed_doc)
  cat(sprintf("Document parsed: %d pages\n", total_pages))
  cat(sprintf("Processing all %d pages\n", total_pages))

  # Load system prompt (used by both text and image modes)
  cat("Loading system prompt from config/system_prompt.txt\n")
  system_prompt <- load_system_prompt()

  # Build user messages (with automatic chunking if needed)
  cat("Building user messages...\n")
  if (mode == "text") {
    user_message_chunks <- build_prompt_text(
      parsed_document = parsed_doc,
      deliverable_type = document_type,
      audience = audience
    )
  } else {
    user_message_chunks <- build_prompt_images(
      parsed_document = parsed_doc,
      deliverable_type = document_type,
      audience = audience
    )
  }

  num_chunks <- nrow(user_message_chunks)
  if (num_chunks > 1) {
    cat(sprintf("Document split into %d chunks\n", num_chunks))
  }

  # Initialize results list
  all_suggestions <- list()
  api_metadata <- list()

  # Process each chunk
  for (i in seq_len(num_chunks)) {
    chunk <- user_message_chunks[i, ]

    cat(sprintf("\n[Chunk %d/%d] Pages %d-%d...",
                i, num_chunks,
                chunk$page_start, chunk$page_end))

    # Call API based on mode
    tryCatch({
      if (mode == "text") {
        result <- call_openai_api(
          user_message = chunk$user_message,
          system_prompt = system_prompt
        )
      } else {
        result <- call_openai_api_images(
          user_content = chunk$user_message,
          system_prompt = system_prompt
        )
      }

      # Store suggestions
      if (!is.null(result$suggestions) && length(result$suggestions) > 0) {
        all_suggestions <- c(all_suggestions, result$suggestions)
        cat(sprintf(" %d suggestion(s) found", length(result$suggestions)))
      } else {
        cat(" No issues found")
      }

      # Store metadata
      api_metadata[[length(api_metadata) + 1]] <- list(
        chunk_id = chunk$chunk_id,
        page_start = chunk$page_start,
        page_end = chunk$page_end,
        usage = result$usage
      )

    }, error = function(e) {
      cat(sprintf("\nError processing chunk %d: %s\n", i, e$message))
      warning(sprintf("Failed to process chunk %d (pages %d-%d): %s",
                     i, chunk$page_start, chunk$page_end, e$message))
    })
  }

  cat(sprintf("\n\nProcessing complete!\n"))

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

  return(results_df)
}
