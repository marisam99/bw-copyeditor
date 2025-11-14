# ==============================================================================
# Title:        Prompt Builder
# Last Updated: 2025-11-05
# Description:  Functions to build user message for LLM prompt from extracted text document.
#               Combines document content with project context (document type, audience).
#               Handles automatic chunking for large documents that would exceed token limits.
#               Uses rtiktoken for accurate token counting matching OpenAI's tokenizers.
# Output:       A tibble with fields: chunk_id | page_start | page_end | user_message
# ==============================================================================

# Helper Functions ------------------------------------------------------------

#' Combine pages and content
#'
#' Combines all pages into a single text string that can be passed to the API.
#'
#' @param extracted_document Output from extract_document() with page_number and content columns.
#' @return Combined text from all pages.
#' @keywords internal
combine_pages <- function(extracted_document) {
  # Format each page as "page X:\n{content}"
  combined_pages <- purrr::map2_chr(
    extracted_document$page_number,
    extracted_document$content,
    ~ paste0("page ", .x, ":\n", .y)
  )

  # Combine all pages with double newlines between them
  all_pages <- paste(combined_pages, collapse = "\n\n")

  return(all_pages)
}

#' Chunk Document
#'
#' If a document's content would exceed the token limit, splits content into appropriately-sized chunks.
#'
#' @param extracted_document Output from extract_document().
#' @param document_type Type of document (see README for examples).
#' @param audience Target audience (see README for examples).
#' @return Table with chunk_id, page_start, page_end, user_message.
#' @keywords internal
chunk_document <- function(extracted_document, document_type, audience) {
  # Create document header (same for all chunks)
  header <- context_header(document_type, audience)
  header_tokens <- estimate_tokens(header)

  # Calculate safety limit (90% of token_limit)
  safety_limit <- floor(CONTEXT_WINDOW_TEXT * 0.9)

  # Calculate tokens available for page content, given reserved space for header
  available_tokens <- safety_limit - header_tokens

  if (available_tokens <= 0) {
    stop("Token limit too small to fit header")
  }

  # Initialize chunking variables
  chunks <- list()
  current_chunk_pages <- list()
  current_chunk_tokens <- 0
  chunk_id <- 1
  page_start <- NULL

  # Iterate through pages
  for (i in seq_len(nrow(extracted_document))) {
    page_num <- extracted_document$page_number[i]
    page_content <- extracted_document$content[i]

    # Format the page and estimate its tokens
    formatted_page <- paste0("page ", page_num, ":\n", page_content)
    page_tokens <- estimate_tokens(formatted_page)

    # Check if adding this page would exceed the limit
    potential_tokens <- current_chunk_tokens + page_tokens

    # If this page alone is too large, warn but include it anyway
    if (page_tokens > available_tokens && length(current_chunk_pages) == 0) {
      warning(glue::glue("Page {page_num} exceeds token limit but will be included as a single chunk"))
    }

    # Start new chunk if needed
    if (potential_tokens > available_tokens && length(current_chunk_pages) > 0) {
      # Save current chunk
      chunk_data <- tibble::tibble(
        page_number = sapply(current_chunk_pages, `[[`, "page_number"),
        content = sapply(current_chunk_pages, `[[`, "content")
      )

      formatted_pages <- combine_pages(chunk_data)
      user_message <- paste0(header, "\n\nFile:\n\n", formatted_pages)

      chunks[[length(chunks) + 1]] <- list(
        chunk_id = chunk_id,
        page_start = page_start,
        page_end = current_chunk_pages[[length(current_chunk_pages)]]$page_number,
        user_message = user_message
      )

      # Reset for next chunk
      chunk_id <- chunk_id + 1
      current_chunk_pages <- list()
      current_chunk_tokens <- 0
      page_start <- NULL
    }

    # Add page to current chunk
    if (is.null(page_start)) {
      page_start <- page_num
    }
    current_chunk_pages[[length(current_chunk_pages) + 1]] <- list(
      page_number = page_num,
      content = page_content
    )
    current_chunk_tokens <- current_chunk_tokens + page_tokens
  }

  # Save final chunk
  if (length(current_chunk_pages) > 0) {
    chunk_data <- tibble::tibble(
      page_number = sapply(current_chunk_pages, `[[`, "page_number"),
      content = sapply(current_chunk_pages, `[[`, "content")
    )

    formatted_pages <- combine_pages(chunk_data)
    user_message <- paste0(header, "\n\nFile:\n\n", formatted_pages)

    chunks[[length(chunks) + 1]] <- list(
      chunk_id = chunk_id,
      page_start = page_start,
      page_end = current_chunk_pages[[length(current_chunk_pages)]]$page_number,
      user_message = user_message
    )
  }

  # Convert to tibble
  result <- tibble::tibble(
    chunk_id = sapply(chunks, `[[`, "chunk_id"),
    page_start = sapply(chunks, `[[`, "page_start"),
    page_end = sapply(chunks, `[[`, "page_end"),
    user_message = sapply(chunks, `[[`, "user_message")
  )

  return(result)
}


