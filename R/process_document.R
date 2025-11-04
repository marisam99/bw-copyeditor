#' Process Document for Copyediting
#'
#' Main orchestrator function that processes an entire document through the
#' copyediting pipeline. Parses the document, sends each page to OpenAI API,
#' and returns a structured data frame of suggestions.
#'
#' @param file_path Character. Path to the document file (PDF, DOCX, or TXT).
#' @param project_context Character. Project-specific context or background (default: "").
#' @param system_prompt Character. System prompt with style guide embedded.
#'   If NULL, loads from default location or uses built-in default.
#' @param api_key Character. OpenAI API key. If NULL, reads from OPENAI_API_KEY
#'   environment variable.
#' @param model Character. OpenAI model to use (default: "gpt-4").
#' @param temperature Numeric. Sampling temperature (default: 0.3).
#' @param process_pages Integer vector. Specific pages to process. If NULL,
#'   processes all pages (default: NULL).
#' @param verbose Logical. Print progress messages (default: TRUE).
#' @param delay_between_pages Numeric. Delay in seconds between API calls to
#'   avoid rate limits (default: 1).
#'
#' @return A data frame with columns:
#'   \item{page_number}{Integer. Page number where issue was found}
#'   \item{location}{Character. Description of where issue occurs}
#'   \item{original_text}{Character. The problematic text}
#'   \item{suggested_edit}{Character. Proposed correction}
#'   \item{edit_type}{Character. Type of edit (grammar, style, clarity, etc.)}
#'   \item{reason}{Character. Explanation of why edit is needed}
#'   \item{severity}{Character. Importance level (critical, recommended, optional)}
#'   \item{confidence}{Numeric. Confidence score (0-1)}
#'
#' @examples
#' \dontrun{
#'   # Process entire document
#'   results <- process_document(
#'     file_path = "report.pdf",
#'     project_context = "Annual healthcare report for Client X",
#'     api_key = Sys.getenv("OPENAI_API_KEY")
#'   )
#'
#'   # Process specific pages only
#'   results <- process_document(
#'     file_path = "report.pdf",
#'     process_pages = c(1, 2, 5),
#'     project_context = "Annual report"
#'   )
#'
#'   # Export to CSV
#'   write.csv(results, "copyedit_suggestions.csv", row.names = FALSE)
#' }
#'
#' @export
process_document <- function(file_path,
                             project_context = "",
                             system_prompt = NULL,
                             api_key = NULL,
                             model = "gpt-4",
                             temperature = 0.3,
                             process_pages = NULL,
                             verbose = TRUE,
                             delay_between_pages = 1) {

  # Validate file path
  if (!file.exists(file_path)) {
    stop(sprintf("File not found: %s", file_path))
  }

  if (verbose) {
    cat(sprintf("\n=== Bellwether Copyeditor ===\n"))
    cat(sprintf("Processing: %s\n", basename(file_path)))
  }

  # Parse document
  if (verbose) cat("Parsing document...\n")
  doc <- parse_document(file_path)

  if (verbose) {
    cat(sprintf("Document parsed: %d pages\n", doc$total_pages))
  }

  # Determine which pages to process
  if (is.null(process_pages)) {
    pages_to_process <- seq_len(doc$total_pages)
  } else {
    pages_to_process <- process_pages[process_pages <= doc$total_pages]
    if (length(pages_to_process) == 0) {
      stop("No valid pages to process")
    }
  }

  if (verbose) {
    cat(sprintf("Processing %d page(s): %s\n",
                length(pages_to_process),
                paste(pages_to_process, collapse = ", ")))
  }

  # Load system prompt if not provided
  if (is.null(system_prompt)) {
    # Try to load from config directory
    config_path <- file.path("config", "system_prompt.txt")
    if (file.exists(config_path)) {
      if (verbose) cat("Loading system prompt from config/system_prompt.txt\n")
      system_prompt <- load_system_prompt(config_path)
    } else {
      if (verbose) cat("Using default system prompt\n")
      # Will use default in build_prompt()
    }
  }

  # Initialize results list
  all_suggestions <- list()
  api_metadata <- list()

  # Process each page
  for (i in seq_along(pages_to_process)) {
    page_idx <- pages_to_process[i]

    if (verbose) {
      cat(sprintf("\n[%d/%d] Processing page %d...",
                  i, length(pages_to_process), page_idx))
    }

    # Get page text
    page_text <- doc$pages[[page_idx]]

    # Skip empty pages
    if (is.null(page_text) || nchar(trimws(page_text)) == 0) {
      if (verbose) cat(" (empty, skipping)\n")
      next
    }

    # Build prompt
    messages <- build_prompt(
      text_chunk = page_text,
      page_num = page_idx,
      project_context = project_context,
      system_prompt = system_prompt
    )

    # Call API
    tryCatch({
      result <- call_openai_api(
        messages = messages,
        model = model,
        api_key = api_key,
        temperature = temperature
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
        page = page_idx,
        usage = result$usage
      )

    }, error = function(e) {
      if (verbose) {
        cat(sprintf("\nError processing page %d: %s\n", page_idx, e$message))
      }
      warning(sprintf("Failed to process page %d: %s", page_idx, e$message))
    })

    # Add delay between requests to avoid rate limits
    if (i < length(pages_to_process) && delay_between_pages > 0) {
      Sys.sleep(delay_between_pages)
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
  attr(results_df, "pages_processed") <- pages_to_process
  attr(results_df, "model") <- model
  attr(results_df, "api_metadata") <- api_metadata
  attr(results_df, "processed_at") <- Sys.time()

  if (verbose) {
    print_summary(results_df)
  }

  return(results_df)
}


#' Print Summary of Copyediting Results
#'
#' Prints a formatted summary of the copyediting results.
#'
#' @param results_df Data frame. Results from process_document().
#'
#' @keywords internal
print_summary <- function(results_df) {

  if (nrow(results_df) == 0) {
    cat("\nNo issues found! Document looks good.\n")
    return(invisible(NULL))
  }

  cat("\n=== Summary ===\n")

  # By severity
  if ("severity" %in% names(results_df)) {
    cat("\nBy Severity:\n")
    severity_counts <- table(results_df$severity)
    for (sev in names(severity_counts)) {
      cat(sprintf("  %s: %d\n", sev, severity_counts[sev]))
    }
  }

  # By type
  if ("edit_type" %in% names(results_df)) {
    cat("\nBy Type:\n")
    type_counts <- table(results_df$edit_type)
    for (type in names(type_counts)) {
      cat(sprintf("  %s: %d\n", type, type_counts[type]))
    }
  }

  # By page
  if ("page_number" %in% names(results_df)) {
    cat("\nBy Page:\n")
    page_counts <- table(results_df$page_number)
    for (page in names(page_counts)) {
      cat(sprintf("  Page %s: %d\n", page, page_counts[page]))
    }
  }

  cat("\n")
}


#' Export Results to CSV
#'
#' Convenience function to export copyediting results to CSV.
#'
#' @param results_df Data frame. Results from process_document().
#' @param output_path Character. Path for output CSV file.
#' @param include_metadata Logical. Include metadata in separate file (default: TRUE).
#'
#' @return Invisible NULL. Writes files to disk.
#'
#' @examples
#' \dontrun{
#'   results <- process_document("report.pdf")
#'   export_results(results, "copyedit_results.csv")
#' }
#'
#' @export
export_results <- function(results_df, output_path, include_metadata = TRUE) {

  # Export main results
  write.csv(results_df, output_path, row.names = FALSE)
  cat(sprintf("Results exported to: %s\n", output_path))

  # Export metadata if requested
  if (include_metadata && !is.null(attr(results_df, "document_path"))) {

    # Create metadata data frame
    metadata <- data.frame(
      document_path = attr(results_df, "document_path"),
      pages_processed = paste(attr(results_df, "pages_processed"), collapse = ", "),
      model = attr(results_df, "model"),
      total_suggestions = nrow(results_df),
      processed_at = as.character(attr(results_df, "processed_at")),
      stringsAsFactors = FALSE
    )

    # Write metadata
    metadata_path <- sub("\\.csv$", "_metadata.csv", output_path)
    write.csv(metadata, metadata_path, row.names = FALSE)
    cat(sprintf("Metadata exported to: %s\n", metadata_path))
  }

  return(invisible(NULL))
}
