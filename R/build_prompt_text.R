# ==============================================================================
# Title:        Prompt Builder
# Last Updated: 2025-11-05
# Description:  Functions to build user message for LLM prompt from parsed text document.
#               Combines document content with project context (deliverable type, audience).
#               Handles automatic chunking for large documents that would exceed token limits.
#               Uses rtiktoken for accurate token counting matching OpenAI's tokenizers.
# ==============================================================================

# Load configuration ----------------------------------------------------------
source(file.path("R", "config.R"))

# Helper Functions ------------------------------------------------------------

#' Project Context Header
#'
#' Creates the header section with deliverable type and audience information.
#'
#' @param deliverable_type Character. Type of deliverable (e.g., "external field-facing",
#'   "external client-facing", "internal").
#' @param audience Character. Description of the target audience.
#'
#' @return Character string with formatted header.
#' @keywords internal
context_header <- function(deliverable_type, audience) {
  header <- paste0(
    "---\n",
    "Type of Document: ", deliverable_type, "\n",
    "Audience: ", audience, "\n",
    "---"
  )
  return(header)
}


#' Combine pages and content
#'
#' Combines all pages from the parsed document tibble into a single text string.
#'
#' @param parsed_document Tibble. Output from parse_document() with columns
#'   page_number and content.
#'
#' @return Character string with all pages combined
#' @keywords internal
combine_pages <- function(parsed_document) {
  # Format each page as "page X:\n{content}"
  combined_pages <- purrr::map2_chr(
    parsed_document$page_number,
    parsed_document$content,
    ~ paste0("page ", .x, ":\n", .y)
  )

  # Combine all pages with double newlines between them
  all_pages <- paste(combined_pages, collapse = "\n\n")

  return(all_pages)
}


#' Estimate Token Count
#'
#' Counts tokens in a text string using the rtiktoken package.
#' This provides exact token counts matching what OpenAI's API will use.
#'
#' @param text Character. Text to count tokens for.
#' @param model Character. Model name to determine which tokenizer to use
#'   (default: "gpt-4").
#'
#' @return Integer. Exact token count.
#' @keywords internal
estimate_tokens <- function(text, model = "gpt-4") {
  # Count tokens using rtiktoken
  token_count <- rtiktoken::get_token_count(text, model = model)
  return(token_count)
}


