#' Parse Document with Page Numbers
#'
#' Extracts text content from a document while preserving page number metadata.
#' Supports PDF, DOCX, and TXT formats.
#'
#' @param file_path Character. Path to the document file.
#' @return A list with two elements:
#'   \item{pages}{A list where each element contains the text for one page}
#'   \item{metadata}{A data frame with page_number and character_count for each page}
#'
#' @examples
#' \dontrun{
#'   doc <- parse_document("report.pdf")
#'   doc$pages[[1]]  # Access first page text
#'   doc$metadata    # View page metadata
#' }
#'
#' @export
parse_document <- function(file_path) {

  # Check if file exists
  if (!file.exists(file_path)) {
    stop(sprintf("File not found: %s", file_path))
  }

  # Get file extension
  file_ext <- tolower(tools::file_ext(file_path))

  # Parse based on file type
  result <- switch(
    file_ext,
    "pdf" = parse_pdf(file_path),
    "docx" = parse_docx(file_path),
    "txt" = parse_txt(file_path),
    stop(sprintf("Unsupported file format: %s. Supported formats: pdf, docx, txt", file_ext))
  )

  return(result)
}


#' Parse PDF Document
#' @param file_path Path to PDF file
#' @return List with pages and metadata
#' @keywords internal
parse_pdf <- function(file_path) {

  if (!requireNamespace("pdftools", quietly = TRUE)) {
    stop("Package 'pdftools' is required to parse PDF files. Install with: install.packages('pdftools')")
  }

  # Extract text by page
  pages_text <- pdftools::pdf_text(file_path)

  # Create metadata
  metadata <- data.frame(
    page_number = seq_along(pages_text),
    character_count = nchar(pages_text),
    line_count = sapply(strsplit(pages_text, "\n"), length),
    stringsAsFactors = FALSE
  )

  # Convert to list of pages
  pages <- as.list(pages_text)
  names(pages) <- paste0("page_", seq_along(pages))

  return(list(
    pages = pages,
    metadata = metadata,
    file_path = file_path,
    file_type = "pdf",
    total_pages = length(pages)
  ))
}


#' Parse DOCX Document
#' @param file_path Path to DOCX file
#' @return List with pages and metadata
#' @keywords internal
parse_docx <- function(file_path) {

  if (!requireNamespace("officer", quietly = TRUE)) {
    stop("Package 'officer' is required to parse DOCX files. Install with: install.packages('officer')")
  }

  # Read docx
  doc <- officer::read_docx(file_path)

  # Extract content
  content <- officer::docx_summary(doc)

  # Get paragraphs only (filter out other content types)
  paragraphs <- content[content$content_type == "paragraph", ]

  # Combine all text
  full_text <- paste(paragraphs$text, collapse = "\n")

  # For DOCX, we'll estimate pages based on character count
  # Typical page: ~2000-3000 characters
  chars_per_page <- 2500
  estimated_pages <- ceiling(nchar(full_text) / chars_per_page)

  if (estimated_pages == 0) estimated_pages <- 1

  # Split text into estimated pages
  text_length <- nchar(full_text)
  pages <- list()

  for (i in 1:estimated_pages) {
    start_pos <- (i - 1) * chars_per_page + 1
    end_pos <- min(i * chars_per_page, text_length)

    pages[[i]] <- substr(full_text, start_pos, end_pos)
  }

  names(pages) <- paste0("page_", seq_along(pages))

  # Create metadata
  metadata <- data.frame(
    page_number = seq_along(pages),
    character_count = sapply(pages, nchar),
    line_count = sapply(pages, function(x) length(strsplit(x, "\n")[[1]])),
    stringsAsFactors = FALSE
  )

  return(list(
    pages = pages,
    metadata = metadata,
    file_path = file_path,
    file_type = "docx",
    total_pages = length(pages),
    note = "Page numbers are estimated based on character count for DOCX files"
  ))
}


#' Parse TXT Document
#' @param file_path Path to TXT file
#' @return List with pages and metadata
#' @keywords internal
parse_txt <- function(file_path) {

  # Read entire file
  full_text <- readLines(file_path, warn = FALSE)
  full_text <- paste(full_text, collapse = "\n")

  # Estimate pages (using same logic as DOCX)
  chars_per_page <- 2500
  estimated_pages <- ceiling(nchar(full_text) / chars_per_page)

  if (estimated_pages == 0) estimated_pages <- 1

  # Split text into estimated pages
  text_length <- nchar(full_text)
  pages <- list()

  for (i in 1:estimated_pages) {
    start_pos <- (i - 1) * chars_per_page + 1
    end_pos <- min(i * chars_per_page, text_length)

    pages[[i]] <- substr(full_text, start_pos, end_pos)
  }

  names(pages) <- paste0("page_", seq_along(pages))

  # Create metadata
  metadata <- data.frame(
    page_number = seq_along(pages),
    character_count = sapply(pages, nchar),
    line_count = sapply(pages, function(x) length(strsplit(x, "\n")[[1]])),
    stringsAsFactors = FALSE
  )

  return(list(
    pages = pages,
    metadata = metadata,
    file_path = file_path,
    file_type = "txt",
    total_pages = length(pages),
    note = "Page numbers are estimated based on character count for TXT files"
  ))
}
