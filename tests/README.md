# Testing Guide

This directory contains automated tests for the bwcopyeditor package using the `testthat` framework.

## Quick Start

### Run all tests:
```r
devtools::test()
```

### Run tests for a specific file:
```r
testthat::test_file("tests/testthat/test-parse_document.R")
```

### Run tests interactively (for debugging):
```r
devtools::load_all()
source("tests/testthat/test-parse_document.R")
```

## Test Structure

- `testthat.R` - Entry point for test runner
- `testthat/` - Directory containing all test files
  - `test-*.R` - Test files (one per R source file)
  - `fixtures/` - Sample data files for testing

## Writing Tests

### Basic test structure:
```r
test_that("description of what you're testing", {
  result <- your_function(input)
  expect_equal(result, expected_value)
})
```

### Common expectations:
- `expect_equal(x, y)` - Check if x equals y
- `expect_true(condition)` - Check if condition is TRUE
- `expect_error(code, message)` - Check if code throws error
- `expect_type(x, "type")` - Check object type
- `expect_s3_class(x, "class")` - Check S3 class

### Skipping tests conditionally:
```r
skip_if_not_installed("package")  # Skip if package not available
skip_if_not(condition, "reason")   # Skip if condition false
skip_on_cran()                     # Skip when testing for CRAN
```

## Test Fixtures

Sample files for testing are stored in `testthat/fixtures/`. See that directory's README for details on what files are needed.

## Best Practices

1. **Test file naming**: Name test files `test-<source_file>.R` (e.g., `test-parse_document.R`)
2. **One test file per source file**: Keeps tests organized
3. **Descriptive test names**: Use clear descriptions in `test_that()`
4. **Test edge cases**: Empty inputs, missing files, invalid formats
5. **Use fixtures**: Don't create large test data in the test file itself
6. **Skip gracefully**: Use `skip_*` functions when dependencies are missing

## Example Test

```r
test_that("parse_document() rejects non-existent files", {
  expect_error(
    parse_document("fake_file.pdf"),
    "File not found"
  )
})
```

This test:
1. Describes what it's testing
2. Calls the function with invalid input
3. Expects a specific error message

## Running Tests in CI/CD

Tests automatically run when you:
- Run `R CMD check`
- Submit to CRAN
- Use GitHub Actions (if configured)

## Learn More

- [testthat documentation](https://testthat.r-lib.org/)
- [R Packages book - Testing chapter](https://r-pkgs.org/testing-basics.html)
