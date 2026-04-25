# Tests for R/json-read.R -- read_json()

test_that("read_json() round-trips correctly", {
  dm <- data.frame(
    STUDYID = c("STUDY1", "STUDY1"),
    USUBJID = c("SUBJ01", "SUBJ02"),
    AGE = c(65L, 72L),
    WEIGHT = c(70.5, 85.2),
    stringsAsFactors = FALSE
  )
  attr(dm, "label") <- "Demographics"
  attr(dm$STUDYID, "label") <- "Study Identifier"
  attr(dm$AGE, "label") <- "Age"

  path <- withr::local_tempfile(fileext = ".json")

  write_json(dm, path, dataset = "DM")
  dm2 <- read_json(path)

  expect_equal(nrow(dm2), 2L)
  expect_equal(ncol(dm2), 4L)
  expect_equal(names(dm2), c("STUDYID", "USUBJID", "AGE", "WEIGHT"))
  expect_equal(dm2$STUDYID, c("STUDY1", "STUDY1"), ignore_attr = TRUE)
  expect_equal(dm2$AGE, c(65L, 72L), ignore_attr = TRUE)
  expect_equal(dm2$WEIGHT, c(70.5, 85.2), tolerance = 1e-10, ignore_attr = TRUE)
  expect_equal(attr(dm2, "label"), "Demographics")
  expect_equal(attr(dm2$STUDYID, "label"), "Study Identifier")
  expect_equal(attr(dm2$AGE, "label"), "Age")
  expect_equal(attr(dm2, "dataset_name"), "DM")
})

test_that("write_json() handles NA values", {
  df <- data.frame(
    X = c("a", NA, "c"),
    Y = c(1L, NA, 3L),
    stringsAsFactors = FALSE
  )

  path <- withr::local_tempfile(fileext = ".json")

  write_json(df, path, dataset = "TEST")
  df2 <- read_json(path)

  expect_equal(df2$X, c("a", NA, "c"), ignore_attr = TRUE)
  expect_true(is.na(df2$Y[2]))
})

test_that("read_json() handles empty dataset", {
  df <- data.frame(
    STUDYID = character(0),
    AGE = integer(0),
    stringsAsFactors = FALSE
  )

  path <- withr::local_tempfile(fileext = ".json")

  write_json(df, path, dataset = "EMPTY")
  df2 <- read_json(path)

  expect_equal(nrow(df2), 0L)
  expect_equal(ncol(df2), 2L)
  expect_equal(names(df2), c("STUDYID", "AGE"))
})

test_that("read_json() errors on invalid input", {
  # Non-existent file
  expect_error(read_json("nonexistent.json"), class = "herald_error_io")

  # Invalid JSON structure
  path <- withr::local_tempfile(fileext = ".json")
  writeLines('{"foo": "bar"}', path)
  expect_error(read_json(path), class = "herald_error_io")
})

test_that("read_json errors for non-existent file", {
  expect_error(read_json("/no/such/file.json"), class = "herald_error_io")
})

test_that("read_json errors for non-character path", {
  expect_error(read_json(42L), class = "herald_error_input")
})

test_that("read_json errors for invalid Dataset-JSON structure", {
  tmp <- withr::local_tempfile(fileext = ".json")
  # Missing 'rows' and 'columns'
  writeLines('{"name": "DM", "label": "Demographics"}', tmp)
  expect_error(read_json(tmp), class = "herald_error_io")
})

test_that("read_json handles dataset with zero rows", {
  tmp <- withr::local_tempfile(fileext = ".json")

  dm <- data.frame(STUDYID = character(0L), stringsAsFactors = FALSE)
  write_json(dm, tmp, dataset = "DM", label = "Demographics")

  result <- read_json(tmp)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0L)
  expect_true("STUDYID" %in% names(result))
})

test_that("write_json with herald.sort_keys sorts rows before writing", {
  tmp <- withr::local_tempfile(fileext = ".json")

  dm <- data.frame(
    STUDYID = c("S1", "S1", "S1"),
    USUBJID = c("003", "001", "002"),
    stringsAsFactors = FALSE
  )
  attr(dm, "herald.sort_keys") <- "USUBJID"

  write_json(dm, tmp, dataset = "DM")

  result <- read_json(tmp)
  expect_equal(as.character(result$USUBJID), c("001", "002", "003"))
})

test_that("read_json preserves sas.length attribute from JSON", {
  tmp <- withr::local_tempfile(fileext = ".json")

  # Write JSON with a column that has length attribute
  dm <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  attr(dm$STUDYID, "sas.length") <- 12L
  attr(dm$STUDYID, "label") <- "Study ID"
  write_json(dm, tmp, dataset = "DM")

  result <- read_json(tmp)
  # Should preserve the label
  expect_equal(attr(result$STUDYID, "label"), "Study ID")
})

test_that("read_json handles null values in rows (sparse rows)", {
  tmp <- withr::local_tempfile(fileext = ".json")

  # Create JSON with sparse rows (some cells missing)
  json_content <- jsonlite::toJSON(
    list(
      datasetJSONVersion = "1.1.0",
      name = "DM",
      records = 2L,
      columns = list(
        list(name = "STUDYID", dataType = "string"),
        list(name = "AGE", dataType = "integer")
      ),
      rows = list(
        list("S1", 65L),
        list("S2") # sparse row -- AGE missing
      )
    ),
    auto_unbox = TRUE
  )
  writeLines(json_content, tmp)

  result <- read_json(tmp)
  expect_equal(nrow(result), 2L)
  expect_true(is.na(result$AGE[2L]))
})

test_that("read_json errors when columns and rows fields missing", {
  tmp <- withr::local_tempfile(fileext = ".json")
  writeLines('{"name":"DM","label":"Demographics"}', tmp)

  expect_error(read_json(tmp), class = "herald_error_io")
})

test_that("read_json handles zero-row dataset with numeric columns", {
  json_content <- jsonlite::toJSON(
    list(
      datasetJSONVersion = "1.1",
      name = "DM",
      columns = list(list(name = "AGE", label = "Age", dataType = "integer")),
      rows = list()
    ),
    auto_unbox = TRUE
  )

  tmp <- withr::local_tempfile(fileext = ".json")
  writeLines(json_content, tmp)

  result <- read_json(tmp)
  expect_equal(nrow(result), 0L)
  expect_true("AGE" %in% names(result))
})
