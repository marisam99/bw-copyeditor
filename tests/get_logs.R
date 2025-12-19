# ==============================================================================
# Title:        Get Response Logs and Metadata
# Description:  Retrieves stored responses from OpenAI's Responses API and
#               extracts cost, time, and usage metadata for analysis.
# Output:       CSV file with response metadata (cost, tokens, timestamps, etc.)
# ==============================================================================

source("config/dependencies.R")
source("config/model_config.R")
library(httr2)

# Configuration ----------------------------------------------------------------
base_url <- "https://api.openai.com/v1/responses"
api_key <- Sys.getenv("OPENAI_API_KEY")

# Helper Functions -------------------------------------------------------------

#' Read Response IDs from CSV
#'
#' Reads response IDs from a CSV file.
#'
#' @param csv_path Path to CSV file (default: tests/eval_tracker.csv).
#' @param id_column Name of column containing response IDs (default: "API Response ID").
#' @return Character vector of response IDs.
#' @keywords internal
read_response_ids_from_csv <- function(csv_path = "tests/eval_tracker.csv",
                                       id_column = "API Response ID") {
  if (!file.exists(csv_path)) {
    stop(sprintf("CSV file not found: %s", csv_path))
  }

  # Read CSV with UTF-8 encoding
  df <- read.csv(csv_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")

  # Check column exists
  if (!id_column %in% names(df)) {
    stop(sprintf("Column '%s' not found in CSV. Available columns: %s",
                 id_column, paste(names(df), collapse = ", ")))
  }

  # Extract response IDs
  response_ids <- df[[id_column]]

  message(sprintf("Read %d response IDs from %s",
                  length(response_ids), csv_path))

  return(response_ids)
}


#' Validate API Key
#'
#' Checks that OPENAI_API_KEY is set in environment.
#'
#' @keywords internal
validate_api_key <- function() {
  if (Sys.getenv("OPENAI_API_KEY") == "") {
    stop("OpenAI API key not found. Set OPENAI_API_KEY in your .Renviron file or use Sys.setenv(OPENAI_API_KEY = 'your-key'). For more information, see the README.md.")
  }
}


#' Execute Function with Retry Logic
#'
#' Wraps API calls with automatic retry on rate limits and server errors.
#'
#' @param fn Function to execute with retry logic.
#' @param max_attempts Maximum retry attempts.
#' @return Result from fn().
#' @keywords internal
with_retry <- function(fn, max_attempts = MAX_RETRY_ATTEMPTS) {
  attempt <- 1
  last_error <- NULL

  while (attempt <= max_attempts) {
    tryCatch({
      return(fn())
    }, error = function(e) {
      last_error <<- e
      error_msg <- conditionMessage(e)

      if (!is.null(e$parent) && inherits(e$parent, "error")) {
        error_msg <- paste(error_msg, "\nDetails:", conditionMessage(e$parent))
      }

      if (grepl("rate limit|429", error_msg, ignore.case = TRUE)) {
        message(sprintf("⏳ Rate limit hit (attempt %d/%d) - retrying in %d seconds...",
                       attempt, max_attempts, attempt * 2))
        Sys.sleep(attempt * 2)
      } else if (grepl("500|502|503|504", error_msg, ignore.case = TRUE)) {
        message(sprintf("⏳ Server error (attempt %d/%d) - retrying in %d seconds...",
                       attempt, max_attempts, attempt * 2))
        Sys.sleep(attempt * 2)
      } else {
        stop(sprintf("API request failed: %s", error_msg))
      }
    })

    attempt <- attempt + 1
  }

  stop(sprintf("API request failed after %d attempts: %s",
               max_attempts, last_error$message))
}


#' Fetch Response by ID
#'
#' Retrieves a single response by ID from OpenAI Responses API.
#'
#' @param response_id Character string response ID (e.g., "resp_...").
#' @return Parsed JSON response object.
#' @keywords internal
fetch_response_by_id <- function(response_id) {
  req <- request(paste0(base_url, "/", response_id)) |>
    req_auth_bearer_token(api_key)

  resp <- req_perform(req)
  parsed <- resp_body_json(resp, simplifyVector = FALSE)

  return(parsed)
}


#' Calculate API Cost
#'
#' Calculates API cost from token usage and model.
#'
#' @param usage Usage object with prompt_tokens, completion_tokens.
#' @param model Model name (e.g., "gpt-5.1", "gpt-4o").
#' @return Cost in dollars (numeric).
#' @keywords internal
calculate_cost <- function(usage, model) {
  # Pricing table (per million tokens) - Updated 2025-12-19
  pricing <- list(
    "gpt-5.1" = list(input = 1.25, output = 10.00),
    "gpt-5" = list(input = 1.25, output = 10.00),
    "gpt-4o" = list(input = 2.50, output = 10.00),
    "gpt-4o-mini" = list(input = 0.15, output = 0.60)
  )

  # Extract base model name (handle versioned models like gpt-4o-2024-08-06)
  base_model <- gsub("-\\d{4}-\\d{2}-\\d{2}$", "", model)

  # Get pricing or use default
  if (base_model %in% names(pricing)) {
    rates <- pricing[[base_model]]
  } else {
    warning(sprintf("⚠️ Unknown model '%s', using GPT-4o pricing", model))
    rates <- pricing[["gpt-4o"]]
  }

  # Calculate cost (tokens / 1,000,000 * rate)
  input_cost <- (usage$prompt_tokens / 1e6) * rates$input
  output_cost <- (usage$completion_tokens / 1e6) * rates$output
  total_cost <- input_cost + output_cost

  return(total_cost)
}


#' Extract Metadata from Response Object
#'
#' Extracts relevant metadata fields from API response object.
#'
#' @param response_obj Parsed response from fetch_response_by_id().
#' @return Tibble with one row containing extracted metadata.
#' @keywords internal
extract_metadata_from_response <- function(response_obj) {
  # Safely extract fields with defaults
  response_id <- pluck(response_obj, "id", .default = NA_character_)
  created_at <- pluck(response_obj, "created_at", .default = NA_integer_)
  model <- pluck(response_obj, "model", .default = NA_character_)

  # Extract usage
  usage <- pluck(response_obj, "usage", .default = list())

  # Basic token counts
  input_tokens <- pluck(usage, "input_tokens", .default = NA_integer_)
  output_tokens <- pluck(usage, "output_tokens", .default = NA_integer_)
  total_tokens <- pluck(usage, "total_tokens", .default = NA_integer_)

  # Detailed token breakdowns
  input_tokens_details <- pluck(usage, "input_tokens_details", .default = list())
  cached_tokens <- pluck(input_tokens_details, "cached_tokens", .default = NA_integer_)

  output_tokens_details <- pluck(usage, "output_tokens_details", .default = list())
  reasoning_tokens <- pluck(output_tokens_details, "reasoning_tokens", .default = NA_integer_)

  # Legacy field names (for backward compatibility)
  # Some responses may use prompt_tokens/completion_tokens instead
  if (is.na(input_tokens) && !is.null(usage$prompt_tokens)) {
    input_tokens <- pluck(usage, "prompt_tokens", .default = NA_integer_)
  }
  if (is.na(output_tokens) && !is.null(usage$completion_tokens)) {
    output_tokens <- pluck(usage, "completion_tokens", .default = NA_integer_)
  }

  # Extract custom metadata
  metadata <- pluck(response_obj, "metadata", .default = list())
  mode <- pluck(metadata, "mode", .default = NA_character_)
  phase <- pluck(metadata, "phase", .default = NA_character_)
  system_prompt_version <- pluck(metadata, "system_prompt", .default = NA_character_)
  reasoning_level <- pluck(metadata, "reasoning", .default = NA_character_)

  # Calculate cost
  cost <- if (!is.na(model) && length(usage) > 0 && (!is.na(input_tokens) || !is.null(usage$prompt_tokens))) {
    usage_for_calc <- list(
      prompt_tokens = input_tokens,
      completion_tokens = output_tokens
    )
    calculate_cost(usage_for_calc, model)
  } else {
    NA_real_
  }

  # Convert timestamp to datetime
  created_datetime <- if (!is.na(created_at)) {
    as.POSIXct(created_at, origin = "1970-01-01", tz = "UTC")
  } else {
    NA
  }

  # Return as tibble with detailed token breakdown
  tibble(
    response_id = response_id,
    created_at = created_datetime,
    model = model,
    input_tokens = input_tokens,
    output_tokens = output_tokens,
    total_tokens = total_tokens,
    cached_tokens = cached_tokens,
    reasoning_tokens = reasoning_tokens,
    cost_usd = cost,
    mode = mode,
    phase = phase,
    system_prompt_version = system_prompt_version,
    reasoning_level = reasoning_level
  )
}


#' Retrieve Response Metadata
#'
#' Retrieves metadata for multiple response IDs from OpenAI Responses API.
#'
#' @param response_ids Character vector of response IDs.
#' @return Tibble with metadata for each response.
#' @keywords internal
retrieve_response_metadata <- function(response_ids) {
  # Validate API key
  validate_api_key()

  # Remove empty/NA IDs and trim whitespace
  response_ids <- response_ids[!is.na(response_ids) & nchar(trimws(response_ids)) > 0]
  response_ids <- trimws(response_ids)

  if (length(response_ids) == 0) {
    stop("No valid response IDs provided")
  }

  message(sprintf("\n=== Retrieving Response Metadata ==="))
  message(sprintf("Total response IDs: %d\n", length(response_ids)))

  # Initialize results list
  results <- list()
  failed_ids <- character(0)

  # Process each response ID
  for (i in seq_along(response_ids)) {
    response_id <- response_ids[i]

    message(sprintf("⏳ [%d/%d] Fetching: %s",
                    i, length(response_ids), response_id))

    tryCatch({
      # Fetch with retry logic
      response_obj <- with_retry(function() {
        fetch_response_by_id(response_id)
      })

      # Extract metadata
      metadata_row <- extract_metadata_from_response(response_obj)
      results[[length(results) + 1]] <- metadata_row

      message(sprintf("✅ Retrieved (Cost: $%.4f, Tokens: %s)",
                      metadata_row$cost_usd,
                      format(metadata_row$total_tokens, big.mark = ",")))

      # Rate limiting: small delay between requests
      if (i < length(response_ids)) {
        Sys.sleep(0.5)  # 500ms delay
      }

    }, error = function(e) {
      warning(sprintf("⚠️ Failed to retrieve %s: %s",
                      response_id, e$message))
      failed_ids <<- c(failed_ids, response_id)
    })
  }

  message(sprintf("\n✅ Retrieval complete!"))
  message(sprintf("Successful: %d", length(results)))
  if (length(failed_ids) > 0) {
    message(sprintf("Failed: %d", length(failed_ids)))
  }
  message("")

  # Combine results
  if (length(results) == 0) {
    warning("⚠️ No metadata retrieved")
    return(tibble())
  }

  metadata_df <- bind_rows(results)

  # Add failed IDs as attribute
  if (length(failed_ids) > 0) {
    attr(metadata_df, "failed_ids") <- failed_ids
  }

  return(metadata_df)
}


#' Export Metadata to CSV
#'
#' Exports metadata to timestamped CSV file.
#'
#' @param metadata_df Tibble from retrieve_response_metadata().
#' @param output_dir Directory to save CSV (default: tests/).
#' @param base_name Base filename (default: "response_metadata").
#' @return Path to exported CSV file.
#' @keywords internal
export_metadata_to_csv <- function(metadata_df,
                                   output_dir = "tests",
                                   base_name = "response_metadata") {
  # Create timestamp
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  filename <- sprintf("%s_%s.csv", base_name, timestamp)
  output_path <- file.path(output_dir, filename)

  # Ensure directory exists
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Export to CSV with UTF-8 encoding
  write.csv(metadata_df, output_path, row.names = FALSE, fileEncoding = "UTF-8")

  message(sprintf("✅ Exported to: %s", output_path))
  message(sprintf("Rows: %d", nrow(metadata_df)))

  # Print summary statistics
  if (nrow(metadata_df) > 0) {
    message(sprintf("\nSummary:"))
    message(sprintf("  Total cost: $%.2f", sum(metadata_df$cost_usd, na.rm = TRUE)))
    message(sprintf("  Total tokens: %s", format(sum(metadata_df$total_tokens, na.rm = TRUE), big.mark = ",")))
    message(sprintf("  Models used: %s", paste(unique(metadata_df$model), collapse = ", ")))
  }

  return(output_path)
}


# Main Function ----------------------------------------------------------------

#' Main Execution Function
#'
#' Orchestrates the full workflow: read CSV, retrieve metadata, export results.
#'
#' @param csv_path Path to CSV file (default: tests/eval_tracker.csv).
#' @param id_column Name of column containing response IDs (default: "API Response ID").
#' @return Tibble with response metadata.
#' @export
main <- function(csv_path = "tests/eval_tracker.csv",
                id_column = "API Response ID") {
  # Read response IDs from CSV
  response_ids <- read_response_ids_from_csv(
    csv_path = csv_path,
    id_column = id_column
  )

  # Retrieve metadata
  metadata_df <- retrieve_response_metadata(response_ids)

  # Export results
  if (nrow(metadata_df) > 0) {
    export_metadata_to_csv(metadata_df)
  }

  return(metadata_df)
}


# Auto-execution ---------------------------------------------------------------
# Run main() if script is sourced interactively
if (interactive() && !exists(".get_logs_executed")) {
  .get_logs_executed <- TRUE
  message("Run main() to retrieve response metadata from eval_tracker.csv")
}
