# BW Copyeditor Shiny App

Interactive web interface for the BW Copyeditor package.

## Running Locally

### Option 1: From R Console (Recommended)

```r
# If package is installed
library(bwcopyeditor)
run_copyeditor_app()
```

### Option 2: Direct from Directory

```r
# From RStudio
# Open inst/shiny-app/app.R and click "Run App"

# From R console
shiny::runApp("inst/shiny-app")
```

## Usage

1. **Upload PDF**: Click "Select PDF File" and choose your document
2. **Document Type**: Enter description (e.g., "External client-facing report")
3. **Target Audience**: Describe audience (e.g., "Healthcare executives")
4. **Processing Mode**:
   - Text Mode: For reports, publications (text-heavy documents)
   - Image Mode: For slide decks, presentations (visual-heavy documents)
5. **Process**: Click "Process Document" button
6. **Review Results**: View suggestions in the interactive table
7. **Download**: Export results as CSV

## Features

- Drag-and-drop or click to upload PDFs
- Real-time progress indicators
- Interactive, sortable, filterable results table
- Color-coded severity levels (critical/recommended/optional)
- One-click CSV export with timestamps
- Modern, responsive design

## Requirements

Ensure these packages are installed:
```r
install.packages(c("shiny", "DT", "shinycssloaders", "bslib"))
```

## API Key

The app uses the OpenAI API. Ensure your API key is set:
```r
Sys.setenv(OPENAI_API_KEY = "your-key-here")
```

For deployment to shinyapps.io, set the environment variable in the app settings on the shinyapps.io dashboard.
