# ==============================================================================
# Title:        Document Processor (Text Mode)
# Last Updated: 2025-11-13
# Description:  Main orchestrator function for text-mode copyediting pipeline.
#               Parses PDF documents, builds prompts with automatic chunking,
#               calls OpenAI API, and returns structured copyediting suggestions.
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
#' @param file_path Character. Path to the document file (PDF only).
#' @param document_type Character. Type of document (e.g., "external field-facing",
#'   "external client-facing", "internal").
#' @param audience Character. Description of the target audience.
#' @param context_window Integer. Maximum tokens per API call (default: CONTEXT_WINDOW_TEXT from config/model_config.R).
#' @param process_pages Integer vector. Specific pages to process. If NULL,
#'   processes all pages (default: NULL).
#' @param verbose Logical. Print progress messages (default: TRUE).
#' @param delay_between_chunks Numeric. Delay in seconds between API calls to
#'   avoid rate limits (default: 1).
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
#'   # Process entire document (requires OPENAI_API_KEY environment variable)
#'   results <- process_document(
#'     file_path = "report.pdf",
#'     document_type = "external client-facing",
#'     audience = "Healthcare executives"
#'   )
#'
#'   # Process specific pages only
#'   results <- process_document(
#'     file_path = "report.pdf",
#'     document_type = "internal",
#'     audience = "Data science team",
#'     process_pages = c(1, 2, 5)
#'   )
#'
#'   # Export to CSV
#'   write.csv(results, "copyedit_suggestions.csv", row.names = FALSE)
#' }
#'
#' @export
process_document <- function(file_path,
                             document_type,
                             audience,
                             context_window = CONTEXT_WINDOW_TEXT,
                             process_pages = NULL,
                             verbose = TRUE,
                             delay_between_chunks = 1) {

  # Validate inputs
  if (!file.exists(file_path)) {
    stop(sprintf("File not found: %s", file_path))
  }

  if (missing(document_type) || is.null(document_type) || nchar(trimws(document_type)) == 0) {
    stop("document_type is required")
  }

  if (missing(audience) || is.null(audience) || nchar(trimws(audience)) == 0) {
    stop("audience is required")
  }

  if (verbose) {
    cat(sprintf("\n=== Bellwether Copyeditor ===\n"))
    cat(sprintf("Processing: %s\n", basename(file_path)))
    cat(sprintf("Document type: %s\n", document_type))
    cat(sprintf("Audience: %s\n", audience))
  }

  # Parse document
  if (verbose) cat("\nParsing document...\n")
  parsed_doc <- parse_document(file_path, mode = "text")

  total_pages <- nrow(parsed_doc)
  if (verbose) {
    cat(sprintf("Document parsed: %d pages\n", total_pages))
  }

  # Filter pages if specified
  if (!is.null(process_pages)) {
    valid_pages <- process_pages[process_pages <= total_pages & process_pages > 0]
    if (length(valid_pages) == 0) {
      stop("No valid pages to process")
    }

    parsed_doc <- parsed_doc[parsed_doc$page_number %in% valid_pages, ]

    if (verbose) {
      cat(sprintf("Processing %d page(s): %s\n",
                  nrow(parsed_doc),
                  paste(sort(parsed_doc$page_number), collapse = ", ")))
    }
  } else {
    if (verbose) {
      cat(sprintf("Processing all %d pages\n", total_pages))
    }
  }

  # Load system prompt
  if (verbose) cat("Loading system prompt from config/system_prompt.txt\n")
  system_prompt <- load_system_prompt()

  # Build user messages (with automatic chunking if needed)
  if (verbose) cat("Building user messages...\n")
  user_message_chunks <- build_prompt_text(
    parsed_document = parsed_doc,
    deliverable_type = document_type,
    audience = audience
  )

  num_chunks <- nrow(user_message_chunks)
  if (verbose && num_chunks > 1) {
    cat(sprintf("Document split into %d chunks\n", num_chunks))
  }

  # Initialize results list
  all_suggestions <- list()
  api_metadata <- list()

  # Process each chunk
  for (i in seq_len(num_chunks)) {
    chunk <- user_message_chunks[i, ]

    if (verbose) {
      cat(sprintf("\n[Chunk %d/%d] Pages %d-%d...",
                  i, num_chunks,
                  chunk$page_start, chunk$page_end))
    }

    # Call API
    tryCatch({
      result <- call_openai_api(
        user_message = chunk$user_message,
        system_prompt = system_prompt
      )

      # Store suggestions
      if (!is.null(result$suggestions) && length(result$suggestions) > 0) {
        all_suggestions <- c(all_suggestions, result$suggestions)
        if (verbose) {
          cat(sprintf(" %d suggestion(s) found", length(result$suggestions)))
        }
      } else {
        if (verbose) cat(" No issues found")
      }

      # Store metadata
      api_metadata[[length(api_metadata) + 1]] <- list(
        chunk_id = chunk$chunk_id,
        page_start = chunk$page_start,
        page_end = chunk$page_end,
        usage = result$usage
      )

    }, error = function(e) {
      if (verbose) {
        cat(sprintf("\nError processing chunk %d: %s\n", i, e$message))
      }
      warning(sprintf("Failed to process chunk %d (pages %d-%d): %s",
                     i, chunk$page_start, chunk$page_end, e$message))
    })

    # Add delay between requests to avoid rate limits
    if (i < num_chunks && delay_between_chunks > 0) {
      Sys.sleep(delay_between_chunks)
    }
  }

  if (verbose) {
    cat(sprintf("\n\nProcessing complete!\n"))
    cat(sprintf("Total suggestions: %d\n", length(all_suggestions)))
  }

  # Convert to data frame
  results_df <- format_results(all_suggestions)

  # Add metadata as attributes
  attr(results_df, "document_path") <- file_path
  attr(results_df, "document_type") <- document_type
  attr(results_df, "audience") <- audience
  attr(results_df, "pages_processed") <- if (!is.null(process_pages)) process_pages else seq_len(total_pages)
  attr(results_df, "num_chunks") <- num_chunks
  attr(results_df, "model") <- MODEL_TEXT  # Model used for text-mode copyediting (from config/model_config.R)
  attr(results_df, "api_metadata") <- api_metadata
  attr(results_df, "processed_at") <- Sys.time()

  if (verbose) {
    print_summary(results_df)
  }

  return(results_df)
}
