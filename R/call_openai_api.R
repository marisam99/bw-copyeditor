# ==============================================================================
# Title:        OpenAI API Caller (using ellmer package)
# Last Updated: 2025-11-05
# Description:  Functions to call OpenAI API for copyediting using the ellmer package.
#               Supports both text-only and multimodal (image) modes.
# ==============================================================================

# Load configuration ----------------------------------------------------------
source(file.path("config", "model_config.R"))


# Helper Functions ------------------------------------------------------------

#' Parse JSON Response from API
#'
#' Extracts and parses the copyediting suggestions from the API response.
#'
#' @param response Character. Response content from chat$chat().
#' @param model Character. Model name used.
#' @param chat Chat object. The ellmer chat session.
#'
#' @return List with parsed suggestions and metadata.
#' @keywords internal
parse_json_response <- function(response, model, chat) {

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required. Install with: install.packages('jsonlite')")
  }

  # Parse the JSON suggestions from response
  suggestions <- tryCatch({
    # Response should be a JSON string
    parsed <- jsonlite::fromJSON(response, simplifyVector = FALSE)

    # If it's already parsed (has suggestions field), use it directly
    if (is.list(parsed) && "suggestions" %in% names(parsed)) {
      parsed$suggestions
    } else {
      # Otherwise, the whole thing might be the suggestions array
      parsed
    }
  }, error = function(e) {
    warning(sprintf("Failed to parse API response as JSON: %s\nRaw content: %s",
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

#' Call OpenAI API for Copyediting (Text Mode)
#'
#' Sends a text-only request to the OpenAI API using the ellmer package and
#' returns the parsed response. For documents with images, use call_openai_api_images()
#' instead.
#'
#' @param user_message Character. The user message text from build_prompt_text() for text mode.
#' @param system_prompt Character. The system prompt with copyediting instructions.
#'   If NULL, loads from config/system_prompt.txt.
#'
#' @details
#' This function uses the model specified in MODEL_TEXT (from config/model_config.R).
#' To change the model, edit MODEL_TEXT in config/model_config.R.
#'
#' Note: GPT-5 (reasoning model) does not support the temperature parameter.
#' Uses reasoning_effort = "minimal" for faster responses on copyediting tasks.
#' Retry settings are configured in config/model_config.R via MAX_RETRY_ATTEMPTS.
#'
#' @return A list with:
#'   \item{suggestions}{Parsed JSON array of copyediting suggestions}
#'   \item{model}{Model used for the request}
#'   \item{usage}{Token usage information (if available)}
#'   \item{response_metadata}{Full response metadata}
#'
#' @examples
#' \dontrun{
#'   # Parse document and build user messages
#'   parsed <- parse_document(mode = "text")
#'   user_msgs <- build_prompt_text(parsed, "external client-facing", "Healthcare executives")
#'
#'   # Call API (requires OPENAI_API_KEY environment variable)
#'   # system_prompt loads automatically from config/system_prompt.txt
#'   result <- call_openai_api(
#'     user_message = user_msgs$user_message[1]
#'   )
#'   suggestions <- result$suggestions
#' }
#'
#' @export
call_openai_api <- function(user_message,
                           system_prompt = NULL) {

  # Load required package
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("Package 'ellmer' is required. Install with: install.packages('ellmer')")
  }

  # Check API key is set in environment
  if (Sys.getenv("OPENAI_API_KEY") == "") {
    stop("OpenAI API key not found. Set OPENAI_API_KEY in your .Renviron file or use Sys.setenv(OPENAI_API_KEY = 'your-key').")
  }

  # Load system prompt if not provided
  if (is.null(system_prompt)) {
    system_prompt <- load_system_prompt()
  }

  # Validate inputs
  if (!is.character(user_message) || length(user_message) != 1) {
    stop("user_message must be a single character string")
  }

  # Create chat session with retry logic
  attempt <- 1
  last_error <- NULL

  while (attempt <= MAX_RETRY_ATTEMPTS) {
    tryCatch({
      # Create chat session (ellmer reads OPENAI_API_KEY from environment automatically)
      # GPT-5 is a reasoning model that doesn't support the temperature parameter
      # (only supports default value of 1)
      # Use reasoning_effort: minimal for faster responses on straightforward tasks like copyediting
      chat <- ellmer::chat_openai(
        system_prompt = system_prompt,
        model = MODEL_TEXT,
        api_args = list(
          reasoning_effort = "minimal"
        )
      )

      # Send message and get response
      response <- chat$chat(user_message)

      # Parse the JSON response
      result <- parse_json_response(response, MODEL_TEXT, chat)

      return(result)

    }, error = function(e) {
      last_error <- e

      # Extract detailed error information
      error_msg <- conditionMessage(e)

      # Try to extract the full error details from the httr response if available
      if (!is.null(e$parent) && inherits(e$parent, "error")) {
        error_msg <- paste(error_msg, "\nDetails:", conditionMessage(e$parent))
      }

      if (grepl("rate limit|429", error_msg, ignore.case = TRUE)) {
        message(sprintf("Rate limit hit (attempt %d/%d). Retrying in %d seconds...",
                       attempt, MAX_RETRY_ATTEMPTS, attempt * 2))
        Sys.sleep(attempt * 2)  # Exponential backoff
      } else if (grepl("500|502|503|504", error_msg, ignore.case = TRUE)) {
        message(sprintf("Server error (attempt %d/%d). Retrying in %d seconds...",
                       attempt, MAX_RETRY_ATTEMPTS, attempt * 2))
        Sys.sleep(attempt * 2)
      } else {
        # Don't retry on client errors - show full error details
        cat("\n=== Full API Error Details ===\n")
        cat("Error message:", error_msg, "\n")
        cat("Error class:", class(e), "\n")
        if (!is.null(e$call)) cat("Error call:", deparse(e$call), "\n")
        cat("==============================\n\n")
        stop(sprintf("API request failed: %s", error_msg))
      }
    })

    attempt <- attempt + 1
  }

  # If we get here, all retries failed
  stop(sprintf("API request failed after %d attempts: %s", MAX_RETRY_ATTEMPTS, last_error$message))
}


#' Call OpenAI API for Copyediting (Image Mode)
#'
#' Sends a multimodal request (text + images) to the OpenAI Vision API using
#' the ellmer package and returns the parsed response. For text-only documents,
#' use call_openai_api() instead.
#'
#' @param user_content List. The ellmer-formatted content from build_prompt_images().
#'   This should be a list of ellmer content objects (strings and content_image_file).
#' @param system_prompt Character. The system prompt with copyediting instructions.
#'   If NULL, loads from config/system_prompt.txt.
#'
#' @details
#' This function uses the model specified in MODEL_IMAGES (from config/model_config.R).
#' To change the model, edit MODEL_IMAGES in config/model_config.R.
#'
#' Note: GPT-5 (reasoning model) does not support the temperature parameter.
#' Uses reasoning_effort = "minimal" for faster responses on copyediting tasks.
#' Max_completion_tokens and retry settings are configured in config/model_config.R via
#' MAX_COMPLETION_TOKENS_IMAGES and MAX_RETRY_ATTEMPTS.
#'
#' @return A list with:
#'   \item{suggestions}{Parsed JSON array of copyediting suggestions}
#'   \item{model}{Model used for the request}
#'   \item{usage}{Token usage information (if available)}
#'   \item{response_metadata}{Full response metadata}
#'
#' @details
#' This function is designed for documents parsed in image mode (slide decks,
#' presentations, or documents with visual elements like charts/diagrams).
#' Images are handled by ellmer's content_image_file() helper. This is significantly
#' more expensive than text mode - use only when visual elements matter.
#'
#' The user_content parameter should be a list-column from build_prompt_images()
#' containing ellmer-formatted content (plain strings for text, content_image_file
#' objects for images).
#'
#' @examples
#' \dontrun{
#'   # Parse document as images
#'   slides <- parse_document(mode = "images")
#'
#'   # Build multimodal prompt (returns ellmer format)
#'   prompts <- build_prompt_images(
#'     slides,
#'     "external client-facing",
#'     "Healthcare executives"
#'   )
#'
#'   # Call API for first chunk (requires OPENAI_API_KEY environment variable)
#'   result <- call_openai_api_images(
#'     user_content = prompts$user_message[[1]]
#'   )
#'   suggestions <- result$suggestions
#' }
#'
#' @export
call_openai_api_images <- function(user_content,
                                   system_prompt = NULL) {

  # Load required package
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("Package 'ellmer' is required. Install with: install.packages('ellmer')")
  }

  # Check API key is set in environment
  if (Sys.getenv("OPENAI_API_KEY") == "") {
    stop("OpenAI API key not found. Set OPENAI_API_KEY in your .Renviron file or use Sys.setenv(OPENAI_API_KEY = 'your-key').")
  }

  # Load system prompt if not provided
  if (is.null(system_prompt)) {
    system_prompt <- load_system_prompt()
  }

  # Validate inputs
  if (!is.list(user_content) || length(user_content) == 0) {
    stop("user_content must be a non-empty list of ellmer content objects from build_prompt_images()")
  }

  # Create chat session with retry logic
  attempt <- 1
  last_error <- NULL

  while (attempt <= MAX_RETRY_ATTEMPTS) {
    tryCatch({
      # Create chat session (ellmer reads OPENAI_API_KEY from environment automatically)
      # GPT-5 is a reasoning model that:
      # - Requires max_completion_tokens instead of max_tokens
      # - Does not support temperature parameter (only accepts default value of 1)
      # - Use reasoning_effort: minimal for faster responses on straightforward tasks like copyediting
      chat <- ellmer::chat_openai(
        system_prompt = system_prompt,
        model = MODEL_IMAGES,
        api_args = list(
          max_completion_tokens = MAX_COMPLETION_TOKENS_IMAGES,
          reasoning_effort = "minimal"
        )
      )

      # Send multimodal message and get response
      # user_content is already in ellmer format (strings + content_image_file objects)
      response <- do.call(chat$chat, user_content)

      # Parse the JSON response
      result <- parse_json_response(response, MODEL_IMAGES, chat)

      return(result)

    }, error = function(e) {
      last_error <- e

      # Extract detailed error information
      error_msg <- conditionMessage(e)

      # Try to extract the full error details from the httr response if available
      if (!is.null(e$parent) && inherits(e$parent, "error")) {
        error_msg <- paste(error_msg, "\nDetails:", conditionMessage(e$parent))
      }

      if (grepl("rate limit|429", error_msg, ignore.case = TRUE)) {
        message(sprintf("Rate limit hit (attempt %d/%d). Retrying in %d seconds...",
                       attempt, MAX_RETRY_ATTEMPTS, attempt * 2))
        Sys.sleep(attempt * 2)  # Exponential backoff
      } else if (grepl("500|502|503|504", error_msg, ignore.case = TRUE)) {
        message(sprintf("Server error (attempt %d/%d). Retrying in %d seconds...",
                       attempt, MAX_RETRY_ATTEMPTS, attempt * 2))
        Sys.sleep(attempt * 2)
      } else {
        # Don't retry on client errors - show full error details
        cat("\n=== Full API Error Details ===\n")
        cat("Error message:", error_msg, "\n")
        cat("Error class:", class(e), "\n")
        if (!is.null(e$call)) cat("Error call:", deparse(e$call), "\n")
        cat("==============================\n\n")
        stop(sprintf("API request failed: %s", error_msg))
      }
    })

    attempt <- attempt + 1
  }

  # If we get here, all retries failed
  stop(sprintf("API request failed after %d attempts: %s", MAX_RETRY_ATTEMPTS, last_error$message))
}
