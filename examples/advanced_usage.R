# Advanced Usage Example for Bellwether Copyeditor
# =================================================
#
# This script demonstrates advanced features including:
# - Different models and parameters
# - Batch processing multiple documents
# - Custom analysis and reporting
# - Handling large documents with automatic chunking

# Load the package functions
source("R/parse_document.R")
source("R/build_prompt.R")
source("R/call_openai_api.R")
source("R/process_document.R")
source("R/format_results.R")

# ====================
# Basic Usage with Document Context
# ====================

# Process a document with full context
results <- process_document(
  file_path = "document.pdf",
  document_type = "external client-facing",
  audience = "Healthcare executives and C-suite stakeholders",
  model = "gpt-4"
)

# ====================
# Different Models
# ====================

# Use GPT-4 Turbo (faster, cheaper)
results_turbo <- process_document(
  file_path = "document.pdf",
  document_type = "internal",
  audience = "Research team",
  model = "gpt-4-turbo-preview",
  temperature = 0.2  # Lower temperature for more consistency
)

# Use GPT-3.5 Turbo (fastest, cheapest, less accurate)
results_gpt35 <- process_document(
  file_path = "document.pdf",
  document_type = "external field-facing",
  audience = "Healthcare providers",
  model = "gpt-3.5-turbo",
  delay_between_chunks = 0.5  # Faster rate limiting
)

# ====================
# Batch Processing
# ====================

# Process multiple documents
documents <- c(
  "reports/report_2024_q1.pdf",
  "reports/report_2024_q2.pdf",
  "reports/report_2024_q3.pdf"
)

# Process each document
all_results <- list()

for (doc in documents) {
  cat(sprintf("\n\n=== Processing %s ===\n", basename(doc)))

  results <- process_document(
    file_path = doc,
    document_type = "external client-facing",
    audience = "Board members and investors"
  )

  # Store results with document name
  all_results[[basename(doc)]] <- results

  # Export individual results
  output_name <- paste0("results_", tools::file_path_sans_ext(basename(doc)), ".csv")
  export_results(results, output_name)

  # Add a longer delay between documents
  Sys.sleep(5)
}

# Combine all results
combined_results <- do.call(rbind, lapply(names(all_results), function(doc_name) {
  df <- all_results[[doc_name]]
  df$document <- doc_name
  df
}))

# Export combined results
write.csv(combined_results, "all_documents_results.csv", row.names = FALSE)

# ====================
# Custom Analysis
# ====================

# Analyze patterns across documents
library(ggplot2)  # Optional for visualization

# Most common issues by document
issue_summary <- aggregate(
  page_number ~ document + edit_type,
  data = combined_results,
  FUN = length
)
names(issue_summary)[3] <- "count"

# Print summary
print(issue_summary)

# Issues by severity and type
severity_type <- table(combined_results$severity, combined_results$edit_type)
print(severity_type)

# ====================
# Low-Level API Usage
# ====================

# For more control, use the individual functions

# 1. Parse document
parsed_doc <- parse_document("document.pdf", mode = "text")
cat(sprintf("Document has %d pages\n", nrow(parsed_doc)))

# 2. Build user messages (with automatic chunking if needed)
user_message_chunks <- build_prompt(
  parsed_document = parsed_doc,
  document_type = "internal",
  audience = "Data science team",
  context_window = 400000
)

cat(sprintf("Document split into %d chunk(s)\n", nrow(user_message_chunks)))

# 3. Load system prompt
system_prompt_path <- "config/system_prompt_template.txt"
system_prompt <- paste(readLines(system_prompt_path, warn = FALSE), collapse = "\n")

# 4. Process first chunk manually
first_chunk <- user_message_chunks[1, ]

# Construct messages array
messages <- list(
  list(role = "system", content = system_prompt),
  list(role = "user", content = first_chunk$user_message)
)

# 5. Call API
api_result <- call_openai_api(
  messages = messages,
  model = "gpt-4",
  temperature = 0.3
)

# 6. Format results
suggestions_df <- format_results(api_result$suggestions)

print(suggestions_df)

# Check token usage
print(api_result$usage)

# ====================
# Error Handling
# ====================

# Wrap in tryCatch for robust error handling
safe_process <- function(file_path, ...) {
  tryCatch({
    results <- process_document(file_path, ...)
    return(list(success = TRUE, results = results, error = NULL))
  }, error = function(e) {
    return(list(success = FALSE, results = NULL, error = e$message))
  })
}

# Use it
result <- safe_process(
  "document.pdf",
  document_type = "external client-facing",
  audience = "Healthcare providers",
  verbose = FALSE
)

if (result$success) {
  cat("Processing successful!\n")
  print(result$results)
} else {
  cat(sprintf("Error: %s\n", result$error))
}

# ====================
# Generate Report
# ====================

# Create a summary report
generate_summary_report <- function(results, output_file = "summary_report.txt") {

  sink(output_file)

  cat("========================================\n")
  cat("COPYEDITING SUMMARY REPORT\n")
  cat("========================================\n\n")

  cat(sprintf("Generated: %s\n", Sys.time()))
  cat(sprintf("Document: %s\n", attr(results, "document_path")))
  cat(sprintf("Model: %s\n", attr(results, "model")))
  cat(sprintf("Total issues found: %d\n\n", nrow(results)))

  if (nrow(results) > 0) {

    cat("BY SEVERITY:\n")
    print(table(results$severity))
    cat("\n")

    cat("BY TYPE:\n")
    print(table(results$edit_type))
    cat("\n")

    cat("BY PAGE:\n")
    print(table(results$page_number))
    cat("\n")

    cat("TOP 10 CRITICAL ISSUES:\n")
    cat("------------------------\n")
    critical <- results[results$severity == "critical", ]
    if (nrow(critical) > 0) {
      for (i in 1:min(10, nrow(critical))) {
        cat(sprintf("\n%d. Page %d - %s\n",
                    i, critical$page_number[i], critical$edit_type[i]))
        cat(sprintf("   Original: %s\n", critical$original_text[i]))
        cat(sprintf("   Suggested: %s\n", critical$suggested_edit[i]))
        cat(sprintf("   Reason: %s\n", critical$reason[i]))
      }
    } else {
      cat("No critical issues found.\n")
    }
  }

  sink()

  cat(sprintf("Report saved to: %s\n", output_file))
}

# Generate the report
generate_summary_report(results, "copyedit_summary.txt")
