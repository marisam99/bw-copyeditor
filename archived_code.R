# ==============================================================================
# Title:        Archived Code
# Description:  Functions that I wrote but didn't end up using
# ==============================================================================

#' Extract PDF Document
#'
#' Opens a file picker and extracts content from a PDF.
#'
#' @param mode Extraction mode: "text" (default) or "image".
#'   Text mode: For reports and publications.
#'   Images mode: For slide decks with visuals.
#' @return A table with page numbers and either text content or image file paths.
#'
#' @examples
#' \dontrun{
#'   # Extract text from a report
#'   doc <- extract_document()
#'
#'   # Extract images from a slide deck
#'   slides <- extract_document(mode = "images")
#' }
#'
#' @export
extract_document <- function(mode = c("text", "images")) {

  # Match mode argument
  mode <- match.arg(mode)

  # Open file picker
  file_path <- file.choose()

  # Check if file exists
  if (!file.exists(file_path)) {
    stop(glue("File not found: {file_path}. If your PDF is in a Sharepoint folder, wait for it to stop syncing."))
  }

  # Get file extension; validate that it's PDF
  file_ext <- tolower(file_ext(file_path))
  if (file_ext != "pdf") {
    stop(glue(
      "Only PDF files are supported. Found: {file_ext}\n",
      "If you have a DOCX or PPTX file, please export to PDF first:\n",
      "File > Save As > PDF\n",
      "For more information, see the README.md."
    ))
  }

  # Start extraction
  message("⏳ Extracting document content...\n")

  # Extract content based on mode
  result <- if (mode == "text") {
    extract_to_text(file_path)
  } else {
    extract_to_images(file_path)
  }

  # Store file path in attributes
  attr(result, "file_path") <- file_path

  return(result)
}

#' Export Results to CSV
#'
#' Exports results to CSV in the same folder as source document.
#'
#' @param final_df Results from process_document().
#' @param output_filename Output file name (default: "copyedit_results.csv").
#' @param include_metadata Include metadata file (default: TRUE).
#' @return Invisible NULL.
#'
#' @examples
#' \dontrun{
#'   results <- process_document()
#'   export_results(results)
#'   export_results(results, "my_results.csv")
#' }
#'
#' @export
export_results <- function(final_df, output_filename = "copyedit_results.csv", include_metadata = TRUE) {

  # Get source file directory from metadata
  file_path <- attr(results_df, "file_path")

  if (!is.null(file_path) && file.exists(file_path)) {
    output_dir <- dirname(file_path)
    output_path <- file.path(output_dir, output_filename)
  } else {
    # Fallback to current directory if file_path not available
    output_path <- output_filename
    warning("⚠️ Source file path not found in metadata. Saving to current directory.")
  }

  # Export main results
  write.csv(results_df, output_path, row.names = FALSE)
  cat(sprintf("✅ Results exported to: %s\n", output_path))

  # Export metadata if requested
  if (include_metadata && !is.null(attr(results_df, "mode"))) {

    # Create metadata data frame
    doc_mode <- attr(results_df, "mode")
    doc_type <- attr(results_df, "document_type")
    aud <- attr(results_df, "audience")
    chunks <- attr(results_df, "num_chunks")

    metadata <- data.frame(
      mode = if (is.null(doc_mode)) NA else doc_mode,
      document_type = if (is.null(doc_type)) NA else doc_type,
      audience = if (is.null(aud)) NA else aud,
      pages_processed = paste(attr(results_df, "pages_processed"), collapse = ", "),
      num_chunks = if (is.null(chunks)) 1 else chunks,
      model = attr(results_df, "model"),
      total_suggestions = nrow(results_df),
      processed_at = as.character(attr(results_df, "processed_at")),
      stringsAsFactors = FALSE
    )

    # Write metadata
    metadata_path <- sub("\\.csv$", "_metadata.csv", output_path)
    write.csv(metadata, metadata_path, row.names = FALSE)
    cat(sprintf("✅ Metadata exported to: %s\n", metadata_path))
  }

  return(invisible(NULL))
}
