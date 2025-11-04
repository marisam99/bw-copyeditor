# Test Fixtures

This directory contains sample files used for testing.

## Files needed:

- `test_document.pdf` - A simple PDF document for testing both text and image parsing modes

## How to create test file:

1. Create a simple document with 1-2 pages of text in Word or similar
2. Export to PDF as `test_document.pdf`
3. Place the file in this directory

Tests will automatically skip if this file doesn't exist.

**Note:** The same PDF file is used to test both parsing modes:
- Text mode: Extracts text content
- Images mode: Converts pages to PNG images
