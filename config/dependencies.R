# ==============================================================================
# Package Dependencies for BW Copyeditor
# ==============================================================================
# This file loads all required packages for the copyediting tool.
# Missing packages will be automatically detected and can be installed when prompted.

# Check and Install Missing Packages ------------------------------------------

#' Check Dependencies and Install if Missing
#'
#' Checks if all required packages are installed. If any are missing,
#' prompts the user to install them automatically.
#'
#' @param auto_install If TRUE, installs without prompting. Default FALSE.
#' @keywords internal
check_dependencies <- function(auto_install = FALSE) {
  required_packages <- c(
    "pdftools", "tibble", "dplyr", "purrr",
    "glue", "ellmer", "jsonlite", "rtiktoken",
    "shiny", "DT", "shinycssloaders", "bslib", "here", "markdown"
  )

  # Check which packages are missing
  missing <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

  if (length(missing) > 0) {
    message("\n⚠️  Missing required packages: ", paste(missing, collapse = ", "))

    if (auto_install) {
      message("Installing missing packages...")
      install.packages(missing)
      message("✅ Installation complete!\n")
    } else {
      # Interactive prompt
      response <- readline(prompt = "Install missing packages now? (y/n): ")
      if (tolower(trimws(response)) == "y") {
        message("\nInstalling packages...")
        install.packages(missing)
        message("✅ Installation complete!\n")
      } else {
        stop(
          "Required packages not installed.\n",
          "Install manually with: install.packages(c('",
          paste(missing, collapse = "', '"), "'))"
        )
      }
    }
  }
}

# Run dependency check (only in interactive sessions)
if (interactive()) {
  check_dependencies()
}

# Load Packages ---------------------------------------------------------------

# PDF Processing
library(pdftools)      # Extract text and convert PDFs to images

# Data Manipulation (tidyverse)
library(tibble)        # Modern data frames
library(dplyr)         # Data manipulation (filter, mutate, select, bind_rows)
library(purrr)         # Functional programming (map, pluck, compact)

# String Formatting
library(glue)          # String interpolation

# LLM API
library(ellmer)        # OpenAI API wrapper (chat_openai, content_image_file)

# JSON Parsing
library(jsonlite)      # Parse API responses

# Token Counting
library(rtiktoken)     # OpenAI tokenizer

# Base R Utilities
library(tools)         # File path utilities (file_ext, file_path_sans_ext)

# Shiny Web Application
library(shiny)         # Web application framework
library(DT)            # Interactive tables
library(shinycssloaders) # Loading spinners
library(bslib)         # Modern UI theming
library(markdown)      # Markdown rendering

# Path Management
library(here)          # Project-relative paths
