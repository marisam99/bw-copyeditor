# bw-copyeditor

A tool that uses OpenAI's LLM models to copyedit deliverable drafts according to project context and Bellwether style conventions.

## Features

- **Page Preservation**: Maintains page numbers throughout the copyediting process
- **Structured Output**: Returns results as a data frame that can be easily exported to CSV
- **Two Parsing Modes**: Text extraction for publications, image conversion for slide decks
- **PDF Only**: Simplified workflow - export DOCX/PPTX to PDF first
- **Custom Style Guides**: Embed your organization's style guide in the system prompt
- **Project Context**: Add project-specific context to improve relevance of suggestions
- **Flexible Processing**: Process entire documents or specific pages
- **Rich Metadata**: Track edit types, severity levels, and confidence scores
- **Batch Processing**: Process multiple documents efficiently

## Installation

### Prerequisites

Install required R packages:

```r
install.packages(c("httr", "jsonlite", "pdftools", "stringr", "glue", "tibble"))
```

**Note:** This tool only supports PDF files. If you have DOCX or PPTX files, export them to PDF first using File > Save As > PDF in Microsoft Office.

### Setup

1. Clone this repository
2. Set your OpenAI API key as an environment variable:

```r
Sys.setenv(OPENAI_API_KEY = "sk-your-api-key-here")
```

Or add to your `.Renviron` file:
```
OPENAI_API_KEY=sk-your-api-key-here
```

## Quick Start

```r
# Load the package functions
source("R/parse_document.R")
source("R/build_prompt.R")
source("R/call_openai_api.R")
source("R/process_document.R")
source("R/format_results.R")

# Process a text-heavy document (uses gpt-4o automatically)
results <- process_document(
  file_path = "path/to/report.pdf",
  document_type = "external client-facing",
  audience = "Healthcare executives"
)

# View results
print(results)

# Export to CSV
write.csv(results, "copyedit_results.csv", row.names = FALSE)
```

## Architecture

The tool is built with a modular architecture consisting of six main functions:

### 1. `parse_document(file_path, mode = "text")`
Extracts content from PDF documents with two parsing modes.
- **Input**: Path to PDF file
- **Parameters**:
  - `mode = "text"` (default): Extract text by page for publications
  - `mode = "images"`: Convert pages to images for slide decks
- **Output**: Tibble with `page_number` and either `content` (text) or `image_path` (images)
- **Features**:
  - Accurate page boundaries from PDF structure
  - Text mode for standard copyediting
  - Image mode for multimodal LLM review of visual content

### 2. `build_prompt(text_chunk, page_num, project_context, system_prompt)`
Constructs the messages array for OpenAI API requests.
- **Input**: Text to review, page number, project context, system prompt
- **Output**: Formatted messages array
- **Features**:
  - Separates system and user messages
  - Embeds style guide in system prompt
  - Adds project-specific context
  - Helper function to load prompts from files

### 3. `call_openai_api(user_message, system_prompt, model, ...)`
Sends requests to OpenAI API with error handling and retry logic.
- **Input**: User message, system prompt, model name, parameters (API key read from environment)
- **Output**: Parsed JSON response with suggestions
- **Features**:
  - Exponential backoff for rate limiting
  - Configurable retry attempts
  - Token usage tracking
  - Response validation

### 4. `process_document(file_path, project_context, ...)`
Main orchestrator that coordinates the entire pipeline.
- **Input**: Document path, context, configuration options
- **Output**: Structured data frame of copyediting suggestions
- **Features**:
  - Progress reporting
  - Selective page processing
  - Metadata tracking
  - Summary statistics
  - Rate limiting controls

### 5. `format_results(suggestions_list)`
Converts raw API responses into clean, structured data frames.
- **Input**: List of suggestions from API
- **Output**: Validated data frame with standard columns
- **Features**:
  - Type validation and conversion
  - Field standardization
  - Sorting by page and severity
  - Missing data handling

### 6. `export_results(results_df, output_path)`
Convenience function for exporting results with metadata.
- **Input**: Results data frame, output path
- **Output**: CSV files (results + metadata)
- **Features**:
  - Automatic metadata file generation
  - Processing timestamp
  - Model and configuration info

