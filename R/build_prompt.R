#' Build Prompt for OpenAI API
#'
#' Constructs the messages array for OpenAI API request, including system prompt
#' with style guide and user message with text to copyedit.
#'
#' @param text_chunk Character. The text content to be copyedited.
#' @param page_num Integer. The page number of the text chunk.
#' @param project_context Character. Project-specific context or background information.
#' @param system_prompt Character. The system prompt containing style guide and instructions.
#'   If NULL, a default prompt will be used.
#'
#' @return A list representing the messages array for OpenAI API, with:
#'   \item{system}{System message with style guide}
#'   \item{user}{User message with text to review}
#'
#' @examples
#' \dontrun{
#'   messages <- build_prompt(
#'     text_chunk = "The data shows that...",
#'     page_num = 1,
#'     project_context = "Annual report for healthcare client",
#'     system_prompt = "You are a copyeditor..."
#'   )
#' }
#'
#' @export
build_prompt <- function(text_chunk,
                        page_num,
                        project_context = "",
                        system_prompt = NULL) {

  # Validate inputs
  if (missing(text_chunk) || is.null(text_chunk) || nchar(trimws(text_chunk)) == 0) {
    stop("text_chunk cannot be empty")
  }

  if (missing(page_num) || !is.numeric(page_num)) {
    stop("page_num must be a numeric value")
  }

  # Use default system prompt if none provided
  if (is.null(system_prompt)) {
    system_prompt <- get_default_system_prompt()
  }

  # Build the user message
  user_message <- build_user_message(text_chunk, page_num, project_context)

  # Return messages in OpenAI format
  messages <- list(
    list(
      role = "system",
      content = system_prompt
    ),
    list(
      role = "user",
      content = user_message
    )
  )

  return(messages)
}


#' Build User Message
#'
#' Constructs the user message portion of the prompt.
#'
#' @param text_chunk Character. The text to copyedit.
#' @param page_num Integer. Page number.
#' @param project_context Character. Project context.
#'
#' @return Character string with formatted user message.
#' @keywords internal
build_user_message <- function(text_chunk, page_num, project_context) {

  # Start building message
  message_parts <- c()

  # Add project context if provided
  if (!is.null(project_context) && nchar(trimws(project_context)) > 0) {
    message_parts <- c(
      message_parts,
      "PROJECT CONTEXT:",
      project_context,
      ""
    )
  }

  # Add page information and text
  message_parts <- c(
    message_parts,
    sprintf("PAGE NUMBER: %d", page_num),
    "",
    "TEXT TO COPYEDIT:",
    "---",
    text_chunk,
    "---",
    "",
    "Please review the above text and provide copyediting suggestions in the specified JSON format."
  )

  # Combine into single message
  user_message <- paste(message_parts, collapse = "\n")

  return(user_message)
}


#' Get Default System Prompt
#'
#' Returns the default system prompt with instructions for copyediting.
#' Users should typically provide their own system prompt with embedded style guide.
#'
#' @return Character string with default system prompt.
#' @keywords internal
get_default_system_prompt <- function() {

  prompt <- "You are a professional copyeditor. Review the provided text and identify issues related to:
- Grammar and punctuation
- Style and clarity
- Consistency
- Spelling and typos

Return your findings as a JSON array where each object has the following structure:
{
  \"page_number\": <integer>,
  \"location\": \"<brief description of where the issue occurs>\",
  \"original_text\": \"<the problematic text>\",
  \"suggested_edit\": \"<your proposed correction>\",
  \"edit_type\": \"<one of: grammar, style, clarity, consistency, spelling>\",
  \"reason\": \"<brief explanation of why this edit is needed>\",
  \"severity\": \"<one of: critical, recommended, optional>\",
  \"confidence\": <number between 0 and 1>
}

IMPORTANT: Return ONLY the JSON array, with no additional text before or after. If there are no issues, return an empty array: []"

  return(prompt)
}


#' Load Custom System Prompt from File
#'
#' Helper function to load a system prompt from a text file.
#' Useful for maintaining style guides in separate files.
#'
#' @param file_path Character. Path to the system prompt file.
#'
#' @return Character string with the system prompt content.
#'
#' @examples
#' \dontrun{
#'   system_prompt <- load_system_prompt("config/bellwether_style_prompt.txt")
#'   messages <- build_prompt(text, page_num, context, system_prompt)
#' }
#'
#' @export
load_system_prompt <- function(file_path) {

  if (!file.exists(file_path)) {
    stop(sprintf("System prompt file not found: %s", file_path))
  }

  prompt <- readLines(file_path, warn = FALSE)
  prompt <- paste(prompt, collapse = "\n")

  if (nchar(trimws(prompt)) == 0) {
    stop("System prompt file is empty")
  }

  return(prompt)
}
