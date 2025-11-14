# Configuration Files

This directory contains configuration files for the bw-copyeditor tool. For more specific explanations of why certain settings were chosen, see the primary README file.

## Files

### `model_config.R` : Central configuration for models, token limits, and API settings.

**Global Settings (apply to both text and image mode):** \
- `REASONING_LEVEL` : Applies to GPT-5 only; determines the amount of time GPT-5 should spend "thinking" about the task (minimal, low, medium, or high) \| default: "minimal"\
- `MAX_RETRY_ATTEMPTS` : Retry attempts for API failures \| default: 3

**Text Mode Settings:**

\- `MODEL_TEXT` : Model for text mode \| default: GPT-5\
- `CONTEXT_WINDOW_TEXT` : Token limit for text mode \| default: 400,000 (GPT-5's max)

**Image Mode Settings:**

\- `MODEL_IMAGES` : Model for image mode \| default: GPT-5\
- `IMAGES_PER_CHUNK` : Images per chunk that will be passed to the API \| default: 20 \
- `DETAIL_SETTING` : resolution of images (low or high) \| default: "high"\
 - `MAX_COMPLETION_TOKENS_IMAGES` : Max output tokens for image mode (30,000)\
- `CONTEXT_WINDOW_IMAGES` : Input token limit for images \| default: 180,000

**To customize:** \
1. Open `config/model_config.R` \
2. Edit the configuration constants \
3. Save and reload your R session

### `system_prompt.txt` : The copyediting instructions and Bellwether style guide. 

This is automatically loaded; there is no need to customize. For questions about the instructions or style guide, reach out to Marisa or Amber.