# ==============================================================================
# Title:        Image Prompt Builder
# Last Updated: 2025-11-05
# Description:  Functions to build user message for multimodal LLM from parsed image document.
#               Converts PDF pages to base64-encoded images for vision-capable models.
#               Handles automatic chunking for large documents that would exceed token/payload limits.
#               Uses fixed token estimates for image processing costs.
# ==============================================================================

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


#' Encode Image to Base64 Data URL
#'
#' Reads a PNG image file and converts it to a base64-encoded data URL
#' suitable for multimodal API requests.
#'
#' @param image_path Character. Path to PNG image file.
#'
#' @return Character string with data URL format: "data:image/png;base64,..."
#' @keywords internal
encode_image <- function(image_path) {
  # Check file exists
  if (!file.exists(image_path)) {
    stop(glue::glue("Image file not found: {image_path}"))
  }

  # Check it's a PNG file
  if (tolower(tools::file_ext(image_path)) != "png") {
    warning(glue::glue("Expected PNG file, got: {tools::file_ext(image_path)}"))
  }

  # Read the entire file as raw bytes
  image_size <- file.info(image_path)$size
  raw_bytes <- readBin(image_path, "raw", n = image_size)

  # Encode to base64 text
  base64_string <- base64enc::base64encode(raw_bytes)

  # Create data URL (format required by OpenAI Vision API)
  data_url <- paste0("data:image/png;base64,", base64_string)

  return(data_url)
}


#' Estimate Token Count for Image
#'
#' Returns the estimated token cost for processing an image with OpenAI's vision models.
#' Token costs are fixed based on detail level, not image content.
#'
#' @param detail Character. Detail level: "high" or "low" (default: "high").
#'   - "high": ~2,805 tokens per image (tiles image for detail, better for reading text)
#'   - "low": 85 tokens per image (resizes to 512x512, may miss small text)
#'
#' @return Integer. Estimated token count.
#' @keywords internal
estimate_image_tokens <- function(detail = "high") {
  # Token costs from OpenAI Vision API documentation
  # These are approximations - actual costs may vary slightly
  tokens <- switch(detail,
    "high" = 2805,  # High detail: tiles the image for better text recognition
    "low" = 85,     # Low detail: single 512x512 view
    stop(glue::glue("Invalid detail level: {detail}. Must be 'high' or 'low'."))
  )

  return(tokens)
}


#' Build Multimodal Content Array
#'
#' Constructs the multimodal content structure for API requests, combining
#' text context with base64-encoded images.
#'
#' @param parsed_document Tibble. Output from parse_document(mode = "images") with
#'   columns page_number and image_path.
#' @param deliverable_type Character. Type of deliverable.
#' @param audience Character. Target audience description.
#' @param detail Character. Image detail level: "high" or "low" (default: "high").
#'
#' @return List with multimodal content structure suitable for OpenAI Vision API.
#' @keywords internal
build_multimodal_content <- function(parsed_document, deliverable_type, audience, detail = "high") {

  # Start with text context
  header <- context_header(deliverable_type, audience)
  intro_text <- paste0(
    header, "\n\n",
    "File:\n\n",
    "The following pages are from a document that needs copyediting. ",
    "Please review each page for errors according to the instructions provided."
  )

  # Initialize content array with intro text
  content <- list(
    list(type = "text", text = intro_text)
  )

  # Add each page as an image
  for (i in seq_len(nrow(parsed_document))) {
    page_num <- parsed_document$page_number[i]
    image_path <- parsed_document$image_path[i]

    # Add page label
    content[[length(content) + 1]] <- list(
      type = "text",
      text = glue::glue("\nPage {page_num}:")
    )

    # Encode and add image
    data_url <- encode_image(image_path)
    content[[length(content) + 1]] <- list(
      type = "image_url",
      image_url = list(
        url = data_url,
        detail = detail
      )
    )
  }

  return(content)
}


