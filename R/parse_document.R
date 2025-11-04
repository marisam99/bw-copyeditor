# ==============================================================================
# Title:        Document Parser
# Last Updated: 2025-01-04
# Description:  Functions to parse PDF documents for LLM copyediting.
#               Text mode for documents without images (extracts text by page).
#               Image mode for documents with images (e.g., slide decks, embedded charts) (converts pages to images).
# ==============================================================================

# Helper Functions ------------------------------------------------------------

#' Extract Text from PDF by Page
#' @param file_path Path to PDF file
#' @return A tibble with columns: page_number (integer) and content (character)
#' @keywords internal
parse_to_text <- function(file_path) {
  # Extract text from PDF by page
  pages_text <- pdftools::pdf_text(file_path)

  # Return tibble with page numbers and content
  tibble::tibble(
    page_number = seq_along(pages_text),
    content = pages_text
  )
}


#' Convert PDF Pages to Images
#' @param file_path Path to PDF file
#' @return A tibble with columns: page_number (integer) and image_path (character).
#'   Images are saved to temporary directory and persist for the R session.
#' @keywords internal
parse_to_images <- function(file_path) {
  # Convert PDF pages to PNG images in temp directory
  image_paths <- pdftools::pdf_convert(
    pdf = file_path,
    format = "png",
    dpi = 150,
    filenames = file.path(tempdir(), "page_%d.png"),
    verbose = TRUE
  )

  # Return tibble with page numbers and image paths
  tibble::tibble(
    page_number = seq_along(image_paths),
    image_path = image_paths
  )
}


# Main Function ----------------------------------------------------------------

#' Parse PDF Document
#'
#' Opens a file picker to select a PDF document, then extracts content with two modes:
#' - Text mode (default): For documents without images - extracts text by page
#' - Images mode: For documents with images (e.g., slide decks, embedded charts) - converts pages to images for multimodal LLM
#'
#' @param mode Character. Parsing mode: "text" (default) or "images".
#'   Use "text" for text-heavy documents like reports and publications.
#'   Use "images" for visual-heavy documents like slide decks.
#' @return A tibble with columns:
#'   - Text mode: page_number (int), content (chr)
#'   - Images mode: page_number (int), image_path (chr)
#'
#' @examples
#' \dontrun{
#'   # Text mode for publications (default)
#'   doc <- parse_document()
#'   doc$content[1]      # First page text
#'
#'   # Images mode for slide decks
#'   slides <- parse_document(mode = "images")
#'   slides$image_path[1]   # First page image path
#' }
#'
#' @export
parse_document <- function(mode = c("text", "images")) {

  # Match mode argument
  mode <- match.arg(mode)

  # Open file picker
  file_path <- file.choose()

  # Check if file exists
  if (!file.exists(file_path)) {
    stop(glue::glue("File not found: {file_path}"))
  }

  # Get file extension
  file_ext <- tolower(tools::file_ext(file_path))

  # Only accept PDF files
  if (file_ext != "pdf") {
    stop(glue::glue(
      "Only PDF files are supported. Found: {file_ext}\n",
      "If you have a DOCX or PPTX file, please export to PDF first:\n",
      "File > Save As > PDF"
    ))
  }

  # Parse based on mode
  if (mode == "text") {
    return(parse_to_text(file_path))
  } else {
    return(parse_to_images(file_path))
  }
}
