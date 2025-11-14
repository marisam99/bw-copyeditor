# ==============================================================================
# Model Configuration for BW Copyeditor
# ==============================================================================
# This file contains all centralized configuration settings for the copyediting tool.
# Modify values here to change model selections, context windows, and API parameters.

# Global Settings -------------------------------------------------------------
# Settings that apply across all modes (text and images)

#' Default sampling temperature for non-reasoning API calls. Range: 0.0-2.0
#' Lower values (closer to 0) make output more focused and deterministic.
#' NOTE: GPT-5 (reasoning model) does not support temperature parameter
#' This setting is retained for backward compatibility but not currently used.
DEFAULT_TEMPERATURE <- 0.3

#' Maximum number of retry attempts for failed API requests
#' Used for rate limit errors (429) and server errors (500, 502, 503, 504)
MAX_RETRY_ATTEMPTS <- 3

#' Default reasoning level for reasoning API calls. (minimal, low, medium, high)
#' NOTE: GPT-4o and 4.1 are not reasoning models and do not support this parameter
REASONING_LEVEL <- "minimal" # GPT-5 only

#' Pricing for input tokens
COST_PER_1M <- 1.25 # for GPT-5, as of November 13, 2025


# Text Mode Configuration -----------------------------------------------------
# Settings for text-only copyediting (publications, reports, text-heavy documents)

#' Model: 
MODEL_TEXT <- "gpt-5" # GPT-5 is a reasoning model with balanced costs

#' Maximum tokens per API request for text mode
CONTEXT_WINDOW_TEXT <- 400000


# Image Mode Configuration ----------------------------------------------------
# Settings for image-based copyediting (slide decks, presentations, visual documents)

#' Model for image-based copyediting (must support computer vision)
MODEL_IMAGES <- "gpt-5" # GPT-5 has multimodal capabilities

#' Maximum tokens per API request for image mode
CONTEXT_WINDOW_IMAGES <- 180000 # Lower than text mode due to image token overhead

#' Maximum completion tokens in response for image mode
#' Note: GPT-5 requires max_completion_tokens instead of max_tokens;
#'      previous models will not use this parameter
MAX_COMPLETION_TOKENS_IMAGES <- 16000 
#' Higher than default due to potentially more issues to report from visual content

#' Image detail level for vision API (high or low)
DETAIL_SETTING <- "high" # high recommended for copyediting to catch all text


# Helper Functions ------------------------------------------------------------

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
  token_count <- rtiktoken::get_token_count(text, model = tokenizer_model)
  return(token_count)
}