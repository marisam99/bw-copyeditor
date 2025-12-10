# ==============================================================================
# Title:        OpenAI API Caller (using ellmer package)
# Description:  Functions to call OpenAI API for copyediting using the ellmer package.
#               Supports both text-only and multimodal (image) modes.
# Output:       a list object with the JSON response, model and usage information, and API metadata.
# ==============================================================================

# Helper Functions ------------------------------------------------------------

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
      last_error <<- e  # Use <<- to assign to outer scope
      error_msg <- conditionMessage(e)

      # Try to extract full error details from httr response if available
      if (!is.null(e$parent) && inherits(e$parent, "error")) {
        error_msg <- paste(error_msg, "\nDetails:", conditionMessage(e$parent))
      }

      if (grepl("rate limit|429", error_msg, ignore.case = TRUE)) {
        message(sprintf("⏳ Rate limit hit (attempt %d/%d) - retrying in %d seconds...",
                       attempt, max_attempts, attempt * 2))
        Sys.sleep(attempt * 2)  # Exponential backoff
      } else if (grepl("500|502|503|504", error_msg, ignore.case = TRUE)) {
        message(sprintf("⏳ Server error (attempt %d/%d) - retrying in %d seconds...",
                       attempt, max_attempts, attempt * 2))
        Sys.sleep(attempt * 2)
      } else {
        # Don't retry on client errors - show full error details
        cat("\n=== Full API Error Details ===\n")
        cat("Error message:", error_msg, "\n")
        cat("Error class:", class(e), "\n")
        if (!is.null(e$call)) cat("Error call:", deparse(e$call), "\n")
        cat("==============================\n\n")
        stop(sprintf("API request failed: %s. For more information, see the README.md.", error_msg))
      }
    })

    attempt <- attempt + 1
  }

  # If we get here, all retries failed
  stop(sprintf("API request failed after %d attempts: %s. For more information, see the README.md.",
               max_attempts, last_error$message))
}


#' Parse JSON Response from API
#'
#' Extracts and parses copyediting suggestions from API response.
#'
#' @param response Response content from chat$chat().
#' @param model Model name used.
#' @param chat The ellmer chat session.
#' @return List with parsed suggestions and metadata.
#' @keywords internal
parse_json_response <- function(response, model, chat) {

  # Parse the JSON suggestions from response
  suggestions <- tryCatch({
    # Response should be a JSON string
    parsed <- fromJSON(response, simplifyVector = FALSE)

    # If it's already parsed (has suggestions field), use it directly
    if (is.list(parsed) && "suggestions" %in% names(parsed)) {
      parsed$suggestions
    } else {
      # Otherwise, the whole thing might be the suggestions array
      parsed
    }
  }, error = function(e) {
    warning(sprintf("⚠️ Failed to parse API response as JSON: %s\nRaw content: %s",
                   e$message, substr(response, 1, 500)))
    list()  # Return empty list if parsing fails
  })

  # Try to get usage information from chat object
  usage <- tryCatch({
    chat$last_turn()$tokens
  }, error = function(e) {
    NULL
  })

  # Try to get other metadata
  response_metadata <- tryCatch({
    turn <- chat$last_turn()
    list(
      finish_reason = if (is.null(turn$finish_reason)) "unknown" else turn$finish_reason,
      created = if (is.null(turn$created)) Sys.time() else turn$created,
      id = if (is.null(turn$id)) NA else turn$id
    )
  }, error = function(e) {
    list(
      finish_reason = "unknown",
      created = Sys.time(),
      id = NA
    )
  })

  # Return structured result
  result <- list(
    suggestions = suggestions,
    model = model,
    usage = usage,
    response_metadata = response_metadata
  )

  return(result)
}


# Main Functions --------------------------------------------------------------

#' Call OpenAI API (Text Mode)
#'
#' Sends text to OpenAI API for copyediting. For images, use call_openai_api_images().
#'
#' @param user_message User message text from build_prompt_text().
#' @return List with suggestions, model, usage, and response_metadata.
#'
#' @examples
#' \dontrun{
#'   # Extract and build prompt
#'   doc <- extract_document(mode = "text")
#'   prompts <- build_prompt_text(doc, "external client-facing", "Healthcare executives")
#'
#'   # Call API
#'   result <- call_openai_api_text(prompts$user_message[1])
#' }
#'
#' @export
call_openai_api_text <- function(user_message) {

  # Validate API key
  validate_api_key()

  # Validate inputs
  if (!is.character(user_message) || length(user_message) != 1) {
    stop("user_message must be a single character string. For more information, see the README.md.")
  }

  # Execute with retry logic
  result <- with_retry(function() {
    # Set timeout
    options(elmer.timeout = TIMEOUT_TEXT)

    # Create chat session
    chat <- chat_openai(
      system_prompt = SYSTEM_PROMPT,
      model = MODEL_TEXT,
      api_args = list(
        reasoning = list(
          effort = REASONING_LEVEL
        )
      ),
      echo = "none"
    )

    # Send message and get response
    start_time <- Sys.time()
    response <- chat$chat(user_message)
    elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)

    message(sprintf("✅ Response received in %.1f seconds", elapsed))

    # Parse the JSON response
    parse_json_response(response, MODEL_TEXT, chat)
  })

  return(result)
}


#' Call OpenAI API (Image Mode)
#'
#' Sends images to OpenAI Vision API for copyediting. More expensive than text mode.
#' For text-only documents, use call_openai_api_text().
#'
#' @param user_content Ellmer-formatted content from build_prompt_images().
#' @return List with suggestions, model, usage, and response_metadata.
#'
#' @examples
#' \dontrun{
#'   # Extract and build prompt
#'   slides <- extract_document(mode = "images")
#'   prompts <- build_prompt_images(slides, "external client-facing", "Healthcare executives")
#'
#'   # Call API
#'   result <- call_openai_api_images(prompts$user_message[[1]])
#' }
#'
#' @export
call_openai_api_images <- function(user_content) {

  # Validate API key
  validate_api_key()

  # Validate inputs
  if (!is.list(user_content) || length(user_content) == 0) {
    stop("user_content must be a non-empty list of ellmer content objects from build_prompt_images(). For more information, see the README.md.")
  }

  # Execute with retry logic
  result <- with_retry(function() {
    # Set timeout
    options(elmer.timeout = TIMEOUT_IMAGES)

    # Create chat session
    chat <- chat_openai(
      system_prompt = SYSTEM_PROMPT,
      model = MODEL_IMAGES,
      api_args = list(
        max_output_tokens = MAX_COMPLETION_TOKENS_IMAGES,
        reasoning = list(
          effort = REASONING_LEVEL
        )
      ),
      echo = "none"
    )

    # Send multimodal message and get response
    # user_content is already in ellmer format (strings + content_image_file objects)
    start_time <- Sys.time()
    response <- do.call(chat$chat, user_content)
    elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)

    message(sprintf("✅ Response received in %.1f seconds", elapsed))

    # Parse the JSON response
    parse_json_response(response, MODEL_IMAGES, chat)
  })

  return(result)
}
