# ==============================================================================
# Title:        Document Extracter
# Last Updated: 2025-01-04
# Description:  Functions to extract content from PDF documents for LLM copyediting.
#               Text mode for documents without images (extracts text by page).
#               Image mode for documents with images (e.g., slide decks, embedded charts) (converts pages to images).
# Output:       A tibble, with fields dependent on text or image mode
# ==============================================================================

# Helper Functions ------------------------------------------------------------

#' Extract Text from PDF by Page
#' @param file_path Path to PDF file
#' @return A tibble with columns: page_number (integer) and content (character)
#' @keywords internal
extract_to_text <- function(file_path) {
  # Extract text from PDF by page
  pages_text <- pdf_text(file_path)

  # Return tibble with page numbers and content
  tibble(
    page_number = seq_along(pages_text),
    content = pages_text
  )
}

#' Convert PDF Pages to Images
#' @param file_path Path to PDF file
#' @return A tibble with columns: page_number (integer) and image_path (character).
#'   Images are saved to temporary directory and persist for the R session.
#' @keywords internal
extract_to_images <- function(file_path) {
  # Convert PDF pages to PNG images in temp directory
  # Suppress warning from pdftools internal sprintf call
  image_paths <- suppressWarnings(
    pdf_convert(
      pdf = file_path,
      format = "png",
      dpi = 150,
      filenames = file.path(tempdir(), "page_%d.png"),
      verbose = TRUE
    )
  )

  # Return tibble with page numbers and image paths
  tibble(
    page_number = seq_along(image_paths),
    image_path = image_paths
  )
}


# Main Function ----------------------------------------------------------------

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
