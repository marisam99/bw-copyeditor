# ==============================================================================
# Tests for parse_document.R
# ==============================================================================

# Test parse_document() main function --------------------------------------

test_that("parse_document() rejects non-existent files", {
  expect_error(
    parse_document("fake_file.pdf"),
    "File not found"
  )
})

test_that("parse_document() rejects non-PDF files", {
  # Create a temporary file with unsupported extension
  temp_file <- tempfile(fileext = ".docx")
  file.create(temp_file)

  expect_error(
    parse_document(temp_file),
    "Only PDF files are supported"
  )

  # Cleanup
  unlink(temp_file)
})

# Test parse_to_text() -----------------------------------------------------

test_that("parse_to_text() returns correct structure", {
  skip_if_not_installed("pdftools")
  skip_if_not_installed("tibble")

  test_file <- "tests/testthat/fixtures/test_document.pdf"
  skip_if_not(file.exists(test_file), "Test PDF file not found")

  result <- parse_to_text(test_file)

  # Check structure
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("page_number", "content"))

  # Check types
  expect_type(result$page_number, "integer")
  expect_type(result$content, "character")

  # Check values
  expect_gt(nrow(result), 0)
  expect_true(all(nchar(result$content) > 0))
})

# Test parse_to_images() ---------------------------------------------------

test_that("parse_to_images() returns correct structure", {
  skip_if_not_installed("pdftools")
  skip_if_not_installed("tibble")

  test_file <- "tests/testthat/fixtures/test_document.pdf"
  skip_if_not(file.exists(test_file), "Test PDF file not found")

  result <- parse_to_images(test_file)

  # Check structure
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("page_number", "image_path"))

  # Check types
  expect_type(result$page_number, "integer")
  expect_type(result$image_path, "character")

  # Check values
  expect_gt(nrow(result), 0)

  # Check that image files exist
  expect_true(all(file.exists(result$image_path)))
})

# Integration tests --------------------------------------------------------

test_that("parse_document() defaults to text mode", {
  skip_if_not_installed("pdftools")

  test_file <- "tests/testthat/fixtures/test_document.pdf"
  skip_if_not(file.exists(test_file), "Test PDF file not found")

  result <- parse_document(test_file)

  # Should return tibble with text content
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("page_number", "content"))
})

test_that("parse_document() handles text mode explicitly", {
  skip_if_not_installed("pdftools")

  test_file <- "tests/testthat/fixtures/test_document.pdf"
  skip_if_not(file.exists(test_file), "Test PDF file not found")

  result <- parse_document(test_file, mode = "text")

  # Should return tibble with text content
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("page_number", "content"))
})

test_that("parse_document() handles images mode", {
  skip_if_not_installed("pdftools")

  test_file <- "tests/testthat/fixtures/test_document.pdf"
  skip_if_not(file.exists(test_file), "Test PDF file not found")

  result <- parse_document(test_file, mode = "images")

  # Should return tibble with image paths
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("page_number", "image_path"))
})
