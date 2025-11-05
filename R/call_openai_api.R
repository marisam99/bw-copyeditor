# ==============================================================================
# Title:        OpenAI API Caller (using ellmer package)
# Last Updated: 2025-11-05
# Description:  Functions to call OpenAI API for copyediting using the ellmer package.
#               Supports both text-only and multimodal (image) modes.
# ==============================================================================

#' Call OpenAI API for Copyediting (Text Mode)
#'
#' Sends a text-only request to the OpenAI API using the ellmer package and
#' returns the parsed response. For documents with images, use call_openai_api_images()
#' instead.
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
#'   # Call API for first chunk
#'   result <- call_openai_api(
#'     user_message = prompts$user_message[1],
#'     api_key = "sk-..."
#'   )
#'   # Parse document and build user messages
#'   parsed <- parse_document("report.pdf", mode = "text")
#'   user_msgs <- build_prompt(parsed, "external client-facing", "Healthcare executives")
#'
#'   # Load system prompt
#'   system_prompt <- paste(readLines("config/system_prompt_template.txt", warn = FALSE), collapse = "\n")
#'
#'   # Construct messages array
#'   messages <- list(
#'     list(role = "system", content = system_prompt),
#'     list(role = "user", content = user_msgs$user_message[1])
#'   )
#'
#'   # Call API
#'   result <- call_openai_api(messages, api_key = "sk-...")
#'   suggestions <- result$suggestions
#' }
#'
#' @export
call_openai_api <- function(user_message,
                           system_prompt = NULL,
                           model = "gpt-4o",
                           api_key = NULL,
                           temperature = 0.3,
                           max_retries = 3) {

  # Load required package
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("Package 'ellmer' is required. Install with: install.packages('ellmer')")
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

  # Create chat session with retry logic
  attempt <- 1
  last_error <- NULL

  while (attempt <= max_retries) {
    tryCatch({
      # Create chat session
      chat <- ellmer::chat_openai(
        system_prompt = system_prompt,
        model = model,
        api_key = api_key,
        api_args = list(
          temperature = temperature,
          response_format = list(type = "json_object")
        )
      )

      # Send message and get response
      response <- chat$chat(user_message)

      # Parse the JSON response
      result <- parse_json_response(response, model, chat)

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
#'   If NULL, loads from config/llm_instructions.txt.
#' @param model Character. Vision-capable OpenAI model to use (default: "gpt-4o").
#'   Options: "gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o1", etc. Must support vision.
#' @param api_key Character. OpenAI API key. If NULL, will attempt to read
#'   from OPENAI_API_KEY environment variable.
#' @param temperature Numeric. Sampling temperature between 0 and 2 (default: 0.3).
#'   Lower values make output more focused and deterministic.
#' @param max_tokens Integer. Maximum tokens in response (default: 16000).
#'   Higher for image mode due to potentially more issues to report.
#' @param max_retries Integer. Maximum number of retry attempts for failed requests (default: 3).
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
                                  max_retries = 3) {

  # Load required package
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("Package 'ellmer' is required. Install with: install.packages('ellmer')")
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
    stop("user_content must be a non-empty list of ellmer content objects from build_prompt_images()")
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

  # Create chat session with retry logic
  attempt <- 1
  last_error <- NULL

  while (attempt <= max_retries) {
    tryCatch({
      # Create chat session
      chat <- ellmer::chat_openai(
        system_prompt = system_prompt,
        model = model,
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
      result <- parse_json_response(response, model, chat)

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
      finish_reason = turn$finish_reason %||% "unknown",
      created = turn$created %||% Sys.time(),
      id = turn$id %||% NA
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


#' Null-coalescing operator
#'
#' Returns left-hand side if not NULL, otherwise returns right-hand side.
#'
#' @param x First value
#' @param y Default value if x is NULL
#'
#' @return x if not NULL, otherwise y
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
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
