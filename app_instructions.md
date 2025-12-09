# Bellwether's AI Copyeditor

## Overview

An R-based tool that uses OpenAI's LLM models to copyedit PDF documents according to Bellwether style conventions.

-   **Input**: PDF file, choice of text or image mode, type of document, and intended audience
-   **Output**: CSV file with a table of suggested edits with page numbers, issues, and explanations

> **Important Note**: This tool flags errors for human review — it does not automatically fix them. It is on the author(s) to ensure that any errors are corrected.

## Getting Started

1.  **Upload your PDF file**: This is the file to be copyedited, clean of comments and tracked changes. Do NOT include endnotes. You MUST convert or print your file to PDF.
2.  **Describe your document**: In the text box under "Document Type," write a brief description of the document's purpose, in natural language
    -   Examples: "case study for publication," "blog post," "board presentation"
3.  **Describe your audience**: In the text box under "Target Audience," write a brief description of the intended audience
    -   Examples: "funders, ed tech developers, and policymakers," "nonprofit executive leadership," or "K-12 parents and caregivers"
4.  **Choose the appropriate mode**: The copyeditor has text and image mode, and you must specify one.
    -   *Text Mode*: for documents that only have text (e.g., memos, reports, blog posts)
    -   *Image Mode*: for documents that have any visual elements (e.g., reports with charts, slide decks, surveys)

## How It Works

The tool follows a pipeline of scripts:

1.  **Extract**: Opens file picker and extracts PDF content
    -   Text mode: Extracts text from each page
    -   Image mode: Converts each page to PNG images
2.  **Build Prompts**: Formats content for API call, with document type and audience
    -   Automatically chunks large documents
    -   Adds project context header
3.  **Call API**: Sends to chosen AI model through OpenAI API for copyediting review
    -   Uses GPT-5 (reasoning model) by default
    -   Includes retry logic for rate limits, and error handling
4.  **Format Results**: Returns structured table of suggestions
    -   Reformats API response and validates results
    -   Collects metadata attributes if needed
5.  **Export**: Saves results to CSV automatically
    -   Timestamped filename
    -   Includes metadata file

## Output Structure

Results are returned as a table with these columns:

| Column           | Type      | Description                               |
|------------------|-----------|-------------------------------------------|
| `page_number`    | Integer   | Page where issue was found                |
| `issue`          | Character | Brief description (e.g., "grammar error") |
| `original_text`  | Character | Text containing the error                 |
| `suggested_edit` | Character | Recommended fix                           |
| `rationale`      | Character | Explanation of why edit is needed         |
| `severity`       | Character | critical / recommended / optional         |
| `confidence`     | Numeric   | Confidence score (0-1)                    |
| `is_valid`       | Logical   | TRUE if row has required fields           |

## Support

For questions or issues, reach out to Marisa!