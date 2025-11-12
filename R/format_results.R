# ==============================================================================
# Title:        Result Formatter
# Last Updated: 2025-11-12
# Description:  Functions to format and validate copyediting suggestions from
#               LLM API responses into clean, structured data frames.
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
    location = character(0),
    original_text = character(0),
    suggested_edit = character(0),
    edit_type = character(0),
    reason = character(0),
    severity = character(0),
    confidence = numeric(0)
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
#' Converts the nested list structure from API to a flat tibble.
#'
#' @param suggestions_list List of suggestions.
#'
#' @return Tibble.
#' @keywords internal
convert_list_to_df <- function(suggestions_list) {

  # Extract each suggestion using purrr
  rows <- purrr::map(suggestions_list, function(suggestion) {

    # Handle both flat and nested structures
    if (is.list(suggestion)) {
      # Extract fields with defaults
      tibble::tibble(
        page_number = as.integer(get_field(suggestion, "page_number", NA)),
        location = as.character(get_field(suggestion, "location", "")),
        original_text = as.character(get_field(suggestion, "original_text", "")),
        suggested_edit = as.character(get_field(suggestion, "suggested_edit", "")),
        edit_type = as.character(get_field(suggestion, "edit_type", "other")),
        reason = as.character(get_field(suggestion, "reason", "")),
        severity = as.character(get_field(suggestion, "severity", "recommended")),
        confidence = as.numeric(get_field(suggestion, "confidence", 0.5))
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
#' Validates and cleans the results tibble.
#'
#' @param results_df Tibble.
#'
#' @return Validated tibble.
#' @keywords internal
validate_results <- function(results_df) {

  if (nrow(results_df) == 0) {
    return(results_df)
  }

  # Ensure proper types and standardize values using dplyr::mutate
  results_df <- results_df %>%
    dplyr::mutate(
      # Ensure proper types
      page_number = as.integer(page_number),
      confidence = as.numeric(confidence),
      # Clamp confidence to [0, 1]
      confidence = dplyr::case_when(
        confidence < 0 ~ 0,
        confidence > 1 ~ 1,
        TRUE ~ confidence
      ),
      # Standardize severity values
      severity = tolower(trimws(severity)),
      severity = dplyr::if_else(
        severity %in% c("critical", "recommended", "optional"),
        severity,
        "recommended"
      ),
      # Standardize edit_type values
      edit_type = tolower(trimws(edit_type)),
      edit_type = dplyr::if_else(
        edit_type %in% c("grammar", "style", "clarity", "consistency", "spelling", "other"),
        edit_type,
        "other"
      )
    )

  # Trim whitespace from all character columns
  char_cols <- names(results_df)[sapply(results_df, is.character)]
  results_df <- results_df %>%
    dplyr::mutate(dplyr::across(dplyr::all_of(char_cols), trimws))

  # Remove rows with missing critical fields
  n_before <- nrow(results_df)
  results_df <- results_df %>%
    dplyr::filter(!is.na(page_number), !is.na(original_text), original_text != "")

  n_removed <- n_before - nrow(results_df)
  if (n_removed > 0) {
    warning(sprintf("Removed %d rows with missing critical fields", n_removed))
  }

  return(results_df)
}


#' Order Columns
#'
#' Reorders columns in a standard way.
#'
#' @param results_df Tibble.
#'
#' @return Tibble with ordered columns.
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

  # Get columns that exist in preferred order, then add any extras
  results_df <- results_df %>%
    dplyr::select(
      dplyr::any_of(preferred_order),
      dplyr::everything()
    )

  return(results_df)
}


#' Sort Results
#'
#' Sorts results by page number and severity.
#'
#' @param results_df Tibble.
#'
#' @return Sorted tibble.
#' @keywords internal
sort_results <- function(results_df) {

  if (nrow(results_df) == 0) {
    return(results_df)
  }

  # Define severity order for sorting
  severity_levels <- c("critical", "recommended", "optional")

  # Sort by page number, then severity using dplyr::arrange
  results_df <- results_df %>%
    dplyr::mutate(
      severity_order = match(severity, severity_levels),
      severity_order = dplyr::if_else(is.na(severity_order), 99L, as.integer(severity_order))
    ) %>%
    dplyr::arrange(page_number, severity_order) %>%
    dplyr::select(-severity_order)

  return(results_df)
}


# Main Functions --------------------------------------------------------------

#' Format Copyediting Results
#'
#' Converts a list of copyediting suggestions from OpenAI API into a clean,
#' structured tibble with proper column types and validation.
#'
#' @param suggestions_list List. Raw suggestions from API responses.
#'
#' @return A tibble with standardized columns:
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

  # Convert list to tibble
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
#' @param results_df Tibble. Results from process_document().
#' @param severity Character vector. Filter by severity (e.g., c("critical", "recommended")).
#' @param edit_type Character vector. Filter by edit type (e.g., c("grammar", "spelling")).
#' @param pages Integer vector. Filter by page numbers.
#' @param min_confidence Numeric. Minimum confidence threshold (0-1).
#'
#' @return Filtered tibble.
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

  # Start with full dataset
  filtered <- results_df

  # Apply filters using dplyr::filter
  if (!is.null(severity)) {
    filtered <- filtered %>%
      dplyr::filter(severity %in% !!severity)
  }

  if (!is.null(edit_type)) {
    filtered <- filtered %>%
      dplyr::filter(edit_type %in% !!edit_type)
  }

  if (!is.null(pages)) {
    filtered <- filtered %>%
      dplyr::filter(page_number %in% !!pages)
  }

  if (!is.null(min_confidence)) {
    filtered <- filtered %>%
      dplyr::filter(confidence >= !!min_confidence)
  }

  return(filtered)
}
