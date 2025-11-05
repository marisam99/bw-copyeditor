#' Call OpenAI API for Copyediting (Text Mode)
#'
#' Sends a text-only request to the OpenAI API with the constructed prompt and
#' returns the parsed response. For documents with images, use call_openai_api_images()
#' instead. Includes error handling and rate limiting support.
#'
#' @param user_message Character. The user message text from build_prompt().
#' @param system_prompt Character. The system prompt with copyediting instructions.
#'   If NULL, loads from config/llm_instructions.txt.
#' @param model Character. OpenAI model to use (default: "gpt-4o").
#'   Options: "gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o1", etc.
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
#'   # Parse document and build prompt
#'   doc <- parse_document(mode = "text")
#'   prompts <- build_prompt(doc, "external client-facing", "Healthcare executives")
#'
#'   # Call API for first chunk
#'   result <- call_openai_api(
#'     user_message = prompts$user_message[1],
#'     api_key = "sk-..."
#'   )
#'   suggestions <- result$suggestions
#' }
#'
#' @export
call_openai_api <- function(user_message,
                           system_prompt = NULL,
                           model = "gpt-4o",
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

  # Load system prompt if not provided
  if (is.null(system_prompt)) {
    system_prompt_path <- file.path("config", "llm_instructions.txt")
    if (file.exists(system_prompt_path)) {
      system_prompt <- paste(readLines(system_prompt_path, warn = FALSE), collapse = "\n")
    } else {
      stop("System prompt not provided and config/llm_instructions.txt not found")
    }
  }

  # Validate inputs
  if (!is.character(user_message) || length(user_message) != 1) {
    stop("user_message must be a single character string")
  }

  if (temperature < 0 || temperature > 2) {
    stop("temperature must be between 0 and 2")
  }

  # Build messages array (system + user)
  messages <- list(
    list(role = "system", content = system_prompt),
    list(role = "user", content = user_message)
  )

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


#' Call OpenAI API for Copyediting (Image Mode)
#'
#' Sends a multimodal request (text + images) to the OpenAI Vision API with the
#' constructed prompt and returns the parsed response. For text-only documents,
#' use call_openai_api() instead. Includes error handling and rate limiting support.
#'
#' @param user_content List. The multimodal content array from build_prompt_images().
#'   This should be a list of content objects with type "text" or "image_url".
#' @param system_prompt Character. The system prompt with copyediting instructions.
#'   If NULL, loads from config/llm_instructions.txt.
#' @param model Character. Vision-capable OpenAI model to use (default: "gpt-4o").
#'   Options: "gpt-4o", "gpt-4-turbo", "o1", etc. Must support vision.
#' @param api_key Character. OpenAI API key. If NULL, will attempt to read
#'   from OPENAI_API_KEY environment variable.
#' @param temperature Numeric. Sampling temperature between 0 and 2 (default: 0.3).
#'   Lower values make output more focused and deterministic.
#' @param max_tokens Integer. Maximum tokens in response (default: 16000).
#'   Higher for image mode due to potentially more issues to report.
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
#' @details
#' This function is designed for documents parsed in image mode (slide decks,
#' presentations, or documents with visual elements like charts/diagrams).
#' Each page is sent as a base64-encoded PNG image. This is significantly more
#' expensive than text mode - use only when visual elements matter.
#'
#' The user_content parameter should be a list-column from build_prompt_images()
#' containing multimodal content with both text and image_url objects.
#'
#' @examples
#' \dontrun{
#'   # Parse document as images
#'   slides <- parse_document(mode = "images")
#'
#'   # Build multimodal prompt
#'   prompts <- build_prompt_images(
#'     slides,
#'     "external client-facing",
#'     "Healthcare executives"
#'   )
#'
#'   # Call API for first chunk
#'   result <- call_openai_api_images(
#'     user_content = prompts$user_message[[1]],
#'     api_key = "sk-..."
#'   )
#'   suggestions <- result$suggestions
#' }
#'
#' @export
call_openai_api_images <- function(user_content,
                                  system_prompt = NULL,
                                  model = "gpt-4o",
                                  api_key = NULL,
                                  temperature = 0.3,
                                  max_tokens = 16000,
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

  # Load system prompt if not provided
  if (is.null(system_prompt)) {
    system_prompt_path <- file.path("config", "llm_instructions.txt")
    if (file.exists(system_prompt_path)) {
      system_prompt <- paste(readLines(system_prompt_path, warn = FALSE), collapse = "\n")
    } else {
      stop("System prompt not provided and config/llm_instructions.txt not found")
    }
  }

  # Validate inputs
  if (!is.list(user_content) || length(user_content) == 0) {
    stop("user_content must be a non-empty list of content objects from build_prompt_images()")
  }

  if (temperature < 0 || temperature > 2) {
    stop("temperature must be between 0 and 2")
  }

  # Validate that model supports vision
  vision_models <- c("gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o1", "o1-mini")
  if (!model %in% vision_models) {
    warning(sprintf(
      "Model '%s' may not support vision. Recommended models: %s",
      model, paste(vision_models, collapse = ", ")
    ))
  }

  # Build messages array (system + user with multimodal content)
  messages <- list(
    list(role = "system", content = system_prompt),
    list(role = "user", content = user_content)
  )

  # Build request body
  body <- list(
    model = model,
    messages = messages,
    temperature = temperature,
    max_tokens = max_tokens,
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
#' Lists models for both text-only and vision-capable (image) modes.
#'
#' @param mode Character. Show models for "text", "images", or "all" (default: "all").
#'
#' @return Character vector of model names (invisibly).
#'
#' @examples
#' get_available_models()
#' get_available_models("text")
#' get_available_models("images")
#'
#' @export
get_available_models <- function(mode = c("all", "text", "images")) {

  mode <- match.arg(mode)

  text_models <- c(
    "gpt-4o",           # Recommended: Best balance of performance and cost
    "gpt-4o-mini",      # Budget option: Cheaper and faster
    "gpt-4-turbo",      # Previous generation
    "o1",               # Reasoning model (higher cost)
    "o1-mini"           # Smaller reasoning model
  )

  vision_models <- c(
    "gpt-4o",           # Recommended: Best for vision tasks
    "gpt-4o-mini",      # Budget option with vision support
    "gpt-4-turbo",      # Previous generation with vision
    "o1",               # Reasoning model with vision
    "o1-mini"           # Smaller reasoning model with vision
  )

  if (mode == "text") {
    cat("OpenAI models for text-only copyediting:\n")
    cat("(Use with call_openai_api())\n\n")
    for (i in seq_along(text_models)) {
      cat(sprintf("  %d. %s\n", i, text_models[i]))
    }
    cat("\nRecommended: gpt-4o (best balance of quality and cost)\n")
    return(invisible(text_models))

  } else if (mode == "images") {
    cat("Vision-capable OpenAI models for image-based copyediting:\n")
    cat("(Use with call_openai_api_images())\n\n")
    for (i in seq_along(vision_models)) {
      cat(sprintf("  %d. %s\n", i, vision_models[i]))
    }
    cat("\nRecommended: gpt-4o (best for reading text in images)\n")
    cat("Note: Image mode is significantly more expensive than text mode.\n")
    return(invisible(vision_models))

  } else {
    # Show all
    cat("OpenAI models for copyediting:\n\n")

    cat("TEXT MODE (call_openai_api):\n")
    for (i in seq_along(text_models)) {
      cat(sprintf("  %d. %s\n", i, text_models[i]))
    }

    cat("\nIMAGE MODE (call_openai_api_images):\n")
    for (i in seq_along(vision_models)) {
      cat(sprintf("  %d. %s\n", i, vision_models[i]))
    }

    cat("\nRecommended: gpt-4o for both modes\n")
    cat("Note: Image mode is significantly more expensive. Use only for visual documents.\n")
    cat("\nCheck OpenAI documentation for latest pricing and availability.\n")

    return(invisible(list(text = text_models, images = vision_models)))
  }
}
