# ==============================================================================
# Title:        Result Formatter
# Last Updated: 2025-11-12
# Description:  Functions to format and validate copyediting suggestions from
#               LLM API responses into clean, structured data frames.
# ==============================================================================


# Helper Functions ------------------------------------------------------------

#' Create Empty Results Data Frame
#'
#' Creates an empty data frame with the correct structure.
#'
#' @return Empty data frame with proper column types.
#' @keywords internal
create_empty_results_df <- function() {
  data.frame(
    page_number = integer(0),
    location = character(0),
    original_text = character(0),
    suggested_edit = character(0),
    edit_type = character(0),
    reason = character(0),
    severity = character(0),
    confidence = numeric(0),
    stringsAsFactors = FALSE
  )
}


#' Get Field from List
#'
#' Safely extract a field from a list with a default value.
#'
#' @param lst List.
#' @param field Character. Field name.
#' @param default Default value if field is missing or NULL.
#'
#' @return Field value or default.
#' @keywords internal
get_field <- function(lst, field, default) {
  if (field %in% names(lst) && !is.null(lst[[field]])) {
    return(lst[[field]])
  }
  return(default)
}


#' Convert List to Data Frame
#'
#' Converts the nested list structure from API to a flat data frame.
#'
#' @param suggestions_list List of suggestions.
#'
#' @return Data frame.
#' @keywords internal
convert_list_to_df <- function(suggestions_list) {

  # Extract each suggestion
  rows <- lapply(suggestions_list, function(suggestion) {

    # Handle both flat and nested structures
    if (is.list(suggestion)) {
      # Extract fields with defaults
      data.frame(
        page_number = as.integer(get_field(suggestion, "page_number", NA)),
        location = as.character(get_field(suggestion, "location", "")),
        original_text = as.character(get_field(suggestion, "original_text", "")),
        suggested_edit = as.character(get_field(suggestion, "suggested_edit", "")),
        edit_type = as.character(get_field(suggestion, "edit_type", "other")),
        reason = as.character(get_field(suggestion, "reason", "")),
        severity = as.character(get_field(suggestion, "severity", "recommended")),
        confidence = as.numeric(get_field(suggestion, "confidence", 0.5)),
        stringsAsFactors = FALSE
      )
    } else {
      # Skip invalid entries
      NULL
    }
  })

  # Remove NULL entries
  rows <- rows[!sapply(rows, is.null)]

  if (length(rows) == 0) {
    return(create_empty_results_df())
  }

  # Combine into single data frame
  results_df <- do.call(rbind, rows)

  return(results_df)
}


#' Validate Results
#'
#' Validates and cleans the results data frame.
#'
#' @param results_df Data frame.
#'
#' @return Validated data frame.
#' @keywords internal
validate_results <- function(results_df) {

  if (nrow(results_df) == 0) {
    return(results_df)
  }

  # Ensure proper types
  if ("page_number" %in% names(results_df)) {
    results_df$page_number <- as.integer(results_df$page_number)
  }

  if ("confidence" %in% names(results_df)) {
    results_df$confidence <- as.numeric(results_df$confidence)
    # Clamp confidence to [0, 1]
    results_df$confidence[results_df$confidence < 0] <- 0
    results_df$confidence[results_df$confidence > 1] <- 1
  }

  # Standardize severity values
  if ("severity" %in% names(results_df)) {
    results_df$severity <- tolower(trimws(results_df$severity))
    valid_severities <- c("critical", "recommended", "optional")

    # Map to valid values
    results_df$severity[!results_df$severity %in% valid_severities] <- "recommended"
  }

  # Standardize edit_type values
  if ("edit_type" %in% names(results_df)) {
    results_df$edit_type <- tolower(trimws(results_df$edit_type))
    valid_types <- c("grammar", "style", "clarity", "consistency", "spelling", "other")

    # Map to valid values
    results_df$edit_type[!results_df$edit_type %in% valid_types] <- "other"
  }

  # Trim whitespace from character columns
  char_cols <- sapply(results_df, is.character)
  results_df[char_cols] <- lapply(results_df[char_cols], trimws)

  # Remove rows with missing critical fields
  if (any(c("page_number", "original_text") %in% names(results_df))) {
    complete_rows <- complete.cases(results_df[c("page_number", "original_text")])
    if (sum(!complete_rows) > 0) {
      warning(sprintf("Removed %d rows with missing critical fields", sum(!complete_rows)))
      results_df <- results_df[complete_rows, ]
    }
  }

  return(results_df)
}


