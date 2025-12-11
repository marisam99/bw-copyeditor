# ==============================================================================
# Title:        Document Extracter
# Description:  Functions to extract content from PDF documents for LLM copyediting.
#               Text mode for documents without images (extracts text by page).
#               Image mode for documents with images (e.g., slide decks, embedded charts) (converts pages to images).
# Output:       A tibble, with fields dependent on text or image mode
# ==============================================================================

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

#' Create Session-Scoped Image Directory
#' @return Character path to created directory
#' @keywords internal
create_image_directory <- function() {
  # Generate unique session ID
  session_id <- paste0(
    format(Sys.time(), "%Y%m%d_%H%M%S"),
    "_",
    paste(sample(c(letters, 0:9), 6), collapse = "")
  )

  # Create in working directory (not tempdir)
  img_dir <- file.path(getwd(), "session_images", session_id)

  if (!dir.exists(img_dir)) {
    dir.create(img_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Validate creation
  if (!dir.exists(img_dir)) {
    stop(sprintf("Failed to create image directory: %s", img_dir))
  }

  return(img_dir)
}

#' Clean Up Session Image Directory
#' @param img_dir Path to image directory
#' @keywords internal
cleanup_image_directory <- function(img_dir) {
  if (is.null(img_dir) || !dir.exists(img_dir)) {
    return(invisible(NULL))
  }

  tryCatch({
    unlink(img_dir, recursive = TRUE, force = TRUE)
    message(sprintf("✅ Cleaned up: %s", basename(img_dir)))
  }, error = function(e) {
    warning(sprintf("⚠️ Cleanup failed: %s", img_dir))
  })

  invisible(NULL)
}

#' Convert PDF Pages to Images
#' @param file_path Path to PDF file
#' @return A tibble with columns: page_number, image_path, output_dir
#' @keywords internal
extract_to_images <- function(file_path) {
  # Create session-specific directory in working directory
  output_dir <- create_image_directory()

  # Convert PDF pages to PNG images
  # Suppress warning from pdftools internal sprintf call
  image_paths <- suppressWarnings(
    pdf_convert(
      pdf = file_path,
      format = "png",
      dpi = 150,
      filenames = file.path(output_dir, "page_%d.png"),
      verbose = FALSE
    )
  )

  # Return tibble with directory info for cleanup
  tibble(
    page_number = seq_along(image_paths),
    image_path = image_paths,
    output_dir = output_dir
  )
}