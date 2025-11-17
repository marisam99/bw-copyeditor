# BW Copyeditor Shiny App

Interactive web interface for the BW Copyeditor package.

## Running Locally

### Quick Start (Recommended)

From the R console in Positron or RStudio:

```r
# Run directly from the project directory
shiny::runApp("inst/shiny-app")
```

### Alternative Methods

**Using the helper function:**
```r
# Source the launcher function
source("R/run_app.R")

# Launch app
run_copyeditor_app()
```

**If package is installed:**
```r
library(bwcopyeditor)
run_copyeditor_app()
```

**From Positron/RStudio IDE:**
- Open `inst/shiny-app/app.R`
- Click "Run App" button (RStudio) or use Command Palette (Positron)
- In Positron: Cmd/Ctrl+Shift+P → "Shiny: Run Shiny Application"

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

## Setup

### 1. Install Required Packages

```r
# Check which packages you need
required <- c("shiny", "DT", "shinycssloaders", "bslib", "here", "markdown")
missing <- required[!sapply(required, requireNamespace, quietly = TRUE)]

if (length(missing) > 0) {
  install.packages(missing)
} else {
  message("✅ All packages already installed!")
}
```

### 2. Set OpenAI API Key

The app uses the OpenAI API. Set your API key:

**Temporary (current R session only):**
```r
Sys.setenv(OPENAI_API_KEY = "sk-your-key-here")

# Verify it's set
Sys.getenv("OPENAI_API_KEY")
```

**Permanent (recommended):**
```r
# Open .Renviron file
file.edit("~/.Renviron")

# Add this line to the file:
# OPENAI_API_KEY=sk-your-key-here

# Save, close, and restart R
```

### 3. Navigate to Project Directory

```r
# Check you're in the right place
getwd()  # Should show .../bw-copyeditor

# If not, set working directory
setwd("/path/to/bw-copyeditor")
```

## Troubleshooting

### App Won't Start
```r
# Check all packages are installed
required <- c("shiny", "DT", "shinycssloaders", "bslib", "here", "markdown")
sapply(required, requireNamespace, quietly = TRUE)  # All should be TRUE

# Verify working directory
getwd()  # Should be in bw-copyeditor folder

# Try with error browser
options(shiny.error = browser)
shiny::runApp("inst/shiny-app")
```

### API Errors
```r
# Verify API key is set
Sys.getenv("OPENAI_API_KEY")  # Should show your key (not empty)

# If empty, set it
Sys.setenv(OPENAI_API_KEY = "sk-your-key-here")
```

### File Upload Issues
- Start with a small PDF (< 10 pages)
- Watch the R console in Positron for error messages
- Ensure PDF is not corrupted or password-protected

### Stopping the App
- In Positron/RStudio R console: Press **Ctrl+C** (Cmd+C on Mac)
- Or close browser and interrupt R process

## Deployment

For deployment to shinyapps.io, set the environment variable in the app settings on the shinyapps.io dashboard (not in your code).
