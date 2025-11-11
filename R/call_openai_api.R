# ==============================================================================
# Title:        OpenAI API Caller (using ellmer package)
# Last Updated: 2025-11-05
# Description:  Functions to call OpenAI API for copyediting using the ellmer package.
#               Supports both text-only and multimodal (image) modes.
# ==============================================================================

# Configuration ---------------------------------------------------------------
# Model selection for API calls

# Model for text-only copyediting (high quality, efficient for text)
MODEL_TEXT <- "gpt-4o"

# Model for image-based copyediting (vision-capable, best for reading text in images)
MODEL_IMAGES <- "gpt-4o"


# Helper Functions ------------------------------------------------------------

#' Load System Prompt from Config File
#'
#' Loads the system prompt from config/system_prompt.txt. This function is
#' used internally by both call_openai_api() and call_openai_api_images().
#'
#' @return Character string containing the system prompt.
#' @keywords internal
load_system_prompt <- function() {
  system_prompt_path <- file.path("config", "system_prompt.txt")
  if (!file.exists(system_prompt_path)) {
    stop("System prompt file not found at config/system_prompt.txt")
  }
  paste(readLines(system_prompt_path, warn = FALSE), collapse = "\n")
}


#' Call OpenAI API for Copyediting (Text Mode)
#'
#' Sends a text-only request to the OpenAI API using the ellmer package and
#' returns the parsed response. For documents with images, use call_openai_api_images()
#' instead.
#'
#' @param user_message Character. The user message text from build_prompt().
#' @param system_prompt Character. The system prompt with copyediting instructions.
#'   If NULL, loads from config/system_prompt.txt.
#' @param temperature Numeric. Sampling temperature between 0 and 2 (default: 0.3).
#'   Lower values make output more focused and deterministic.
#' @param max_retries Integer. Maximum number of retry attempts for failed requests (default: 3).
#'
#' @details
#' This function uses the model specified in MODEL_TEXT constant (currently "gpt-4o").
#' To change the model, edit the MODEL_TEXT constant at the top of call_openai_api.R.
#'
#' @return A list with:
#'   \item{suggestions}{Parsed JSON array of copyediting suggestions}
#'   \item{model}{Model used for the request}
#'   \item{usage}{Token usage information (if available)}
#'   \item{response_metadata}{Full response metadata}
#'
#' @examples
#' \dontrun{
#'   # Parse document and build prompt
#'   doc <- parse_document(mode = "text")
#'   prompts <- build_prompt(doc, "external client-facing", "Healthcare executives")
#'
#'   # Call API for first chunk (requires OPENAI_API_KEY environment variable)
#'   result <- call_openai_api(
#'     user_message = prompts$user_message[1]
#'   )
#'   # Parse document and build user messages
#'   parsed <- parse_document("report.pdf", mode = "text")
#'   user_msgs <- build_prompt(parsed, "external client-facing", "Healthcare executives")
#'
#'   # Load system prompt
#'   system_prompt <- paste(readLines("config/system_prompt.txt", warn = FALSE), collapse = "\n")
#'
#'   # Call API (requires OPENAI_API_KEY environment variable)
#'   result <- call_openai_api(
#'     user_message = user_msgs$user_message[1],
#'     system_prompt = system_prompt
#'   )
#'   suggestions <- result$suggestions
#' }
#'
#' @export
call_openai_api <- function(user_message,
                           system_prompt = NULL,
                           temperature = 0.3,
                           max_retries = 3) {

  # Load required package
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("Package 'ellmer' is required. Install with: install.packages('ellmer')")
  }

  # Get API key from environment variable
  api_key <- Sys.getenv("OPENAI_API_KEY")
  if (api_key == "") {
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

  if (temperature < 0 || temperature > 2) {
    stop("temperature must be between 0 and 2")
  }

  # Create chat session with retry logic
  attempt <- 1
  last_error <- NULL

  while (attempt <= max_retries) {
    tryCatch({
      # Create chat session
      chat <- ellmer::chat_openai(
        system_prompt = system_prompt,
        model = MODEL_TEXT,
        api_key = api_key,
        api_args = list(
          temperature = temperature,
          response_format = list(type = "json_object")
        )
      )

      # Send message and get response
      response <- chat$chat(user_message)

      # Parse the JSON response
      result <- parse_json_response(response, MODEL_TEXT, chat)

      return(result)

    }, error = function(e) {
      last_error <- e
      if (grepl("rate limit|429", e$message, ignore.case = TRUE)) {
        message(sprintf("Rate limit hit (attempt %d/%d). Retrying in %d seconds...",
                       attempt, max_retries, attempt * 2))
        Sys.sleep(attempt * 2)  # Exponential backoff
      } else if (grepl("500|502|503|504", e$message, ignore.case = TRUE)) {
        message(sprintf("Server error (attempt %d/%d). Retrying in %d seconds...",
                       attempt, max_retries, attempt * 2))
        Sys.sleep(attempt * 2)
      } else {
        # Don't retry on client errors
        stop(sprintf("API request failed: %s", e$message))
      }
    })

    attempt <- attempt + 1
  }

  # If we get here, all retries failed
  stop(sprintf("API request failed after %d attempts: %s", max_retries, last_error$message))
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
#' @param temperature Numeric. Sampling temperature between 0 and 2 (default: 0.3).
#'   Lower values make output more focused and deterministic.
#' @param max_tokens Integer. Maximum tokens in response (default: 16000).
#'   Higher for image mode due to potentially more issues to report.
#' @param max_retries Integer. Maximum number of retry attempts for failed requests (default: 3).
#'
#' @details
#' This function uses the model specified in MODEL_IMAGES constant (currently "gpt-4o").
#' To change the model, edit the MODEL_IMAGES constant at the top of call_openai_api.R.
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
                                  system_prompt = NULL,
                                  temperature = 0.3,
                                  max_tokens = 16000,
                                  max_retries = 3) {

  # Load required package
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("Package 'ellmer' is required. Install with: install.packages('ellmer')")
  }

  # Get API key from environment variable
  api_key <- Sys.getenv("OPENAI_API_KEY")
  if (api_key == "") {
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

  if (temperature < 0 || temperature > 2) {
    stop("temperature must be between 0 and 2")
  }

  # Create chat session with retry logic
  attempt <- 1
  last_error <- NULL

  while (attempt <= max_retries) {
    tryCatch({
      # Create chat session
      chat <- ellmer::chat_openai(
        system_prompt = system_prompt,
        model = MODEL_IMAGES,
        api_key = api_key,
        api_args = list(
          temperature = temperature,
          max_tokens = max_tokens,
          response_format = list(type = "json_object")
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
      if (grepl("rate limit|429", e$message, ignore.case = TRUE)) {
        message(sprintf("Rate limit hit (attempt %d/%d). Retrying in %d seconds...",
                       attempt, max_retries, attempt * 2))
        Sys.sleep(attempt * 2)  # Exponential backoff
      } else if (grepl("500|502|503|504", e$message, ignore.case = TRUE)) {
        message(sprintf("Server error (attempt %d/%d). Retrying in %d seconds...",
                       attempt, max_retries, attempt * 2))
        Sys.sleep(attempt * 2)
      } else {
        # Don't retry on client errors
        stop(sprintf("API request failed: %s", e$message))
      }
    })

    attempt <- attempt + 1
  }

  # If we get here, all retries failed
  stop(sprintf("API request failed after %d attempts: %s", max_retries, last_error$message))
}


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