#' Order Columns
#'
#' Reorders columns in a standard way.
#'
#' @param results_df Data frame.
#'
#' @return Data frame with ordered columns.
#' @keywords internal
order_columns <- function(results_df) {

  # Define preferred column order
  preferred_order <- c(
    "page_number",
    "location",
    "original_text",
    "suggested_edit",
    "edit_type",
    "reason",
    "severity",
    "confidence"
  )

  # Get actual columns in preferred order
  ordered_cols <- preferred_order[preferred_order %in% names(results_df)]

  # Add any extra columns at the end
  extra_cols <- setdiff(names(results_df), ordered_cols)
  all_cols <- c(ordered_cols, extra_cols)

  results_df <- results_df[, all_cols, drop = FALSE]

  return(results_df)
}


#' Sort Results
#'
#' Sorts results by page number and severity.
#'
#' @param results_df Data frame.
#'
#' @return Sorted data frame.
#' @keywords internal
sort_results <- function(results_df) {

  if (nrow(results_df) == 0) {
    return(results_df)
  }

  # Define severity order
  severity_order <- c("critical", "recommended", "optional")

  # Create sorting key for severity
  if ("severity" %in% names(results_df)) {
    results_df$severity_order <- match(results_df$severity, severity_order)
    results_df$severity_order[is.na(results_df$severity_order)] <- 99
  } else {
    results_df$severity_order <- 1
  }

  # Sort by page number, then severity
  if ("page_number" %in% names(results_df)) {
    results_df <- results_df[order(results_df$page_number, results_df$severity_order), ]
  } else {
    results_df <- results_df[order(results_df$severity_order), ]
  }

  # Remove temporary sorting column
  results_df$severity_order <- NULL

  # Reset row names
  rownames(results_df) <- NULL

  return(results_df)
}


# Main Functions --------------------------------------------------------------

#' Format Copyediting Results
#'
#' Converts a list of copyediting suggestions from OpenAI API into a clean,
#' structured data frame with proper column types and validation.
#'
#' @param suggestions_list List. Raw suggestions from API responses.
#'
#' @return A data frame with standardized columns:
#'   \item{page_number}{Integer}
#'   \item{location}{Character}
#'   \item{original_text}{Character}
#'   \item{suggested_edit}{Character}
#'   \item{edit_type}{Character}
#'   \item{reason}{Character}
#'   \item{severity}{Character}
#'   \item{confidence}{Numeric}
#'
#' @examples
#' \dontrun{
#'   suggestions <- list(
#'     list(page_number = 1, location = "first paragraph",
#'          original_text = "their", suggested_edit = "there",
#'          edit_type = "grammar", reason = "Wrong form of there/their/they're",
#'          severity = "critical", confidence = 0.95)
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

  # Convert list to data frame
  results_df <- convert_list_to_df(suggestions_list)

  # Validate and clean
  results_df <- validate_results(results_df)

  # Order columns
  results_df <- order_columns(results_df)

  # Sort by page number and severity
  results_df <- sort_results(results_df)

  return(results_df)
}


#' Filter Results
#'
#' Helper function to filter results by various criteria.
#'
#' @param results_df Data frame. Results from process_document().
#' @param severity Character vector. Filter by severity (e.g., c("critical", "recommended")).
#' @param edit_type Character vector. Filter by edit type (e.g., c("grammar", "spelling")).
#' @param pages Integer vector. Filter by page numbers.
#' @param min_confidence Numeric. Minimum confidence threshold (0-1).
#'
#' @return Filtered data frame.
#'
#' @examples
#' \dontrun{
#'   results <- process_document("report.pdf")
#'
#'   # Get only critical issues
#'   critical <- filter_results(results, severity = "critical")
#'
#'   # Get grammar and spelling issues on pages 1-5
#'   subset <- filter_results(results,
#'                           edit_type = c("grammar", "spelling"),
#'                           pages = 1:5)
#' }
#'
#' @export
filter_results <- function(results_df,
                          severity = NULL,
                          edit_type = NULL,
                          pages = NULL,
                          min_confidence = NULL) {

  filtered <- results_df

  # Filter by severity
  if (!is.null(severity) && "severity" %in% names(filtered)) {
    filtered <- filtered[filtered$severity %in% severity, ]
  }

  # Filter by edit_type
  if (!is.null(edit_type) && "edit_type" %in% names(filtered)) {
    filtered <- filtered[filtered$edit_type %in% edit_type, ]
  }

  # Filter by pages
  if (!is.null(pages) && "page_number" %in% names(filtered)) {
    filtered <- filtered[filtered$page_number %in% pages, ]
  }

  # Filter by confidence
  if (!is.null(min_confidence) && "confidence" %in% names(filtered)) {
    filtered <- filtered[filtered$confidence >= min_confidence, ]
  }

  # Reset row names
  rownames(filtered) <- NULL

  return(filtered)
}
