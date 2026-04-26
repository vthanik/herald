# Tests for R/parquet-read.R (read_parquet function).

test_that("read_parquet errors when the file is missing", {
  skip_if_not_installed("arrow")
  expect_error(
    read_parquet("/definitely/not/here.parquet"),
    class = "herald_error_io"
  )
})

test_that("read_parquet reads a plain parquet file with no herald metadata", {
  skip_if_not_installed("arrow")
  f <- withr::local_tempfile(fileext = ".parquet")
  df <- data.frame(X = 1:3, Y = c("a", "b", "c"), stringsAsFactors = FALSE)
  arrow::write_parquet(df, f)
  out <- read_parquet(f)
  # No herald metadata -- no label / dataset_name attrs
  expect_null(attr(out, "label"))
  expect_null(attr(out, "dataset_name"))
  expect_equal(out$X, 1:3)
  expect_equal(out$Y, c("a", "b", "c"))
})

test_that("read_parquet skips sas.length when metadata value is non-integer", {
  skip_if_not_installed("arrow")
  f <- withr::local_tempfile(fileext = ".parquet")
  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  # Write manually with a bad length value in metadata
  tbl <- arrow::arrow_table(df)
  meta <- list(
    "herald.dataset.label" = "Test",
    "herald.col.X.label" = "X label",
    "herald.col.X.length" = "notanumber"
  )
  tbl <- tbl$ReplaceSchemaMetadata(meta)
  arrow::write_parquet(tbl, f)
  out <- read_parquet(f)
  # label is set but sas.length should NOT be set (NA parse result)
  expect_equal(attr(out$X, "label"), "X label")
  expect_null(attr(out$X, "sas.length"))
})

test_that("read_parquet sets ds_name when herald.dataset.name is present", {
  skip_if_not_installed("arrow")
  f <- withr::local_tempfile(fileext = ".parquet")
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  tbl <- arrow::arrow_table(df)
  meta <- list(
    "herald.dataset.name" = "DM",
    "herald.dataset.label" = ""
  )
  tbl <- tbl$ReplaceSchemaMetadata(meta)
  arrow::write_parquet(tbl, f)
  out <- read_parquet(f)
  # ds_name present and nzchar -> set; ds_lbl is empty -> NOT set
  expect_equal(attr(out, "dataset_name"), "DM")
  expect_null(attr(out, "label"))
})

test_that("read_parquet skips empty-string column metadata entries", {
  skip_if_not_installed("arrow")
  f <- withr::local_tempfile(fileext = ".parquet")
  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  tbl <- arrow::arrow_table(df)
  # Provide all column meta keys but with empty-string values
  meta <- list(
    "herald.col.X.label"  = "",
    "herald.col.X.format" = "",
    "herald.col.X.length" = "",
    "herald.col.X.type"   = ""
  )
  tbl <- tbl$ReplaceSchemaMetadata(meta)
  arrow::write_parquet(tbl, f)
  out <- read_parquet(f)
  # nzchar guards -- none of the attrs should be stamped
  expect_null(attr(out$X, "label"))
  expect_null(attr(out$X, "format.sas"))
  expect_null(attr(out$X, "sas.length"))
  expect_null(attr(out$X, "xpt_type"))
})

test_that("read_parquet restores all four column metadata attributes", {
  skip_if_not_installed("arrow")
  f <- withr::local_tempfile(fileext = ".parquet")
  df <- data.frame(AGE = 65L, stringsAsFactors = FALSE)
  tbl <- arrow::arrow_table(df)
  meta <- list(
    "herald.col.AGE.label"  = "Age in Years",
    "herald.col.AGE.format" = "8.",
    "herald.col.AGE.length" = "8",
    "herald.col.AGE.type"   = "integer"
  )
  tbl <- tbl$ReplaceSchemaMetadata(meta)
  arrow::write_parquet(tbl, f)
  out <- read_parquet(f)
  expect_equal(attr(out$AGE, "label"),      "Age in Years")
  expect_equal(attr(out$AGE, "format.sas"), "8.")
  expect_equal(attr(out$AGE, "sas.length"), 8L)
  expect_equal(attr(out$AGE, "xpt_type"),   "integer")
})
