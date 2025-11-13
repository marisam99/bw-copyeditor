# Configuration Files

Configuration files for the bw-copyeditor tool.

## Files

### `model_config.R`

Central configuration for models, token limits, and API settings.

**Key settings:**
- `MODEL_TEXT` - Model for text mode (default: "gpt-5")
- `MODEL_IMAGES` - Model for image mode (default: "gpt-5")
- `CONTEXT_WINDOW_TEXT` - Token limit for text mode (400,000)
- `CONTEXT_WINDOW_IMAGES` - Token limit for image mode (180,000)
- `IMAGES_PER_CHUNK` - Images per chunk in image mode (20)
- `DETAIL` - Image detail level: "high" or "low" (default: "high")
- `REASONING_LEVEL` - GPT-5 reasoning effort: "low", "minimal", "high" (default: "minimal")
- `MAX_RETRY_ATTEMPTS` - Retry attempts for API failures (3)
- `MAX_COMPLETION_TOKENS_IMAGES` - Max output tokens for image mode (30,000)

**To customize:**
1. Open `config/model_config.R`
2. Edit the configuration constants
3. Save and reload your R session

### `system_prompt.txt`

The copyediting instructions and Bellwether style guide. Automatically loaded by the tool.

**To customize:**
1. Edit `config/system_prompt.txt`
2. Keep the JSON output structure intact
3. Modify the style guide rules as needed

**What to customize:**
- Writing style preferences (voice, tone)
- Organization-specific terminology
- Number and date formatting
- Punctuation rules
- Citation styles
- Severity guidelines

**Important**: The system prompt expects JSON output. Do not remove the JSON structure requirements.

## How Configuration Works

The tool automatically loads configuration when you run `process_document()`:

```r
# Load main function (sources config automatically)
source("R/process_document.R")

# Configuration is loaded from:
# - config/model_config.R (model settings)
# - config/system_prompt.txt (style guide)
```

## Document Type and Audience

Instead of custom project context files, the tool uses two parameters:

```r
results <- process_document(
  mode = "text",
  document_type = "external client-facing",
  audience = "Healthcare executives"
)
```

These parameters are automatically included in the prompt sent to the API.

**Common document types:**
- "external client-facing"
- "external field-facing"
- "internal"

**Audience examples:**
- "Healthcare executives"
- "Technical staff"
- "Leadership team"
- "General public"

## Customizing for Different Projects

### Option 1: Multiple System Prompts

Create different system prompt files for different clients or document types:

```
config/
├── model_config.R
├── system_prompt.txt              # Default
├── system_prompt_technical.txt    # For technical docs
└── system_prompt_client_a.txt     # Client-specific
```

Then modify `config/model_config.R` to load the appropriate file:

```r
# In model_config.R, change this line:
SYSTEM_PROMPT <- load_system_prompt(file.path("config", "system_prompt_technical.txt"))
```

### Option 2: Environment-Specific Settings

Use different `model_config.R` settings for different projects:

```r
# For cost-sensitive projects:
MODEL_TEXT <- "gpt-4o"  # Instead of gpt-5

# For high-priority projects:
REASONING_LEVEL <- "high"  # Instead of minimal
```

## Tips

1. **Test changes incrementally**: Process a sample document after each config change
2. **Monitor token usage**: Check console output for token counts and costs
3. **Balance quality vs. cost**: GPT-5 with "minimal" reasoning is good for most copyediting
4. **Keep system prompts focused**: Long prompts increase API costs
5. **Version control**: Track changes to system prompts in git

## Token Limits and Chunking

The tool automatically chunks large documents based on these settings:

- **Text mode**: Uses `CONTEXT_WINDOW_TEXT` (400K tokens)
  - Counts exact tokens using `rtiktoken` package
  - Splits at 90% of limit for safety

- **Image mode**: Uses `IMAGES_PER_CHUNK` (20 images)
  - Each high-detail image ~2,805 tokens
  - Total limit: `CONTEXT_WINDOW_IMAGES` (180K tokens)

To process larger documents:
- Increase `CONTEXT_WINDOW_TEXT` if your model supports it
- Adjust `IMAGES_PER_CHUNK` for image mode (balance between chunks and total tokens)

## Example Customization

For a technical documentation project:

1. **Edit `config/system_prompt.txt`:**
   ```
   You are a technical copyeditor specializing in software documentation.

   Key rules:
   - Use active voice
   - Prefer "we" over "I"
   - Technical terms: keep consistent (e.g., "API" not "api")
   ...
   ```

2. **Adjust `config/model_config.R` if needed:**
   ```r
   MODEL_TEXT <- "gpt-4o"  # Lower cost for routine edits
   REASONING_LEVEL <- "minimal"  # Fast responses
   ```

3. **Use in your script:**
   ```r
   source("R/process_document.R")

   results <- process_document(
     mode = "text",
     document_type = "technical documentation",
     audience = "Software developers"
   )
   ```

## Support

For questions about configuration, see the main `README.md` or `CLAUDE.md` for project context.
