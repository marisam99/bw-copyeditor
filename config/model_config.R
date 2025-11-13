# ==============================================================================
# Model Configuration for BW Copyeditor
# ==============================================================================
# This file contains all centralized configuration settings for the copyediting tool.
# Modify values here to change model selections, context windows, and API parameters.

# Global Settings -------------------------------------------------------------
# Settings that apply across all modes (text and images)

#' Default sampling temperature for API calls
#' Lower values (closer to 0) make output more focused and deterministic.
#' Range: 0.0 to 2.0
#' NOTE: GPT-5 (reasoning model) does not support temperature parameter
#' This setting is retained for backward compatibility but not currently used
DEFAULT_TEMPERATURE <- 0.3

#' Maximum number of retry attempts for failed API requests
#' Used for rate limit errors (429) and server errors (500, 502, 503, 504)
MAX_RETRY_ATTEMPTS <- 3


# Text Mode Configuration -----------------------------------------------------
# Settings for text-only copyediting (publications, reports, text-heavy documents)

#' Model Options: 
MODEL_TEXT <- "gpt-5" # GPT-5 is a reasoning model with excellent performance

#' Maximum tokens per API request for text mode
CONTEXT_WINDOW_TEXT <- 400000

#' Reasoning level (minimal, low, medium, high)
REASONING_LEVEL <- "minimal" # GPT-5 only


# Image Mode Configuration ----------------------------------------------------
# Settings for image-based copyediting (slide decks, presentations, visual documents)

#' Model for image-based copyediting
#' Must support vision capabilities for reading text in images
#' GPT-5 has multimodal capabilities and is a reasoning model
MODEL_IMAGES <- "gpt-5"

#' Maximum tokens per API request for image mode
#' Lower than text mode due to image token overhead
CONTEXT_WINDOW_IMAGES <- 180000

#' Maximum completion tokens in response for image mode
#' GPT-5 reasoning models require max_completion_tokens instead of max_tokens
#' Higher than default due to potentially more issues to report from visual content
MAX_COMPLETION_TOKENS_IMAGES <- 16000

#' Image detail level for vision API
#' Options: "high" or "low" (high recommended for copyediting to catch all text)
DETAIL <- "high"

#' Maximum images per chunk for image mode
#' Conservative limit to avoid token overflow and ensure reliable processing
IMAGES_PER_CHUNK <- 20


# Helper Functions ------------------------------------------------------------

#' Load System Prompt from Config File
#'
#' Loads the system prompt from config/system_prompt.txt. This function is
#' used internally by API calling functions to load the copyediting instructions.
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
