# Tests for R/json-write.R -- write_json()

test_that("write_json() creates valid JSON", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(
    STUDYID = c("STUDY1", "STUDY1"),
    USUBJID = c("SUBJ01", "SUBJ02"),
    AGE = c(65L, 72L),
    stringsAsFactors = FALSE
  )
  attr(dm$STUDYID, "label") <- "Study Identifier"
  attr(dm$USUBJID, "label") <- "Unique Subject Identifier"
  attr(dm$AGE, "label") <- "Age"

  path <- withr::local_tempfile(fileext = ".json")

  result <- write_json(dm, path, dataset = "DM", label = "Demographics")
  # write_json returns x invisibly (not the path)
  expect_true(is.data.frame(result))
  expect_true(file.exists(path))

  # Parse and verify v1.1 flat structure
  raw <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  expect_equal(raw$datasetJSONVersion, "1.1.0")

  # v1.1: flat, not nested under clinicalData
  expect_null(raw$clinicalData)
  expect_equal(raw$records, 2L)
  expect_equal(raw$name, "DM")
  expect_equal(raw$label, "Demographics")
  expect_equal(raw$itemGroupOID, "IG.DM")
  expect_true(!is.null(raw$sourceSystem))
  expect_equal(raw$sourceSystem$name, "herald")

  # columns (not items)
  expect_equal(length(raw$columns), 3L)
  expect_equal(raw$columns[[1]]$name, "STUDYID")
  expect_equal(raw$columns[[1]]$label, "Study Identifier")
  expect_equal(raw$columns[[1]]$dataType, "string")
  expect_true(!is.null(raw$columns[[1]]$itemOID))
  expect_equal(raw$columns[[3]]$dataType, "integer")

  # rows (not itemData)
  expect_equal(length(raw$rows), 2L)
})

test_that("write_json() errors on non-data.frame", {
  skip_if_not_installed("jsonlite")

  expect_error(
    write_json("not a data frame", tempfile()),
    class = "herald_error_input"
  )
})

test_that("write_json() infers dataset name from path", {
  skip_if_not_installed("jsonlite")

  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  path <- withr::local_tempfile(pattern = "adsl", fileext = ".json")

  write_json(df, path)
  raw <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  expect_true(grepl("ADSL", raw$name, ignore.case = TRUE))
})

test_that("write_json handles Date column as date dataType", {
  skip_if_not_installed("jsonlite")
  tmp <- withr::local_tempfile(fileext = ".json")

  dm <- data.frame(
    STUDYID = "S1",
    RFSTDTC = as.Date("2020-01-01"),
    stringsAsFactors = FALSE
  )
  expect_no_error(write_json(dm, tmp, dataset = "DM"))

  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  date_col <- Filter(function(c) c[["name"]] == "RFSTDTC", raw$columns)[[1L]]
  expect_equal(date_col$dataType, "date")
})

test_that("write_json handles POSIXct column as datetime dataType", {
  skip_if_not_installed("jsonlite")
  tmp <- withr::local_tempfile(fileext = ".json")

  dm <- data.frame(
    STUDYID = "S1",
    stringsAsFactors = FALSE
  )
  dm$RFSTDTC <- as.POSIXct("2020-01-01 10:00:00", tz = "UTC")

  expect_no_error(write_json(dm, tmp, dataset = "DM"))

  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  dt_col <- Filter(function(c) c[["name"]] == "RFSTDTC", raw$columns)[[1L]]
  expect_equal(dt_col$dataType, "datetime")
})

test_that("write_json infers dataset name from dataset_name attribute", {
  skip_if_not_installed("jsonlite")
  tmp <- withr::local_tempfile(fileext = ".json")

  dm <- data.frame(X = 1L, stringsAsFactors = FALSE)
  attr(dm, "dataset_name") <- "MYDS"
  attr(dm, "label") <- "My Dataset"

  write_json(dm, tmp) # no dataset= arg

  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  expect_equal(raw$name, "MYDS")
  expect_equal(raw$label, "My Dataset")
})

test_that("write_json infers dataset name from filename when no attribute", {
  skip_if_not_installed("jsonlite")
  tmp <- file.path(withr::local_tempdir(), "dm_test.json")

  dm <- data.frame(X = 1L, stringsAsFactors = FALSE)
  write_json(dm, tmp) # no dataset=, no attribute

  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  expect_equal(raw$name, "DM_TEST")
})

test_that("write_json with metadata_ref includes it in output", {
  skip_if_not_installed("jsonlite")
  tmp <- withr::local_tempfile(fileext = ".json")

  dm <- data.frame(X = 1L, stringsAsFactors = FALSE)
  write_json(dm, tmp, dataset = "DM", metadata_ref = "define.xml")

  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  expect_true(
    !is.null(raw$metaDataRef) ||
      !is.null(raw$metadataRef) ||
      grepl("define.xml", paste(unlist(raw), collapse = ""))
  )
})

test_that("write_json handles logical column as boolean dataType", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(
    STUDYID = "S1",
    FLAG = TRUE,
    stringsAsFactors = FALSE
  )
  tmp <- withr::local_tempfile(fileext = ".json")

  write_json(dm, tmp, dataset = "DM")
  expect_true(file.exists(tmp))
  content <- readLines(tmp)
  expect_true(any(grepl("boolean", content, fixed = TRUE)))
})

test_that("write_json handles difftime column as time dataType via SAS format", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(RFTM = "12:30:00", stringsAsFactors = FALSE)
  attr(dm$RFTM, "format.sas") <- "TIME"

  tmp <- withr::local_tempfile(fileext = ".json")

  write_json(dm, tmp, dataset = "DM")
  expect_true(file.exists(tmp))
  content <- readLines(tmp)
  expect_true(any(grepl("time", content, fixed = TRUE)))
})

test_that("write_json handles SAS datetime format string as datetime", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(RFSTDTC = "2020-01-01T00:00:00", stringsAsFactors = FALSE)
  attr(dm$RFSTDTC, "format.sas") <- "DATETIME"

  tmp <- withr::local_tempfile(fileext = ".json")

  write_json(dm, tmp, dataset = "DM")
  content <- readLines(tmp)
  expect_true(any(grepl("datetime", content, fixed = TRUE)))
})

test_that("write_json handles SAS date format string as date", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(RFSTDTC = "2020-01-01", stringsAsFactors = FALSE)
  attr(dm$RFSTDTC, "format.sas") <- "DATE"

  tmp <- withr::local_tempfile(fileext = ".json")

  write_json(dm, tmp, dataset = "DM")
  content <- readLines(tmp)
  expect_true(any(grepl("date", content, fixed = TRUE)))
})

test_that("write_json includes studyOID when study_oid specified", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  tmp <- withr::local_tempfile(fileext = ".json")

  write_json(
    dm,
    tmp,
    dataset = "DM",
    study_oid = "STUDY.001",
    metadata_version_oid = "MDV.001"
  )
  content <- paste(readLines(tmp), collapse = "\n")
  expect_true(grepl("STUDY.001", content, fixed = TRUE))
  expect_true(grepl("MDV.001", content, fixed = TRUE))
})
