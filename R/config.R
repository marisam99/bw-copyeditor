# ==============================================================================
# Global Configuration for BW Copyeditor
# ==============================================================================
# This file contains all centralized configuration settings for the copyediting tool.
# Modify values here to change model selections, context windows, and API parameters.

# Global Settings -------------------------------------------------------------
# Settings that apply across all modes (text and images)

#' Default sampling temperature for API calls
#' Lower values (closer to 0) make output more focused and deterministic.
#' Range: 0.0 to 2.0
DEFAULT_TEMPERATURE <- 0.3

#' Maximum number of retry attempts for failed API requests
#' Used for rate limit errors (429) and server errors (500, 502, 503, 504)
MAX_RETRY_ATTEMPTS <- 3


# Text Mode Configuration -----------------------------------------------------
# Settings for text-only copyediting (publications, reports, text-heavy documents)

#' Model for text-only copyediting
#' High quality and efficient for text processing
MODEL_TEXT <- "gpt-4o"

#' Maximum tokens per API request for text mode
#' gpt-4o supports 128k context window, but we use 400k as conservative estimate
CONTEXT_WINDOW_TEXT <- 400000


# Image Mode Configuration ----------------------------------------------------
# Settings for image-based copyediting (slide decks, presentations, visual documents)

#' Model for image-based copyediting
#' Must support vision capabilities for reading text in images
MODEL_IMAGES <- "gpt-4o"

#' Maximum tokens per API request for image mode
#' Same as text mode for consistency
CONTEXT_WINDOW_IMAGES <- 400000

#' Maximum tokens in response for image mode
#' Higher than default due to potentially more issues to report from visual content
MAX_TOKENS_IMAGES <- 16000