#' Chunk Document into Context Window Sized Pieces
#'
#' Splits a parsed document into chunks that fit within the token limit.
#' Each chunk contains a formatted user message.
#'
#' @param parsed_document Tibble. Output from parse_document() with columns
#'   page_number and content.
#' @param deliverable_type Character. Type of deliverable.
#' @param audience Character. Target audience description.
#' @param token_limit Integer. Maximum tokens per chunk (uses 90% for safety).
#' @param model Character. Model name for tokenization (default: "gpt-4").
#'
#' @return Tibble with columns: chunk_id, page_start, page_end, user_message.
#' @keywords internal
chunk_document <- function(parsed_document, deliverable_type, audience, token_limit, model = "gpt-4") {
  # Create document header (same for all chunks)
  header <- context_header(deliverable_type, audience)
  header_tokens <- estimate_tokens(header, model = model)

  # Calculate safety limit (90% of token_limit)
  safety_limit <- floor(token_limit * 0.9)

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
  for (i in seq_len(nrow(parsed_document))) {
    page_num <- parsed_document$page_number[i]
    page_content <- parsed_document$content[i]

    # Format the page and estimate its tokens
    formatted_page <- paste0("page ", page_num, ":\n", page_content)
    page_tokens <- estimate_tokens(formatted_page, model = model)

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

#' Build Prompt for Text-based API
#'
#' Constructs user messages for LLM API requests with automatic chunking if the
#' document exceeds the context window limit. Takes a parsed document and formats it
#' with deliverable type and audience information.
#'
#' @param parsed_document Tibble. Output from parse_document(mode = "text") with columns
#'   page_number and content.
#' @param deliverable_type Character. Type of deliverable (e.g., "external field-facing",
#'   "external client-facing", "internal").
#' @param audience Character. Description of the target audience.
#'
#' @return Tibble with columns:
#'   \item{chunk_id}{Integer. Sequential chunk identifier}
#'   \item{page_start}{Integer. First page number in chunk}
#'   \item{page_end}{Integer. Last page number in chunk}
#'   \item{user_message}{Character. Formatted user message text}
#'
#' @details
#' The function first attempts to fit the entire document in a single message.
#' If the token count exceeds 90% of the context window, the document
#' is automatically split into multiple chunks, with each chunk staying within
#' the token limit. Pages are never split mid-page.
#'
#' Token counting uses the rtiktoken package for exact token counts
#' matching the specified model's tokenizer.
#'
#' Model settings (context window and model name) are configured in R/config.R
#' and can be adjusted there as needed.
#'
#' The returned user_message does NOT include the system prompt - that should be
#' added separately by the caller.
#'
#' @examples
#' \dontrun{
#'   # Build prompt(s) from parsed document - may return single or multiple chunks
#'   prompts <- build_prompt_text(
#'     parsed_document = parsed_doc,
#'     deliverable_type = "external client-facing",
#'     audience = "Healthcare executives"
#'   )
#'
#'   # Check if chunking was needed
#'   nrow(prompts)  # 1 = single chunk, >1 = multiple chunks
#'
#'   # Access the user message for first chunk
#'   prompts$user_message[1]
#' }
#'
#' @export
build_prompt_text <- function(parsed_document,
                        deliverable_type,
                        audience) {

  # Use constants from R/config.R
  context_window <- CONTEXT_WINDOW_TEXT
  model <- MODEL_TEXT

  # Validate inputs
  if (missing(parsed_document) || !inherits(parsed_document, "data.frame")) {
    stop("parsed_document must be a tibble/data.frame from parse_document()")
  }

  if (!"page_number" %in% names(parsed_document) || !"content" %in% names(parsed_document)) {
    stop("parsed_document must have 'page_number' and 'content' columns")
  }

  if (missing(deliverable_type) || is.null(deliverable_type) || nchar(trimws(deliverable_type)) == 0) {
    stop("deliverable_type cannot be empty")
  }

  if (missing(audience) || is.null(audience) || nchar(trimws(audience)) == 0) {
    stop("audience cannot be empty")
  }

  # Validate rtiktoken package is available
  if (!requireNamespace("rtiktoken", quietly = TRUE)) {
    stop("Package 'rtiktoken' is required. Install with: install.packages('rtiktoken')")
  }

  # Build header and format all pages
  header <- context_header(deliverable_type, audience)
  all_pages <- combine_pages(parsed_document)
  system_prompt_path <- file.path("config", "system_prompt.txt")
  system_prompt <- paste(readLines(system_prompt_path, warn = FALSE), collapse = "\n")

  # Construct full inputs
  all_inputs <- paste0(system_prompt, "\n\n", header, "\n\nFile:\n\n", all_pages)

  # Count total tokens
  total_tokens <- estimate_tokens(all_inputs, model = model)
  safety_limit <- floor(context_window * 0.9)

  # Inform user of token count
  message(glue::glue("Total tokens in document: {format(total_tokens, big.mark = ',')} (limit: {format(safety_limit, big.mark = ',')})"))

  # Check if we need to chunk
  if (total_tokens <= safety_limit) {
    message("Document fits in single chunk - no splitting needed")
    # Fits in single message
    user_message <- paste0(header, "\n\nFile:\n\n", all_pages)
    result <- tibble::tibble(
      chunk_id = 1L,
      page_start = min(parsed_document$page_number),
      page_end = max(parsed_document$page_number),
      user_message = user_message
    )
  } else {
    # Need to chunk the document
    message(glue::glue(
      "Document exceeds token limit ({format(total_tokens, big.mark = ',')} > {format(safety_limit, big.mark = ',')}). Splitting into chunks..."
    ))

    result <- chunk_document(
      parsed_document = parsed_document,
      deliverable_type = deliverable_type,
      audience = audience,
      token_limit = context_window,
      model = model
    )

    message(glue::glue("Document split into {nrow(result)} chunk(s)"))
  }

  # Estimate total cost (rough)
  # Cost per 1M tokens for gpt-4 (approximate - may vary by model version)
  cost_per_1m <- 30.00  # gpt-4 input cost (approximate)
  estimated_cost <- (total_tokens / 1000000) * cost_per_1m

  message(glue::glue(
    "\nEstimated cost: ${format(estimated_cost, digits = 2)} ",
    "(based on ~{format(total_tokens, big.mark = ',')} input tokens for {model})"
  ))
  message("Note: Actual cost may vary based on response length and current API pricing.\n")

  return(result)
}
