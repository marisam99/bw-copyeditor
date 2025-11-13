# ==============================================================================
# Title:        Result Formatter
# Last Updated: 2025-11-13
# Description:  Functions to format, display, and export copyediting suggestions
#               from LLM API responses into clean, structured data frames.
# ==============================================================================


# Helper Functions ------------------------------------------------------------

#' Create Empty Results Data Frame
#'
#' Creates an empty tibble with the correct structure.
#'
#' @return Empty tibble with proper column types.
#' @keywords internal
create_empty_results_df <- function() {
  tibble::tibble(
    page_number = integer(0),
    issue = character(0),
    original_text = character(0),
    suggested_edit = character(0),
    rationale = character(0),
    severity = character(0),
    confidence = numeric(0),
    is_valid = logical(0)
  )
}


#' Convert List to Data Frame
#'
#' Converts nested API list to flat tibble.
#'
#' @param suggestions_list List of suggestions.
#' @return Tibble with suggestion data.
#' @keywords internal
convert_list_to_df <- function(suggestions_list) {

  # Extract each suggestion using purrr
  rows <- purrr::map(suggestions_list, function(suggestion) {

    # Handle both flat and nested structures
    if (is.list(suggestion)) {
      # Extract fields with defaults using purrr::pluck
      tibble::tibble(
        page_number = as.integer(purrr::pluck(suggestion, "page_number", .default = NA)),
        issue = as.character(purrr::pluck(suggestion, "issue", .default = "")),
        original_text = as.character(purrr::pluck(suggestion, "original_text", .default = "")),
        suggested_edit = as.character(purrr::pluck(suggestion, "suggested_edit", .default = "")),
        rationale = as.character(purrr::pluck(suggestion, "rationale", .default = "")),
        severity = as.character(purrr::pluck(suggestion, "severity", .default = "recommended")),
        confidence = as.numeric(purrr::pluck(suggestion, "confidence", .default = 0.5))
      )
    } else {
      # Skip invalid entries
      NULL
    }
  })

  # Remove NULL entries using purrr::compact
  rows <- purrr::compact(rows)

  if (length(rows) == 0) {
    return(create_empty_results_df())
  }

  # Combine into single tibble using dplyr::bind_rows
  results_df <- dplyr::bind_rows(rows)

  return(results_df)
}


#' Validate Results
#'
#' Flags rows with missing critical fields.
#'
#' @param results_df Tibble to validate.
#' @return Tibble with is_valid column added.
#' @keywords internal
validate_results <- function(results_df) {

  if (nrow(results_df) == 0) {
    return(results_df)
  }

  # Flag rows with missing critical fields
  results_df <- results_df |>
    dplyr::mutate(
      is_valid = !is.na(page_number) & !is.na(original_text) & original_text != ""
    )

  # Warn user if any invalid rows found
  n_invalid <- sum(!results_df$is_valid)
  if (n_invalid > 0) {
    warning(sprintf("Found %d rows with missing critical fields (page_number or original_text). These rows are flagged with is_valid = FALSE.", n_invalid))
  }

  return(results_df)
}


# Main Functions --------------------------------------------------------------

#' Format Copyediting Results
#'
#' Converts API suggestions into a structured table.
#'
#' @param suggestions_list Raw suggestions from API.
#' @return Table with page_number, issue, original_text, suggested_edit, rationale, severity, confidence, and is_valid columns.
#'
#' @examples
#' \dontrun{
#'   suggestions <- list(
#'     list(page_number = 1, issue = "grammar error",
#'          original_text = "their", suggested_edit = "there",
#'          rationale = "Wrong form", severity = "critical", confidence = 0.95)
#'   )
#'   df <- format_results(suggestions)
#' }
#'
#' @export
format_results <- function(suggestions_list) {

  # Handle empty suggestions
  if (is.null(suggestions_list) || length(suggestions_list) == 0) {
    return(create_empty_results_df())
  }

  # Convert list to tibble
  results_df <- convert_list_to_df(suggestions_list)

  # Add validation flag
  results_df <- validate_results(results_df)

  # Order columns (preserve API response order, just reorder columns)
  results_df <- results_df |>
    dplyr::select(page_number, issue, original_text, suggested_edit,
                  rationale, severity, confidence, is_valid)

  # Inform user if no results found
  if (nrow(results_df) == 0) {
    message("No copyediting suggestions found.")
  }

  return(results_df)
}


#' Print Summary
#'
#' Prints a summary of copyediting results.
#'
#' @param results_df Results from process_document().
#' @return Invisible NULL.
#'
#' @examples
#' \dontrun{
#'   results <- process_document()
#'   print_summary(results)
#' }
#'
#' @export
print_summary <- function(results_df) {

  if (nrow(results_df) == 0) {
    cat("\nNo issues found! Document looks good.\n")
    return(invisible(NULL))
  }

  cat("\n=== Summary ===\n")
  cat(sprintf("Total suggestions: %d\n", nrow(results_df)))

  # By severity
  if ("severity" %in% names(results_df)) {
    cat("\nBy Severity:\n")
    severity_counts <- table(results_df$severity)
    for (sev in names(severity_counts)) {
      cat(sprintf("  %s: %d\n", sev, severity_counts[sev]))
    }
  }

  cat("\n")

  return(invisible(NULL))
}


#' Export Results to CSV
#'
#' Exports results to CSV in the same folder as source document.
#'
#' @param results_df Results from process_document().
#' @param output_filename Output file name (default: "copyedit_results.csv").
#' @param include_metadata Include metadata file (default: TRUE).
#' @return Invisible NULL.
#'
#' @examples
#' \dontrun{
#'   results <- process_document()
#'   export_results(results)
#'   export_results(results, "my_results.csv")
#' }
#'
#' @export
export_results <- function(results_df, output_filename = "copyedit_results.csv", include_metadata = TRUE) {

  # Get source file directory from metadata
  file_path <- attr(results_df, "file_path")

  if (!is.null(file_path) && file.exists(file_path)) {
    output_dir <- dirname(file_path)
    output_path <- file.path(output_dir, output_filename)
  } else {
    # Fallback to current directory if file_path not available
    output_path <- output_filename
    warning("Source file path not found in metadata. Saving to current directory.")
  }

  # Export main results
  write.csv(results_df, output_path, row.names = FALSE)
  cat(sprintf("Results exported to: %s\n", output_path))

  # Export metadata if requested
  if (include_metadata && !is.null(attr(results_df, "mode"))) {

    # Create metadata data frame
    doc_mode <- attr(results_df, "mode")
    doc_type <- attr(results_df, "document_type")
    aud <- attr(results_df, "audience")
    chunks <- attr(results_df, "num_chunks")

    metadata <- data.frame(
      mode = if (is.null(doc_mode)) NA else doc_mode,
      document_type = if (is.null(doc_type)) NA else doc_type,
      audience = if (is.null(aud)) NA else aud,
      pages_processed = paste(attr(results_df, "pages_processed"), collapse = ", "),
      num_chunks = if (is.null(chunks)) 1 else chunks,
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
