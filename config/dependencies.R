# ==============================================================================
# Package Dependencies for BW Copyeditor
# ==============================================================================
# This file loads all required packages for the copyediting tool.
# Install any missing packages before running:
#   install.packages(c("pdftools", "tibble", "dplyr", "purrr", "glue", "ellmer", "jsonlite", "rtiktoken", "tools"))

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