# Main Function ---------------------------------------------------------------

#' Build Text-Based Prompt
#'
#' Creates user prompts from extracted text. Automatically splits large documents into chunks.
#'
#' @param extracted_document Output from extract_document(mode = "text").
#' @param document_type Type of document (see README for examples).
#' @param audience Target audience description (see README for examples).
#' @return Table with chunk_id, page_start, page_end, and user_message columns.
#'
#' @examples
#' \dontrun{
#'   # Build prompts from extracted document
#'   prompts <- build_prompt_text(
#'     extracted_document = doc,
#'     document_type = "external presentation",
#'     audience = "Executive clients"
#'   )
#' }
#'
#' @export
build_prompt_text <- function(extracted_document,
                        document_type,
                        audience) {

  # Validate inputs
  if (missing(extracted_document) || !inherits(extracted_document, "data.frame")) {
    stop("extracted_document must be a tibble/data.frame from extract_document()")
  }

  if (!"page_number" %in% names(extracted_document) || !"content" %in% names(extracted_document)) {
    stop("extracted_document must have 'page_number' and 'content' columns")
  }

  if (missing(document_type) || is.null(document_type) || nchar(trimws(document_type)) == 0) {
    stop("Document_type cannot be empty. See README for examples.")
  }

  if (missing(audience) || is.null(audience) || nchar(trimws(audience)) == 0) {
    stop("Audience cannot be empty. See README for examples.")
  }

  # Build header and format all pages
  header <- context_header(document_type, audience)
  all_pages <- combine_pages(extracted_document)

  # Count total input tokens; inform user
  all_inputs <- paste0(SYSTEM_PROMPT, "\n\n", header, "\n\nFile:\n\n", all_pages)
  total_tokens <- estimate_tokens(all_inputs)
  safety_limit <- floor(CONTEXT_WINDOW_TEXT * 0.9)
  message(glue::glue("Total tokens in document: {format(total_tokens, big.mark = ',')} (limit: {format(safety_limit, big.mark = ',')})"))

  # Check if we need to chunk
  if (total_tokens <= safety_limit) {
    message("Document fits in single chunk - no splitting needed\n")
    # Fits in single message
    user_message <- paste0(header, "\n\nFile:\n\n", all_pages)
    result <- tibble::tibble(
      chunk_id = 1L,
      page_start = min(extracted_document$page_number),
      page_end = max(extracted_document$page_number),
      user_message = user_message
    )
  } else {
    # Need to chunk the document
    message(glue::glue(
      "Document exceeds token limit ({format(total_tokens, big.mark = ',')} > {format(safety_limit, big.mark = ',')}). Splitting into chunks..."
    ))

    result <- chunk_document(
      extracted_document = extracted_document,
      document_type = document_type,
      audience = audience
    )

    message(glue::glue("Document split into {nrow(result)} chunk(s)\n"))
  }

  # Estimate total cost (rough)
  estimated_cost <- (total_tokens / 1000000) * COST_PER_1M

  message(glue::glue(
    "Estimated minimum cost: ${format(estimated_cost, digits = 2)} ",
    "(based on ~{format(total_tokens, big.mark = ',')} input tokens for {MODEL_TEXT})"
  ))
  message("Note: Final cost will depend on response length.\n")

  return(result)
}
