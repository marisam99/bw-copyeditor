# bw-copyeditor

## Overview

An R tool that uses OpenAI's LLM models to identify copyedits in PDF documents according to Bellwether style conventions.

-   **Input**: PDF file (reports or slide decks), choice of text or image mode, type of document, and intended audience
-   **Output**: .csv file with a table of suggested edits with page numbers, issues, and explanations

**Important Note**: This tool flags errors for human review — it does not automatically fix them. It is on the author(s) to ensure that any errors are corrected.

### Need to Know:

All of the below are **REQUIRED** inputs:

-   **PDF file**: the file to be copyedited, clean of comments/tracked changes. Do NOT include endnotes. You MUST convert your file to PDF:

    -   *In Word:* First clean the document of comments, tracked changes, etc. If you need to leave certain comments in, go to the Review tab and change the Markup setting from "All Markup" to "No Markup." Then go to File \> Print and ensure that the printer selected is "Microsoft Print to PDF." Select the pages you want to print (again, do NOT include endnotes!), and save the file as a .pdf.

    -   *In Powerpoint:* First clean up comments, then go to File \> Save a Copy and in the file type dropdown, choose .pdf. Then save the file in your chosen folder.

    -   If there are other file types you need guidance for, let Marisa know!

-   **Mode**: the copyeditor has text and image mode, and you must specify one.

    -   *Text Mode*: for documents that only have text (e.g., memos, reports, blog posts)

    -   *Image Mode*: for documents that have any visual elements (e.g., reports with charts, slide decks, surveys)

-   **Document Type**: a brief description of the document's purpose, in natural language

    -   Examples: "case study for publication," "blog post," "board presentation"

-   **Audience**: a brief description of the intended audience

    -   Examples: "funders, ed tech developers, and policymakers," "nonprofit executive leadership," "K-12 parents and caregivers"

## Quick Start

### Set-Up

1.  Install Package Prerequisites

``` r
install.packages(c("pdftools", "tidyverse", "ellmer", "glue", "rtiktoken", "jsonlite", "base64enc"))
```

2.  Obtain a copyediting-specific API key and set it in your environment.

``` r
# In your .Renviron file:
OPENAI_API_KEY=sk-your-api-key-here
```

Or in R:

``` r
Sys.setenv(OPENAI_API_KEY = "sk-your-api-key-here")
```

3.  Make sure you know what your inputs are (see the "NEED TO KNOW" section)

4.  Run the copyeditor, specifying the mode, document_type, and audience.

``` r
# Load the main tool
source("R/bw_copyeditor.R")

# Call the function; make sure all three parameters have some input:
copyedit_document(mode = "TKTK", "document_type", "audience")

# Results are automatically exported to CSV with timestamp in the same folder as the file you uploaded.
```

## How It Works

### Architecture

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

### Output Structure

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

## Configuration

-   All AI model-related settings can be found in `config/model_config.R`; see `config/README.md` for more details.
-   The system prompt (instructions for how the AI model should behave) can be found in `config/system_prompt.txt`. DO NOT EDIT THIS; see `config/README.md` for more details.

## Support

For questions or issues, reach out to Marisa!