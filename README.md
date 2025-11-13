# bw-copyeditor

An R tool that uses OpenAI's LLM models to identify copyediting issues in PDF documents according to Bellwether style conventions.

## What It Does

- **Input**: PDF file (reports or slide decks)
- **Output**: Table of suggested edits with page numbers, issues, and explanations
- **Important**: This tool flags errors for human review — it does not automatically fix them

## Features

- **Two Modes**: Text mode for reports, image mode for slide decks
- **Automatic Chunking**: Splits large documents to fit within API limits
- **Page Tracking**: Maintains page numbers for all suggestions
- **Export to CSV**: Results automatically saved with timestamp
- **Custom Style Guide**: Uses project-specific copyediting rules

## Installation

### Prerequisites

```r
install.packages(c("pdftools", "tidyverse", "ellmer", "glue", "rtiktoken", "jsonlite", "base64enc"))
```

### Setup

Set your OpenAI API key:

```r
# In your .Renviron file:
OPENAI_API_KEY=sk-your-api-key-here
```

Or in R:
```r
Sys.setenv(OPENAI_API_KEY = "sk-your-api-key-here")
```

## Quick Start

```r
# Load the main function
source("R/process_document.R")

# Process a text document (report, publication)
results <- process_document(
  mode = "text",
  document_type = "external client-facing",
  audience = "Healthcare executives"
)

# Process a slide deck (images)
results <- process_document(
  mode = "images",
  document_type = "internal",
  audience = "Leadership team"
)

# View results
print(results)

# Results are automatically exported to CSV with timestamp
```

## How It Works

The tool follows a simple pipeline:

1. **Extract**: Opens file picker and extracts PDF content
   - Text mode: Extracts text from each page
   - Image mode: Converts each page to PNG images

2. **Build Prompts**: Formats content with document type and audience
   - Automatically chunks large documents
   - Adds project context header

3. **Call API**: Sends to OpenAI API for copyediting review
   - Uses GPT-5 (reasoning model) by default
   - Includes retry logic for rate limits

4. **Format Results**: Returns structured table of suggestions
   - Filters and validates results
   - Adds metadata attributes

5. **Export**: Saves results to CSV automatically
   - Timestamped filename
   - Includes metadata file

## Output Structure

Results are returned as a table with these columns:

| Column | Type | Description |
|--------|------|-------------|
| `page_number` | Integer | Page where issue was found |
| `issue` | Character | Brief description (e.g., "grammar error") |
| `original_text` | Character | Text containing the error |
| `suggested_edit` | Character | Recommended fix |
| `rationale` | Character | Explanation of why edit is needed |
| `severity` | Character | critical / recommended / optional |
| `confidence` | Numeric | Confidence score (0-1) |
| `is_valid` | Logical | TRUE if row has required fields |

## Configuration

### Models and Settings

Edit `config/model_config.R` to change:
- `MODEL_TEXT` - Model for text mode (default: "gpt-5")
- `MODEL_IMAGES` - Model for image mode (default: "gpt-5")
- `CONTEXT_WINDOW_TEXT` - Token limit for text mode
- `CONTEXT_WINDOW_IMAGES` - Token limit for image mode
- `IMAGES_PER_CHUNK` - Images per chunk in image mode
- `MAX_RETRY_ATTEMPTS` - Retry attempts for API failures

### System Prompt

Edit `config/system_prompt.txt` to customize copyediting rules and style guide.

See `config/README.md` for more details.

## When to Use Each Mode

**Text Mode** (default):
- Reports and publications
- Text-heavy documents
- Faster and cheaper

**Image Mode**:
- Slide decks and presentations
- Documents with text in charts/diagrams
- When layout and visuals matter
- More expensive (processes images)

**Note**: If you have DOCX or PPTX files, export them to PDF first (File > Save As > PDF in Microsoft Office).

## Examples

### Basic Usage

```r
# Load main function
source("R/process_document.R")

# Process a report
results <- process_document(
  mode = "text",
  document_type = "external client-facing",
  audience = "Healthcare executives"
)

# View summary
print_summary(results)

# Filter critical issues
critical <- results[results$severity == "critical", ]
```

### Batch Processing

```r
# Process multiple documents
process_batch <- function(document_type, audience) {
  # Opens file picker for each document
  doc1 <- process_document(mode = "text", document_type, audience)
  doc2 <- process_document(mode = "text", document_type, audience)

  # Combine results
  all_results <- rbind(doc1, doc2)
  return(all_results)
}
```

### Custom Export

```r
# Process document
results <- process_document(
  mode = "text",
  document_type = "internal",
  audience = "Staff"
)

# Export with custom filename
export_results(results, output_filename = "my_edits.csv")
```

## API Costs

Approximate costs (as of 2025):
- **Text mode**: $0.05-0.15 per page (varies by length)
- **Image mode**: $0.10-0.30 per page (higher token cost)

Costs depend on:
- Document length and complexity
- Model used (configured in `config/model_config.R`)
- Number of chunks needed

The tool displays estimated cost before sending to API.

## Troubleshooting

### Rate Limiting
The tool includes automatic retry with exponential backoff. If you continue hitting rate limits:
- Wait a few minutes between large documents
- Check your OpenAI account rate limits

### Token Limits
Large documents are automatically chunked to fit within model context windows. Configuration in `config/model_config.R`.

### Empty Results
If no suggestions are returned:
- Check that the PDF contains readable text (not just scanned images)
- Verify your API key is set correctly
- Check the console for error messages

### API Key Not Found
```r
# Set in R session:
Sys.setenv(OPENAI_API_KEY = "sk-your-key-here")

# Or add to .Renviron file (recommended):
usethis::edit_r_environ()
# Add line: OPENAI_API_KEY=sk-your-key-here
```

## Support

For questions or issues, see `CLAUDE.md` for project context and design principles.

## License

MIT License
