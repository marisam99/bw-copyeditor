# ==============================================================================
# Title:        Model Configuration
# Description:  Centralized configuration settings for the AI model used in the copyeditor.
#               Modify values here to change model selections, context windows, and API parameters.
# ==============================================================================

# API Metadata Configuration ------------------------------------------------------
# Metadata attached to all API requests for tracking in OpenAI Platform logs

#' Current development phase for tracking experiments and releases
PHASE <- "eval_rd1"  # Options: "dev", "eval_rd1", "eval_rd2", "beta", "prod"

#' System prompt version for tracking prompt iterations
SYSTEM_PROMPT_VERSION <- "2025-12-10.v4"

#' System prompt version for tracking prompt iterations
STORAGE_MODE <- TRUE

# GLOBAL Model Settings -------------------------------------------------------------
# Settings that apply across all modes (text and images)

#' Maximum number of retry attempts for failed API requests
#' Used for rate limit errors (429) and server errors (500, 502, 503, 504)
MAX_RETRY_ATTEMPTS <- 3

#' Default reasoning level for reasoning API calls. (none, medium, high)
#' NOTE: GPT-4o and 4.1 are not reasoning models and do not support this parameter
REASONING_LEVEL <- "medium"

# TEXT Mode Configuration -----------------------------------------------------
# Settings for text-only copyediting (publications, reports, text-heavy documents)

#' Model: 
MODEL_TEXT <- "gpt-5.1"

#' Maximum tokens per API request for text mode
CONTEXT_WINDOW_TEXT <- 400000

# Image Mode Configuration ----------------------------------------------------
# Settings for image-based copyediting (slide decks, presentations, visual documents)

#' Model for image-based copyediting (must support computer vision)
MODEL_IMAGES <- "gpt-5.1"

#' Maximum tokens per API request for image mode
CONTEXT_WINDOW_IMAGES <- 180000 # Lower than text mode due to image token overhead

#' Maximum completion tokens in response for image mode
#' Note: GPT-5.1 requires max_output_tokens instead of max_tokens;
#'      previous models will not use this parameter
MAX_TOKENS_IMAGES <- 16000 
#' Higher than default due to potentially more issues to report from visual content

#' Image detail level for vision API (high or low)
DETAIL_SETTING <- "high" # high recommended for copyediting to catch all text

# Estimate tokens using rtiktoken based on model configurations----------------
#' Estimate Text-Based Token Count
#'
#' Counts tokens in text using OpenAI's tokenizers.
#'
#' @param text Text to count tokens for.
#' @return Exact token count.
#' @keywords internal
estimate_tokens <- function(text) {
  tokenizer_model <- MODEL_TEXT # the model rtiktoken will use to calculate estimates, set in model_config.R

  # For newer models not yet supported by rtiktoken, such as GPT-5, fall back to 4o
  if (grepl("^gpt-5", tokenizer_model, ignore.case = TRUE)) {
    tokenizer_model <- "gpt-4o"

    # Only show message once (when model_config.R is first sourced)
    if (!exists(".tokenizer_msg_shown", envir = .GlobalEnv)) {
      message(sprintf("Using gpt-4o tokenizer for %s (rtiktoken doesn't support it yet)", MODEL_TEXT))
      assign(".tokenizer_msg_shown", TRUE, envir = .GlobalEnv)
    }
  }

  # Count tokens using rtiktoken
  token_count <- get_token_count(text, model = tokenizer_model)
  return(token_count)
}