#' Chunk Document by Image Count
#'
#' Splits a parsed document into chunks based on number of images per chunk,
#' ensuring each chunk stays within token and payload limits.
#'
#' @param parsed_document Tibble. Output from parse_document(mode = "images") with
#'   columns page_number and image_path.
#' @param deliverable_type Character. Type of deliverable.
#' @param audience Character. Target audience description.
#' @param images_per_chunk Integer. Maximum images per chunk (default: 20).
#' @param detail Character. Image detail level: "high" or "low" (default: "high").
#' @param model Character. Model name for reference (default: "gpt-4o").
#'
#' @return Tibble with columns: chunk_id, page_start, page_end, user_message.
#' @keywords internal
chunk_by_images <- function(parsed_document,
                            deliverable_type,
                            audience,
                            images_per_chunk = 20,
                            detail = "high",
                            model = "gpt-4o") {

  total_pages <- nrow(parsed_document)
  chunks <- list()
  chunk_id <- 1

  # Calculate number of chunks needed
  num_chunks <- ceiling(total_pages / images_per_chunk)

  message(glue::glue(
    "Splitting {total_pages} pages into {num_chunks} chunk(s) ",
    "({images_per_chunk} images per chunk)"
  ))

  # Split into chunks
  for (i in seq_len(num_chunks)) {
    # Calculate page range for this chunk
    page_start <- ((i - 1) * images_per_chunk) + 1
    page_end <- min(i * images_per_chunk, total_pages)

    # Extract pages for this chunk
    chunk_pages <- parsed_document %>%
      dplyr::filter(page_number >= page_start, page_number <= page_end)

    # Build multimodal content
    user_message <- build_multimodal_content(
      parsed_document = chunk_pages,
      deliverable_type = deliverable_type,
      audience = audience,
      detail = detail
    )

    # Estimate tokens for this chunk
    image_tokens <- nrow(chunk_pages) * estimate_image_tokens(detail)
    text_tokens <- 500  # Rough estimate for context text
    total_tokens <- image_tokens + text_tokens

    message(glue::glue(
      "  Chunk {chunk_id}: pages {page_start}-{page_end} ",
      "(~{format(total_tokens, big.mark = ',')} tokens)"
    ))

    # Store chunk info
    chunks[[length(chunks) + 1]] <- list(
      chunk_id = chunk_id,
      page_start = page_start,
      page_end = page_end,
      user_message = list(user_message)  # Wrap in list for list-column
    )

    chunk_id <- chunk_id + 1
  }

  # Convert to tibble
  result <- tibble::tibble(
    chunk_id = sapply(chunks, `[[`, "chunk_id"),
    page_start = sapply(chunks, `[[`, "page_start"),
    page_end = sapply(chunks, `[[`, "page_end"),
    user_message = lapply(chunks, `[[`, "user_message")
  )

  return(result)
}


# Main Function ---------------------------------------------------------------

