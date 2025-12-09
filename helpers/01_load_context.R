# ==============================================================================
# Title:        Load System Prompt
# Description:  Functions to load system prompt and related information from config directory.
#               Uses rtiktoken for accurate token counting matching OpenAI's tokenizers.
# Output:       Global variables SYSTEM_PROMPT, SYSTEM_PROMPT_TOKENS
# ==============================================================================

# Load System Prompt from Config File-------------------------------------------
# Loads the copyediting instructions and style guide.
system_prompt_path <- file.path("config", "system_prompt.txt")
if (!file.exists(system_prompt_path)) {
    stop("System prompt file not found at config/system_prompt.txt")
  }
  SYSTEM_PROMPT <- paste(readLines(system_prompt_path, warn = FALSE), collapse = "\n")
rm(system_prompt_path) # clean up

# Estimate Token Count of System Prompt -----------------------------------------
SYSTEM_PROMPT_TOKENS <- estimate_tokens(SYSTEM_PROMPT)


# Create Project Context Header -------------------------------------------------
#' Project Context Header
#'
#' Creates the header section with document type and audience.
#'
#' @param document_type Type of document (see README for examples).
#' @param audience Target audience description (see README for examples).
#' @return Formatted header text.
#' @keywords internal
context_header <- function(document_type, audience) {
  header <- paste0(
    "---\n",
    "Type of Document: ", document_type, "\n",
    "Audience: ", audience, "\n",
    "---"
  )
  return(header)
}
