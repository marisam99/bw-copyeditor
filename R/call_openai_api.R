#' Call OpenAI API for Copyediting
#'
#' Sends a request to the OpenAI API with the constructed prompt and returns
#' the parsed response. Includes error handling and rate limiting support.
#'
#' @param messages List. The messages array built by build_prompt().
#' @param model Character. OpenAI model to use (default: "gpt-4").
#'   Options: "gpt-4", "gpt-4-turbo-preview", "gpt-3.5-turbo", etc.
#' @param api_key Character. OpenAI API key. If NULL, will attempt to read
#'   from OPENAI_API_KEY environment variable.
#' @param temperature Numeric. Sampling temperature between 0 and 2 (default: 0.3).
#'   Lower values make output more focused and deterministic.
#' @param max_retries Integer. Maximum number of retry attempts for failed requests (default: 3).
#' @param retry_delay Numeric. Initial delay in seconds between retries (default: 2).
#'   Uses exponential backoff.
#'
#' @return A list with:
#'   \item{suggestions}{Parsed JSON array of copyediting suggestions}
#'   \item{model}{Model used for the request}
#'   \item{usage}{Token usage information}
#'   \item{response_metadata}{Full API response metadata}
#'
#' @examples
#' \dontrun{
#'   messages <- build_prompt("Text to edit", 1, "Project context")
#'   result <- call_openai_api(messages, api_key = "sk-...")
#'   suggestions <- result$suggestions
#' }
#'
#' @export
call_openai_api <- function(messages,
                           model = "gpt-4",
                           api_key = NULL,
                           temperature = 0.3,
                           max_retries = 3,
                           retry_delay = 2) {

  # Load required packages
  if (!requireNamespace("httr", quietly = TRUE)) {
    stop("Package 'httr' is required. Install with: install.packages('httr')")
  }

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required. Install with: install.packages('jsonlite')")
  }

  # Get API key
  if (is.null(api_key)) {
    api_key <- Sys.getenv("OPENAI_API_KEY")
    if (api_key == "") {
      stop("OpenAI API key not found. Provide via api_key parameter or set OPENAI_API_KEY environment variable.")
    }
  }

  # Validate inputs
  if (!is.list(messages) || length(messages) == 0) {
    stop("messages must be a non-empty list")
  }

  if (temperature < 0 || temperature > 2) {
    stop("temperature must be between 0 and 2")
  }

  # Build request body
  body <- list(
    model = model,
    messages = messages,
    temperature = temperature,
    response_format = list(type = "json_object")
  )

  # Make API request with retry logic
  response <- make_request_with_retry(
    body = body,
    api_key = api_key,
    max_retries = max_retries,
    retry_delay = retry_delay
  )

  return(response)
}


#' Make API Request with Retry Logic
#'
#' Internal function to handle API requests with exponential backoff retry.
#'
#' @param body List. Request body.
#' @param api_key Character. API key.
#' @param max_retries Integer. Maximum retries.
#' @param retry_delay Numeric. Initial retry delay.
#'
#' @return Parsed API response.
#' @keywords internal
make_request_with_retry <- function(body, api_key, max_retries, retry_delay) {

  api_url <- "https://api.openai.com/v1/chat/completions"
  attempt <- 1
  current_delay <- retry_delay

  while (attempt <= max_retries + 1) {

    tryCatch({
      # Make the request
      response <- httr::POST(
        url = api_url,
        httr::add_headers(
          "Authorization" = paste("Bearer", api_key),
          "Content-Type" = "application/json"
        ),
        body = jsonlite::toJSON(body, auto_unbox = TRUE),
        encode = "raw"
      )

      # Check for HTTP errors
      if (httr::status_code(response) == 200) {
        # Success! Parse and return
        return(parse_api_response(response, body$model))

      } else if (httr::status_code(response) == 429) {
        # Rate limit error
        message(sprintf("Rate limit hit (attempt %d/%d). Retrying in %.1f seconds...",
                       attempt, max_retries + 1, current_delay))

      } else if (httr::status_code(response) >= 500) {
        # Server error
        message(sprintf("Server error %d (attempt %d/%d). Retrying in %.1f seconds...",
                       httr::status_code(response), attempt, max_retries + 1, current_delay))

      } else {
        # Client error - don't retry
        content <- httr::content(response, "text", encoding = "UTF-8")
        stop(sprintf("API request failed with status %d: %s",
                    httr::status_code(response), content))
      }

    }, error = function(e) {
      if (attempt > max_retries) {
        stop(sprintf("API request failed after %d attempts: %s", max_retries + 1, e$message))
      }
      message(sprintf("Request error (attempt %d/%d): %s. Retrying in %.1f seconds...",
                     attempt, max_retries + 1, e$message, current_delay))
    })

    # Wait before retry (with exponential backoff)
    if (attempt <= max_retries) {
      Sys.sleep(current_delay)
      current_delay <- current_delay * 2
      attempt <- attempt + 1
    } else {
      stop("Maximum retry attempts reached")
    }
  }
}


#' Parse API Response
#'
#' Extracts and parses the copyediting suggestions from OpenAI API response.
#'
#' @param response httr response object.
#' @param model Character. Model name used.
#'
#' @return List with parsed suggestions and metadata.
#' @keywords internal
parse_api_response <- function(response, model) {

  # Parse response content
  content <- httr::content(response, "text", encoding = "UTF-8")
  parsed <- jsonlite::fromJSON(content, simplifyVector = FALSE)

  # Extract the message content (should be JSON)
  if (is.null(parsed$choices) || length(parsed$choices) == 0) {
    stop("No response choices returned from API")
  }

  message_content <- parsed$choices[[1]]$message$content

  # Parse the JSON suggestions
  suggestions <- tryCatch({
    jsonlite::fromJSON(message_content, simplifyVector = FALSE)
  }, error = function(e) {
    warning(sprintf("Failed to parse API response as JSON: %s\nRaw content: %s",
                   e$message, message_content))
    list()  # Return empty list if parsing fails
  })

  # Return structured result
  result <- list(
    suggestions = suggestions,
    model = model,
    usage = parsed$usage,
    response_metadata = list(
      finish_reason = parsed$choices[[1]]$finish_reason,
      created = parsed$created,
      id = parsed$id
    )
  )

  return(result)
}


#' Get Available OpenAI Models
#'
#' Helper function to show commonly used OpenAI models for copyediting.
#'
#' @return Character vector of model names.
#'
#' @examples
#' get_available_models()
#'
#' @export
get_available_models <- function() {
  models <- c(
    "gpt-4-turbo-preview",
    "gpt-4",
    "gpt-4-32k",
    "gpt-3.5-turbo",
    "gpt-3.5-turbo-16k"
  )

  cat("Commonly used OpenAI models:\n")
  for (i in seq_along(models)) {
    cat(sprintf("  %d. %s\n", i, models[i]))
  }

  cat("\nNote: Check OpenAI documentation for latest model availability and pricing.\n")

  return(invisible(models))
}
