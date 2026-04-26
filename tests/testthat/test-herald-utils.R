# -----------------------------------------------------------------------------
# test-herald-utils.R -- shared internal utilities
# -----------------------------------------------------------------------------

# -- htmlesc ------------------------------------------------------------------

test_that("htmlesc escapes & < > \" correctly", {
  expect_equal(herald:::htmlesc("a & b"), "a &amp; b")
  expect_equal(herald:::htmlesc("<b>"), "&lt;b&gt;")
  expect_equal(herald:::htmlesc('"hello"'), "&quot;hello&quot;")
  expect_equal(herald:::htmlesc("a < b & c > d"), "a &lt; b &amp; c &gt; d")
})

test_that("htmlesc is a no-op on plain text", {
  expect_equal(herald:::htmlesc("plain text"), "plain text")
})

test_that("htmlesc handles empty string", {
  expect_equal(herald:::htmlesc(""), "")
})

# -- raw_to_str ---------------------------------------------------------------

test_that("raw_to_str trims trailing spaces and null bytes", {
  raw_vec <- charToRaw("ABC   ")
  expect_equal(herald:::raw_to_str(raw_vec), "ABC")
})

test_that("raw_to_str returns empty string for all-null input", {
  raw_vec <- as.raw(c(0x00, 0x00))
  expect_equal(herald:::raw_to_str(raw_vec), "")
})

# -- validate_write_inputs ----------------------------------------------------

test_that("validate_write_inputs errors when data is not a data frame", {
  tmp <- withr::local_tempfile(fileext = ".xpt")
  expect_error(
    herald:::validate_write_inputs(
      data = list(a = 1),
      path = tmp,
      version = 5L,
      name = "DM",
      label = "Demographics"
    ),
    class = "herald_error"
  )
})

test_that("validate_write_inputs errors when directory does not exist", {
  expect_error(
    herald:::validate_write_inputs(
      data = data.frame(X = 1),
      path = "/nonexistent/path/dm.xpt",
      version = 5L,
      name = "DM",
      label = "Demographics"
    ),
    class = "herald_error_file"
  )
})

test_that("validate_write_inputs errors on unsupported version", {
  tmp <- withr::local_tempfile(fileext = ".xpt")
  expect_error(
    herald:::validate_write_inputs(
      data = data.frame(X = 1L),
      path = tmp,
      version = 9L,
      name = "DM",
      label = "Demographics"
    ),
    class = "herald_error"
  )
})

test_that("validate_write_inputs errors on unsupported column type", {
  tmp <- withr::local_tempfile(fileext = ".xpt")
  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  # Add a list column by constructing directly to avoid row-count mismatch
  df[["BAD"]] <- I(list(1L))
  expect_error(
    herald:::validate_write_inputs(
      data = df,
      path = tmp,
      version = 5L,
      name = "DM",
      label = "Demographics"
    ),
    class = "herald_error"
  )
})

test_that("validate_write_inputs accepts valid V5 inputs", {
  tmp <- withr::local_tempfile(fileext = ".xpt")
  df <- data.frame(AGE = 1L, SEX = "M", stringsAsFactors = FALSE)
  expect_true(
    herald:::validate_write_inputs(
      data = df,
      path = tmp,
      version = 5L,
      name = "DM",
      label = "Demographics"
    )
  )
})

test_that("validate_write_inputs accepts valid V8 inputs", {
  tmp <- withr::local_tempfile(fileext = ".xpt")
  df <- data.frame(AGE = 1L, stringsAsFactors = FALSE)
  expect_true(
    herald:::validate_write_inputs(
      data = df,
      path = tmp,
      version = 8L,
      name = "DM",
      label = "Demographics"
    )
  )
})

# -- validate_v5_compliance ---------------------------------------------------

test_that("validate_v5_compliance errors when dataset name > 8 chars", {
  df <- data.frame(X = 1L)
  expect_error(
    herald:::validate_v5_compliance(df, "TOOLONGNAME"),
    class = "herald_error"
  )
})

test_that("validate_v5_compliance errors on invalid chars in dataset name", {
  df <- data.frame(X = 1L)
  expect_error(
    herald:::validate_v5_compliance(df, "DM-2024"),
    class = "herald_error"
  )
})

test_that("validate_v5_compliance errors when variable name > 8 chars", {
  df <- data.frame(TOOLONGVARNAME = 1L)
  expect_error(
    herald:::validate_v5_compliance(df, "DM"),
    class = "herald_error"
  )
})

test_that("validate_v5_compliance errors on invalid chars in variable name", {
  bad_df <- structure(
    list("VAR-1" = "x"),
    class = "data.frame",
    row.names = 1L
  )
  expect_error(
    herald:::validate_v5_compliance(bad_df, "DM"),
    class = "herald_error"
  )
})

test_that("validate_v5_compliance errors when char column exceeds 200 bytes", {
  big_str <- strrep("A", 201L)
  df <- data.frame(VAR = big_str, stringsAsFactors = FALSE)
  expect_error(
    herald:::validate_v5_compliance(df, "DM"),
    class = "herald_error"
  )
})

test_that("validate_v5_compliance errors when label > 40 chars", {
  df <- data.frame(AGE = 1L)
  attr(df$AGE, "label") <- strrep("X", 41L)
  expect_error(
    herald:::validate_v5_compliance(df, "DM"),
    class = "herald_error"
  )
})

test_that("validate_v5_compliance errors when format name > 8 chars", {
  df <- data.frame(AGE = 1L)
  attr(df$AGE, "format.sas") <- "TOOLONGFMT10."
  expect_error(
    herald:::validate_v5_compliance(df, "DM"),
    class = "herald_error"
  )
})

test_that("validate_v5_compliance passes valid inputs", {
  df <- data.frame(AGE = 1L, SEX = "M", stringsAsFactors = FALSE)
  expect_true(herald:::validate_v5_compliance(df, "DM"))
})

# -- validate_v8_compliance ---------------------------------------------------

test_that("validate_v8_compliance errors when dataset name > 32 chars", {
  df <- data.frame(X = 1L)
  long_name <- strrep("A", 33L)
  expect_error(
    herald:::validate_v8_compliance(df, long_name),
    class = "herald_error"
  )
})

test_that("validate_v8_compliance errors when variable name > 32 chars", {
  long_col <- strrep("A", 33L)
  df <- structure(
    stats::setNames(list(1L), long_col),
    class = "data.frame",
    row.names = 1L
  )
  expect_error(
    herald:::validate_v8_compliance(df, "DM"),
    class = "herald_error"
  )
})

test_that("validate_v8_compliance passes valid inputs", {
  df <- data.frame(AGE = 1L, stringsAsFactors = FALSE)
  expect_true(herald:::validate_v8_compliance(df, "DM"))
})