#' Build Prompt for Multimodal API (Images)
#'
#' Constructs user messages for vision-capable LLM API requests with automatic chunking.
#' Takes a parsed document with images and formats it with deliverable type and audience
#' information. Images are base64-encoded and embedded as data URLs.
#'
#' @param parsed_document Tibble. Output from parse_document(mode = "images") with
#'   columns page_number and image_path.
#' @param deliverable_type Character. Type of deliverable (e.g., "external field-facing",
#'   "external client-facing", "internal").
#' @param audience Character. Description of the target audience.
#' @param context_window Integer. Maximum tokens per request (default: 128000 for gpt-4o).
#' @param detail Character. Image detail level: "high" or "low" (default: "high").
#'   Use "high" for copyediting to ensure small text is readable.
#' @param images_per_chunk Integer. Maximum images per chunk (default: 20).
#'   Adjust based on image size and context window. Conservative default for safety.
#' @param model Character. Model name for reference (default: "gpt-4o").
#'
#' @return Tibble with columns:
#'   \item{chunk_id}{Integer. Sequential chunk identifier}
#'   \item{page_start}{Integer. First page number in chunk}
#'   \item{page_end}{Integer. Last page number in chunk}
#'   \item{user_message}{List. Multimodal content structure with text and encoded images}
#'
#' @details
#' The function automatically chunks documents to stay within token and payload limits.
#' Each chunk contains up to `images_per_chunk` pages, with each image base64-encoded
#' and embedded as a data URL.
#'
#' Token costs per image (approximate):
#' - "high" detail: ~2,805 tokens (better for reading text, recommended for copyediting)
#' - "low" detail: ~85 tokens (may miss small text)
#'
#' The returned user_message is a list-column containing the multimodal content structure.
#' This differs from text mode where user_message is a character string.
#'
#' IMPORTANT: Image mode is more expensive and slower than text mode.
#' Use image mode only for documents where visual elements matter (e.g., slide decks,
#' documents with text in charts/diagrams). For pure text documents, use build_prompt()
#' with parse_document(mode = "text") instead.
#'
#' @examples
#' \dontrun{
#'   # Parse document as images
#'   slides <- parse_document(mode = "images")
#'
#'   # Build prompt(s) - may return single or multiple chunks
#'   prompts <- build_prompt_images(
#'     parsed_document = slides,
#'     deliverable_type = "external client-facing",
#'     audience = "Healthcare executives"
#'   )
#'
#'   # Check number of chunks
#'   nrow(prompts)
#'
#'   # Access the multimodal content for first chunk
#'   prompts$user_message[[1]]
#' }
#'
#' @export
build_prompt_images <- function(parsed_document,
                               deliverable_type,
                               audience,
                               context_window = 128000,
                               detail = "high",
                               images_per_chunk = 20,
                               model = "gpt-4o") {

  # Validate inputs
  if (missing(parsed_document) || !inherits(parsed_document, "data.frame")) {
    stop("parsed_document must be a tibble/data.frame from parse_document(mode = 'images')")
  }

  if (!"page_number" %in% names(parsed_document) || !"image_path" %in% names(parsed_document)) {
    stop("parsed_document must have 'page_number' and 'image_path' columns. Did you use mode = 'images'?")
  }

  if (missing(deliverable_type) || is.null(deliverable_type) || nchar(trimws(deliverable_type)) == 0) {
    stop("deliverable_type cannot be empty")
  }

  if (missing(audience) || is.null(audience) || nchar(trimws(audience)) == 0) {
    stop("audience cannot be empty")
  }

  if (!detail %in% c("high", "low")) {
    stop("detail must be 'high' or 'low'")
  }

  # Validate base64enc package is available
  if (!requireNamespace("base64enc", quietly = TRUE)) {
    stop("Package 'base64enc' is required. Install with: install.packages('base64enc')")
  }

  # Estimate total tokens
  total_pages <- nrow(parsed_document)
  tokens_per_image <- estimate_image_tokens(detail)
  estimated_tokens <- total_pages * tokens_per_image

  message(glue::glue(
    "Processing {total_pages} page(s) as images ",
    "(~{format(estimated_tokens, big.mark = ',')} tokens at '{detail}' detail)"
  ))

  # Calculate if we need to chunk
  # Use 90% of context window for safety (leave room for system prompt + response)
  safety_limit <- floor(context_window * 0.9)
  max_images_in_window <- floor(safety_limit / tokens_per_image)

  # Check if document fits in single chunk
  if (total_pages <= images_per_chunk && estimated_tokens <= safety_limit) {
    message("Document fits in single chunk - no splitting needed")

    # Build single chunk
    user_message <- build_multimodal_content(
      parsed_document = parsed_document,
      deliverable_type = deliverable_type,
      audience = audience,
      detail = detail
    )

    result <- tibble::tibble(
      chunk_id = 1L,
      page_start = min(parsed_document$page_number),
      page_end = max(parsed_document$page_number),
      user_message = list(user_message)
    )

  } else {
    # Need to chunk the document
    if (total_pages > max_images_in_window) {
      warning(glue::glue(
        "Document has {total_pages} pages but context window supports ~{max_images_in_window} images. ",
        "Some chunks may exceed limits. Consider reducing images_per_chunk parameter."
      ))
    }

    message(glue::glue(
      "Document will be split into multiple chunks (limit: {images_per_chunk} images per chunk)"
    ))

    result <- chunk_by_images(
      parsed_document = parsed_document,
      deliverable_type = deliverable_type,
      audience = audience,
      images_per_chunk = images_per_chunk,
      detail = detail,
      model = model
    )
  }

  # Estimate total cost (rough)
  total_input_tokens <- estimated_tokens + (nrow(result) * 500)  # Add context text estimate
  cost_per_1m <- 2.50  # gpt-4o input cost (approximate)
  estimated_cost <- (total_input_tokens / 1000000) * cost_per_1m

  message(glue::glue(
    "\nEstimated cost: ${format(estimated_cost, digits = 2)} ",
    "(based on ~{format(total_input_tokens, big.mark = ',')} input tokens for {model})"
  ))
  message("Note: Actual cost may vary based on response length and current API pricing.\n")

  return(result)
}