## Output Structure

The tool returns a data frame with the following columns:

| Column | Type | Description |
|--------|------|-------------|
| `page_number` | Integer | Page where issue was found |
| `location` | Character | Brief description of location on page |
| `original_text` | Character | The problematic text |
| `suggested_edit` | Character | Proposed correction |
| `edit_type` | Character | Type: grammar, style, clarity, consistency, spelling |
| `reason` | Character | Explanation of why edit is needed |
| `severity` | Character | Level: critical, recommended, optional |
| `confidence` | Numeric | Confidence score (0-1) |

## Usage Examples

### Basic Usage

```r
# Process entire document
results <- process_document(
  file_path = "report.pdf",
  project_context = "Q4 2024 Healthcare Report"
)

# Filter critical issues only
critical <- filter_results(results, severity = "critical")

# Filter by type
grammar_issues <- filter_results(results, edit_type = "grammar")
```

### Custom System Prompt

```r
# Load custom prompt with embedded style guide
system_prompt <- load_system_prompt("config/system_prompt.txt")

results <- process_document(
  file_path = "document.pdf",
  project_context = "Annual report",
  system_prompt = system_prompt
)
```

### Process Specific Pages

```r
# Process only pages 1-5
results <- process_document(
  file_path = "document.pdf",
  project_context = "Executive summary",
  process_pages = c(1, 2, 3, 4, 5)
)
```

### Batch Processing

```r
documents <- c("report1.pdf", "report2.pdf", "report3.pdf")

all_results <- lapply(documents, function(doc) {
  process_document(
    file_path = doc,
    document_type = "external client-facing",
    audience = "Quarterly stakeholders"
  )
})

# Combine results
combined <- do.call(rbind, all_results)
write.csv(combined, "all_results.csv", row.names = FALSE)
```

## Configuration

### System Prompt Template

Create a file `config/system_prompt.txt` with your style guide:

```
You are a professional copyeditor for [Organization].
Review documents according to the following style guide:

[YOUR STYLE GUIDE HERE]

Return findings as a JSON array with this structure:
{
  "page_number": <integer>,
  "location": "<brief description>",
  "original_text": "<problematic text>",
  "suggested_edit": "<proposed correction>",
  "edit_type": "<grammar|style|clarity|consistency|spelling>",
  "reason": "<explanation>",
  "severity": "<critical|recommended|optional>",
  "confidence": <0-1>
}

Return ONLY the JSON array.
```

### Project Context Template

Create `config/project_context_template.txt`:

```
Project: [PROJECT NAME]
Client: [CLIENT NAME]
Document Type: [REPORT/MEMO/ETC]
Audience: [TARGET AUDIENCE]
Key Terms: [DOMAIN-SPECIFIC TERMS]
```

## Examples

See the `examples/` directory for detailed usage examples:
- `basic_usage.R` - Simple walkthrough of core features
- `advanced_usage.R` - Batch processing, custom analysis, error handling

## API Costs

Approximate costs per page (as of 2024):
- GPT-4: $0.03 - $0.06 per page
- GPT-4 Turbo: $0.01 - $0.03 per page
- GPT-3.5 Turbo: $0.002 - $0.005 per page

Actual costs depend on:
- Text length per page
- System prompt length
- Model used
- Temperature settings

## Troubleshooting

### Rate Limiting
If you hit rate limits, adjust the `delay_between_pages` parameter:

```r
results <- process_document(
  file_path = "document.pdf",
  delay_between_pages = 3  # Wait 3 seconds between pages
)
```

### Token Limits
For documents with very long pages, the API may return errors. Solutions:
1. Split large pages into smaller chunks
2. Use models with larger context windows (e.g., gpt-4-32k)
3. Shorten your system prompt

### Empty Results
If no suggestions are returned:
1. Check that your system prompt specifies JSON output format
2. Verify the document actually contains text (not just images)
3. Try a lower temperature value for more deterministic output

## Contributing

Contributions welcome! Please ensure:
- Functions are well-documented with roxygen2 comments
- Examples are included in documentation
- Code follows existing style conventions

## License

MIT License

## Support

For issues or questions, please open an issue on GitHub.
