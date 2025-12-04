# BW Copyeditor - Project Context

## Project Overview

An R package for automated copyediting using Large Language Models (LLMs). This tool is designed to assist non-technical colleagues by flagging potential errors in documents without automatically applying fixes.

### Purpose

-   **Goal:** Flag copyediting errors for human review
-   **Not a goal:** Automatically fix/apply corrections
-   **Target users:** Non-technical colleagues who need copyediting assistance

### Input/Output

**Input:**
- PDF document via file picker (PDF only - export Google Docs/Slides/Sheets to PDF first)
- Document type (e.g., "external client-facing", "internal")
- Audience description (e.g., "Healthcare executives")

**Output:**
- A data frame (table) containing suggested edits with the following columns:
  - `page_number` - Which page the error appears on
  - `issue` - Brief description of the issue (e.g., "grammar error")
  - `original_text` - The text containing the error
  - `suggested_edit` - Recommended fix
  - `rationale` - Explanation of why this edit is needed
  - `severity` - One of: "critical", "recommended", "optional"
  - `confidence` - Numeric value between 0 and 1 indicating confidence
  - `is_valid` - TRUE if row has required fields

------------------------------------------------------------------------

## File Format Handling

### PDF Files (Only Supported Format)

The tool supports two parsing modes for PDF documents:

#### Text Mode (Default)

-   **Use case:** Publications, reports, text-heavy documents
-   **Function:** `extract_to_text()` via `extract_document(mode = "text")`
-   **Process:** Extracts text content from each PDF page
-   **Output:** Tibble with `page_number` and `content` (text)
-   **LLM usage:** Text is sent directly to LLM for copyediting

#### Image Mode

-   **Use case:** Slide decks, presentations, visual-heavy documents
-   **Function:** `extract_to_images()` via `extract_document(mode = "images")`
-   **Process:** Converts each PDF page to PNG images
-   **Output:** Tibble with `page_number` and `image_path`
-   **LLM usage:** Images sent to multimodal LLM (OpenAI GPT with vision) for review
-   **Benefit:** Captures text within charts, diagrams, and other visual elements

**Note:** Export Google Docs, Slides, or Sheets files to PDF first using File \> Download \> PDF Document (.pdf).

------------------------------------------------------------------------

## Technical Requirements

### Core Dependencies

-   **`pdftools`** - For extracting text and converting PDFs to images
-   **`tidyverse`** - Use tidyverse functions wherever applicable (dplyr, tidyr, purrr, etc.)
-   **`ellmer`** - For making LLM API calls
-   **`glue`** - For string formatting
-   **`tibble`** - For data frame structures

### Coding Standards

-   Use tidyverse-style functions and pipelines where appropriate
-   Prefer `%>%` or `|>` pipes for data transformations
-   Use dplyr verbs for data manipulation
-   Keep functions simple and well-documented
-   **Function organization:** Always place helper functions before main exported functions within a script. This makes the code easier to read and maintain:
    1. Configuration constants (if any)
    2. Helper functions (marked with `@keywords internal`)
    3. Main exported functions (marked with `@export`)

### Dependency Management

-   **Centralized dependencies:** All `library()` calls are in `config/dependencies.R`
-   **Automatic checking:** Dependencies are automatically checked on startup with user-friendly prompts
-   **No package:: notation:** Use plain function names (e.g., `tibble()` not `tibble::tibble()`)
-   **Single source of truth:** `config/dependencies.R` is the only place to manage package dependencies
-   All required packages:
    -   `pdftools` - PDF extraction
    -   `tibble`, `dplyr`, `purrr` - Data manipulation
    -   `glue` - String formatting
    -   `ellmer` - LLM API calls
    -   `jsonlite` - JSON parsing
    -   `rtiktoken` - Token counting
    -   `tools` - File utilities

### User-Facing Messaging

-   **Selective emoji usage:** Only use emojis for specific categories:
    -   ⏳ Progress indicators ("Extracting...", "Sending...", "Retrying...")
    -   ✅ Success confirmations ("Processing complete!", "Response received", "Exported to...")
    -   ⚠️ Warnings (failed chunks, missing fields, errors)
    -   🎉 Celebration ("No issues found!")
-   **No emojis for:** Headers, info messages (Mode, Document type), token counts, cost estimates, chunk details
-   **Logical spacing:** Use blank lines to separate logical sections of output
-   **User-friendly:** Write for non-technical colleagues - clear, concise, no jargon

------------------------------------------------------------------------

## Design Principles

### 1. Intuitive for Non-Coders

-   Use clear, descriptive variable names
-   Avoid technical jargon in function names and outputs
-   Examples:
    -   ✅ `pages` instead of `content`
    -   ✅ `pg_number` instead of `metadata`
    -   ✅ `total_pages` instead of `n` or `length`

### 2. Simple Data Structures

-   Avoid deeply nested lists or complex objects
-   Return data frames/tibbles for tabular results
-   Keep output structures flat and easy to inspect

### 3. Clear Documentation

-   Every exported function should have:
    -   Clear description of what it does
    -   Examples showing typical usage
    -   Parameter descriptions
    -   Return value documentation
-   Write documentation for users who may not know R well

### 4. Error Flagging Only

-   The tool identifies errors but does not modify documents
-   All corrections are suggestions that require human review
-   Output should be easy to review and act upon

------------------------------------------------------------------------

## Architecture Notes

### Main Entry Point

The `process_document()` function is the main orchestrator that coordinates the entire pipeline:
- Opens file picker for PDF selection
- Extracts content using `extract_document()`
- Builds prompts with automatic chunking
- Calls OpenAI API via `ellmer`
- Formats and exports results

### Document Extraction

The `extract_document()` function extracts content from PDFs. It accepts a `mode` parameter:
- **Text mode** (default): Returns tibble with `page_number` and `content` (text)
- **Images mode**: Returns tibble with `page_number` and `image_path`

This tibble structure makes it easy to:
- Iterate over pages using standard dplyr operations
- Format content for LLM prompts (e.g., "Page 1: [text]")
- Track which page errors appear on
- Join with error results by page_number

### Prompt Building

Two separate functions handle prompt formatting:
- `build_prompt_text()` - For text mode (with automatic token-based chunking)
- `build_prompt_images()` - For image mode (with image-count-based chunking)

Both functions:
- Add document type and audience context
- Automatically chunk large documents
- Return tibbles with chunk metadata

### LLM Integration

Use the `ellmer` package for all LLM API interactions. The general workflow:
1. Extract document using `extract_document()` (opens file picker)
2. Build prompts with automatic chunking using `build_prompt_text()` or `build_prompt_images()`
3. Send to OpenAI API with appropriate function:
   - Text mode: `call_openai_api_text()` (standard text-only LLM)
   - Image mode: `call_openai_api_images()` (multimodal LLM with vision)
4. Format response using `format_results()` into structured error table
5. Export to CSV using `export_results()` with timestamp
6. Return data frame of suggested edits

------------------------------------------------------------------------

## Development Guidelines

### When Adding New Features

-   Consider whether non-technical users will understand it
-   Keep the input→output flow simple
-   Document with clear examples
-   Test with actual use cases from colleagues

### When Refactoring

-   Maintain backward compatibility where possible
-   Ensure output format remains consistent
-   Update documentation to reflect changes
-   Prioritize code clarity over cleverness

------------------------------------------------------------------------

## Questions or Clarifications?

If you're working on this project and have questions about design decisions or architecture, refer to this document first. It captures the key principles and technical requirements that guide development.