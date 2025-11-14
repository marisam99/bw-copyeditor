# Configuration Files and Explanations

This directory contains configuration files and information for the bw-copyeditor tool. For more information on technical specifications, reach out to Marisa.

## Files

### `model_config.R` : Central configuration for models, token limits, and API settings.

**Global Settings (apply to both text and image mode):**\
- `REASONING_LEVEL` : Applies to GPT-5 only; determines the amount of time GPT-5 should spend "thinking" about the task (minimal, low, medium, or high) \| default: "minimal"\
- `MAX_RETRY_ATTEMPTS` : Retry attempts for API failures \| default: 3

**Text Mode Settings:**

\- `MODEL_TEXT` : Model for text mode \| default: GPT-5\
- `CONTEXT_WINDOW_TEXT` : Token limit for text mode \| default: 400,000 (GPT-5's max)

**Image Mode Settings:**

\- `MODEL_IMAGES` : Model for image mode \| default: GPT-5\
- `IMAGES_PER_CHUNK` : Images per chunk that will be passed to the API \| default: 20\
- `DETAIL_SETTING` : resolution of images (low or high) \| default: "high"\
- `MAX_COMPLETION_TOKENS_IMAGES` : Max output tokens for image mode (30,000)\
- `CONTEXT_WINDOW_IMAGES` : Input token limit for images \| default: 180,000

**To customize:**\
1. Open `config/model_config.R`\
2. Edit the configuration constants\
3. Save and reload your R session

### `system_prompt.txt` : Copyediting instructions and Bellwether style guide.

This system prompt was developed using Bellwether's Style Guide (see original [here](https://docs.google.com/document/d/1EPbXSIdTAQKoA7ypYev3h3lgRpifAc1c309Ks0AZ1iE/edit?usp=drive_link)) and in collaboration with Amber. It informs how the AI model should behave when evaluating the documents sent. This is automatically loaded through the R scripts; there is no need to pre-load it.

**IMPORTANT**: The system prompt is available to view for transparency; however, **DO NOT EDIT IT**. For questions about or suggestions for the instructions or style guide, reach out to Marisa or Amber.