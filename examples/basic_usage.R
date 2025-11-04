# Basic Usage Example for Bellwether Copyeditor
# =============================================
#
# This script demonstrates the basic usage of the bw-copyeditor tool
# to copyedit a document using OpenAI's GPT models.

# Load the package functions
source("R/parse_document.R")
source("R/build_prompt.R")
source("R/call_openai_api.R")
source("R/process_document.R")
source("R/format_results.R")

# ====================
# Setup
# ====================

# Set your OpenAI API key
# Option 1: Set as environment variable (recommended)
Sys.setenv(OPENAI_API_KEY = "sk-your-api-key-here")

# Option 2: Pass directly to function (less secure)
# api_key <- "sk-your-api-key-here"

# ====================
# Basic Example
# ====================

# Process a document with minimal configuration
results <- process_document(
  file_path = "path/to/your/document.pdf",
  project_context = "Annual report for Client X",
  model = "gpt-4"
)

# View results
print(results)

# View first few suggestions
head(results)

# ====================
# Export Results
# ====================

# Export to CSV
export_results(results, "copyedit_results.csv")

# Or use base R
write.csv(results, "copyedit_results.csv", row.names = FALSE)

# ====================
# Filter Results
# ====================

# Get only critical issues
critical_issues <- filter_results(results, severity = "critical")
print(critical_issues)

# Get grammar and spelling issues
language_issues <- filter_results(
  results,
  edit_type = c("grammar", "spelling")
)
print(language_issues)

# Get issues from specific pages with high confidence
page_1_5_high_conf <- filter_results(
  results,
  pages = 1:5,
  min_confidence = 0.8
)
print(page_1_5_high_conf)

# ====================
# Process Specific Pages
# ====================

# Process only pages 1-3
results_partial <- process_document(
  file_path = "path/to/your/document.pdf",
  project_context = "Annual report",
  process_pages = c(1, 2, 3)
)

# ====================
# Summary Statistics
# ====================

# Count by severity
table(results$severity)

# Count by type
table(results$edit_type)

# Count by page
table(results$page_number)

# Average confidence
mean(results$confidence)

# Most common issues
head(sort(table(results$edit_type), decreasing = TRUE))
