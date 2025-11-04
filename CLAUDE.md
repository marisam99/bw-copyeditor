# BW Copyeditor - Project Context

## Project Overview

An R package for automated copyediting using Large Language Models (LLMs). This tool is designed to assist non-technical colleagues by flagging potential errors in documents without automatically applying fixes.

### Purpose

-   **Goal:** Flag copyediting errors for human review
-   **Not a goal:** Automatically fix/apply corrections
-   **Target users:** Non-technical colleagues who need copyediting assistance

### Input/Output

**Input:** - File path to a PDF document (PDF only - export DOCX/PPTX to PDF first)

**Output:** - A data frame (table) containing suggested edits with the following columns: - `page_number` - Which page the error appears on - `original_text` - The text containing the error - `suggested_correction` - Recommended fix - `error_type` - Type/reason for the suggested edit (e.g., "grammar", "spelling", "punctuation", "style")

------------------------------------------------------------------------

## File Format Handling

### PDF Files (Only Supported Format)

The tool supports two parsing modes for PDF documents:

#### Text Mode (Default)

-   **Use case:** Publications, reports, text-heavy documents
-   **Function:** `parse_to_text()` via `parse_document(mode = "text")`
-   **Process:** Extracts text content from each PDF page
-   **Output:** Tibble with `page_number` and `content` (text)
-   **LLM usage:** Text is sent directly to LLM for copyediting

#### Image Mode

-   **Use case:** Slide decks, presentations, visual-heavy documents
-   **Function:** `parse_to_images()` via `parse_document(mode = "images")`
-   **Process:** Converts each PDF page to PNG images
-   **Output:** Tibble with `page_number` and `image_path`
-   **LLM usage:** Images sent to multimodal LLM (e.g., Claude with vision) for review
-   **Benefit:** Captures text within charts, diagrams, and other visual elements

**Note:** If you have DOCX or PPTX files, export them to PDF first using File \> Save As \> PDF in Microsoft Office.

------------------------------------------------------------------------

## Technical Requirements

### Core Dependencies

-   **`pdftools`** - For extracting text and converting PDFs to images
-   **`tidyverse`** - Use tidyverse functions wherever applicable (dplyr, tidyr, purrr, etc.)
-   **`ellmr`** - For making LLM API calls
-   **`glue`** - For string formatting
-   **`tibble`** - For data frame structures

### Coding Standards

-   Use tidyverse-style functions and pipelines where appropriate
-   Prefer `%>%` or `|>` pipes for data transformations
-   Use dplyr verbs for data manipulation
-   Keep functions simple and well-documented

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

### Document Parsing

The `parse_document()` function serves as the main entry point for document processing. It accepts a `mode` parameter: - **Text mode** (default): Returns tibble with `page_number` and `content` (text) - **Images mode**: Returns tibble with `page_number` and `image_path`

This tibble structure makes it easy to: - Iterate over pages using standard dplyr operations - Format content for LLM prompts (e.g., "Page 1: \[text\]") - Track which page errors appear on - Join with error results by page_number

### LLM Integration

Use the `ellmr` package for all LLM API interactions. The general workflow: 1. Parse document to extract text/images by page using `parse_document()` 2. Format each page for LLM review 3. Send to LLM with appropriate prompt: - Text mode: Standard text-only LLM - Image mode: Multimodal LLM (e.g., Claude with vision) 4. Parse LLM response into structured error table 5. Return data frame of suggested edits

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