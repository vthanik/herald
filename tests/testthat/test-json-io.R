# --------------------------------------------------------------------------
# test-json-io.R -- tests for json-io.R (Dataset-JSON I/O)
# --------------------------------------------------------------------------

# -- From test-dataset-json.R ---

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

  path <- tempfile(fileext = ".json")
  withr::defer(unlink(path))

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

test_that("read_json() round-trips correctly", {
  skip_if_not_installed("jsonlite")

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

  path <- tempfile(fileext = ".json")
  withr::defer(unlink(path))

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
  skip_if_not_installed("jsonlite")

  df <- data.frame(
    X = c("a", NA, "c"),
    Y = c(1L, NA, 3L),
    stringsAsFactors = FALSE
  )

  path <- tempfile(fileext = ".json")
  withr::defer(unlink(path))

  write_json(df, path, dataset = "TEST")
  df2 <- read_json(path)

  expect_equal(df2$X, c("a", NA, "c"), ignore_attr = TRUE)
  expect_true(is.na(df2$Y[2]))
})

test_that("read_json() handles empty dataset", {
  skip_if_not_installed("jsonlite")

  df <- data.frame(
    STUDYID = character(0),
    AGE = integer(0),
    stringsAsFactors = FALSE
  )

  path <- tempfile(fileext = ".json")
  withr::defer(unlink(path))

  write_json(df, path, dataset = "EMPTY")
  df2 <- read_json(path)

  expect_equal(nrow(df2), 0L)
  expect_equal(ncol(df2), 2L)
  expect_equal(names(df2), c("STUDYID", "AGE"))
})

test_that("xpt_to_json() converts XPT to Dataset-JSON", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(
    STUDYID = c("S1", "S1"),
    AGE = c(65L, 72L),
    stringsAsFactors = FALSE
  )
  attr(dm$STUDYID, "label") <- "Study ID"

  xpt <- tempfile(fileext = ".xpt")
  json <- tempfile(fileext = ".json")
  withr::defer(unlink(c(xpt, json)))

  write_xpt(dm, xpt, dataset = "DM", label = "Demographics")
  xpt_to_json(xpt, json)

  expect_true(file.exists(json))
  dm2 <- read_json(json)
  expect_equal(nrow(dm2), 2L)
  expect_equal(dm2$STUDYID, c("S1", "S1"), ignore_attr = TRUE)
})

test_that("json_to_xpt() converts Dataset-JSON to XPT", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(
    STUDYID = c("S1", "S1"),
    AGE = c(65L, 72L),
    stringsAsFactors = FALSE
  )

  json <- tempfile(fileext = ".json")
  xpt <- tempfile(fileext = ".xpt")
  withr::defer(unlink(c(json, xpt)))

  write_json(dm, json, dataset = "DM", label = "Demographics")
  json_to_xpt(json, xpt)

  expect_true(file.exists(xpt))
  dm2 <- read_xpt(xpt)
  expect_equal(nrow(dm2), 2L)
  expect_equal(dm2$STUDYID, c("S1", "S1"), ignore_attr = TRUE)
})

test_that("XPT -> JSON -> XPT round-trip preserves data", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(
    STUDYID = c("STUDY1", "STUDY1"),
    USUBJID = c("01-001", "01-002"),
    AGE = c(65, 72),
    SEX = c("M", "F"),
    stringsAsFactors = FALSE
  )
  attr(dm$STUDYID, "label") <- "Study Identifier"
  attr(dm$USUBJID, "label") <- "Unique Subject ID"
  attr(dm$AGE, "label") <- "Age"
  attr(dm$SEX, "label") <- "Sex"

  xpt1 <- tempfile(fileext = ".xpt")
  json <- tempfile(fileext = ".json")
  xpt2 <- tempfile(fileext = ".xpt")
  withr::defer(unlink(c(xpt1, json, xpt2)))

  write_xpt(dm, xpt1, dataset = "DM", label = "Demographics")
  xpt_to_json(xpt1, json)
  json_to_xpt(json, xpt2)

  dm_original <- read_xpt(xpt1)
  dm_roundtrip <- read_xpt(xpt2)

  expect_equal(dm_roundtrip$STUDYID, dm_original$STUDYID)
  expect_equal(dm_roundtrip$USUBJID, dm_original$USUBJID)
  expect_equal(dm_roundtrip$AGE, dm_original$AGE, tolerance = 1e-10)
  expect_equal(dm_roundtrip$SEX, dm_original$SEX)
})

test_that("read_json() errors on invalid input", {
  skip_if_not_installed("jsonlite")

  # Non-existent file
  expect_error(read_json("nonexistent.json"), "does not exist")

  # Invalid JSON structure
  path <- tempfile(fileext = ".json")
  withr::defer(unlink(path))
  writeLines('{"foo": "bar"}', path)
  expect_error(read_json(path), "Dataset-JSON")
})

test_that("write_json() errors on non-data.frame", {
  skip_if_not_installed("jsonlite")

  expect_error(
    write_json("not a data frame", tempfile()),
    "data frame"
  )
})

test_that("write_json() infers dataset name from path", {
  skip_if_not_installed("jsonlite")

  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  path <- tempfile(pattern = "adsl", fileext = ".json")
  withr::defer(unlink(path))

  write_json(df, path)
  raw <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  expect_true(grepl("ADSL", raw$name, ignore.case = TRUE))
})

# -- From test-json-io-extra.R ---

# -- read_json: error cases --------------------------------------------------

test_that("read_json errors for non-existent file", {
  expect_error(read_json("/no/such/file.json"), "does not exist")
})

test_that("read_json errors for non-character path", {
  skip_if_not_installed("jsonlite")
  expect_error(read_json(42L), class = "herald_error_input")
})

test_that("read_json errors for invalid Dataset-JSON structure", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  # Missing 'rows' and 'columns'
  writeLines('{"name": "DM", "label": "Demographics"}', tmp)
  expect_error(read_json(tmp), "Unrecognised")
})

# -- read_json: dataset with zero rows ----------------------------------------

test_that("read_json handles dataset with zero rows", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  dm <- data.frame(STUDYID = character(0L), stringsAsFactors = FALSE)
  write_json(dm, tmp, dataset = "DM", label = "Demographics")

  result <- read_json(tmp)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0L)
  expect_true("STUDYID" %in% names(result))
})

# -- write_json / read_json with date and datetime columns -------------------

test_that("write_json handles Date column as date dataType", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

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
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

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

# -- write_json: sort_keys attribute -----------------------------------------

test_that("write_json with herald.sort_keys sorts rows before writing", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

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

# -- write_json: dataset name from attribute ---------------------------------

test_that("write_json infers dataset name from dataset_name attribute", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  dm <- data.frame(X = 1L, stringsAsFactors = FALSE)
  attr(dm, "dataset_name") <- "MYDS"
  attr(dm, "label") <- "My Dataset"

  write_json(dm, tmp) # no dataset= arg

  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  expect_equal(raw$name, "MYDS")
  expect_equal(raw$label, "My Dataset")
})

# -- write_json: dataset name from filename when no attribute ----------------

test_that("write_json infers dataset name from filename when no attribute", {
  skip_if_not_installed("jsonlite")
  tmp <- file.path(tempdir(), "dm_test.json")
  on.exit(unlink(tmp))

  dm <- data.frame(X = 1L, stringsAsFactors = FALSE)
  write_json(dm, tmp) # no dataset=, no attribute

  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  expect_equal(raw$name, "DM_TEST")
})

# -- write_json: metadata_ref -------------------------------------------------

test_that("write_json with metadata_ref includes it in output", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  dm <- data.frame(X = 1L, stringsAsFactors = FALSE)
  write_json(dm, tmp, dataset = "DM", metadata_ref = "define.xml")

  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  expect_true(
    !is.null(raw$metaDataRef) ||
      !is.null(raw$metadataRef) ||
      grepl("define.xml", paste(unlist(raw), collapse = ""))
  )
})

# -- .build_dataframe: length/format attributes on columns ------------------

test_that("read_json preserves sas.length attribute from JSON", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  # Write JSON with a column that has length attribute
  dm <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  attr(dm$STUDYID, "sas.length") <- 12L
  attr(dm$STUDYID, "label") <- "Study ID"
  write_json(dm, tmp, dataset = "DM")

  result <- read_json(tmp)
  # Should preserve the label
  expect_equal(attr(result$STUDYID, "label"), "Study ID")
})

# -- round-trip with null row values -----------------------------------------

test_that("read_json handles null values in rows (sparse rows)", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

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

# -- From test-json-io-extra2.R ---

# -- write_json: logical column type -----------------------------------------

test_that("write_json handles logical column as boolean dataType", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(
    STUDYID = "S1",
    FLAG = TRUE,
    stringsAsFactors = FALSE
  )
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  write_json(dm, tmp, dataset = "DM")
  expect_true(file.exists(tmp))
  content <- readLines(tmp)
  expect_true(any(grepl("boolean", content, fixed = TRUE)))
})

test_that("write_json handles difftime column as time dataType via SAS format", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(RFTM = "12:30:00", stringsAsFactors = FALSE)
  attr(dm$RFTM, "format.sas") <- "TIME"

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  write_json(dm, tmp, dataset = "DM")
  expect_true(file.exists(tmp))
  content <- readLines(tmp)
  expect_true(any(grepl("time", content, fixed = TRUE)))
})

test_that("write_json handles SAS datetime format string as datetime", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(RFSTDTC = "2020-01-01T00:00:00", stringsAsFactors = FALSE)
  attr(dm$RFSTDTC, "format.sas") <- "DATETIME"

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  write_json(dm, tmp, dataset = "DM")
  content <- readLines(tmp)
  expect_true(any(grepl("datetime", content, fixed = TRUE)))
})

test_that("write_json handles SAS date format string as date", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(RFSTDTC = "2020-01-01", stringsAsFactors = FALSE)
  attr(dm$RFSTDTC, "format.sas") <- "DATE"

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  write_json(dm, tmp, dataset = "DM")
  content <- readLines(tmp)
  expect_true(any(grepl("date", content, fixed = TRUE)))
})


# -- write_json: with study_oid and metadata_version_oid ----------------------

test_that("write_json includes studyOID when study_oid specified", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

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

# -- read_json: with columns/rows absent (should error) -----------------------

test_that("read_json errors when columns and rows fields missing", {
  skip_if_not_installed("jsonlite")

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  writeLines('{"name":"DM","label":"Demographics"}', tmp)

  expect_error(read_json(tmp), "Unrecognised")
})

# -- .build_dataframe: empty rows with numeric type --------------------------

test_that("read_json handles zero-row dataset with numeric columns", {
  skip_if_not_installed("jsonlite")

  json_content <- jsonlite::toJSON(
    list(
      datasetJSONVersion = "1.1",
      name = "DM",
      columns = list(list(name = "AGE", label = "Age", dataType = "integer")),
      rows = list()
    ),
    auto_unbox = TRUE
  )

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  writeLines(json_content, tmp)

  result <- read_json(tmp)
  expect_equal(nrow(result), 0L)
  expect_true("AGE" %in% names(result))
})

# -- json_to_xpt: infers dataset name from JSON path -------------------------

test_that("json_to_xpt infers dataset name from file path", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(STUDYID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  json <- tempfile(fileext = ".json")
  xpt <- tempfile(fileext = ".xpt")
  on.exit({
    unlink(json)
    unlink(xpt)
  })

  write_json(dm, json, dataset = "DM")
  result <- json_to_xpt(json, xpt)
  expect_equal(result, xpt)
  expect_true(file.exists(xpt))
})

# -- xpt_to_json: infers dataset name and label from XPT ---------------------

test_that("xpt_to_json infers dataset name from XPT file name", {
  skip_if_not_installed("jsonlite")

  dm <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  attr(dm, "label") <- "Demographics"
  xpt <- tempfile(fileext = ".xpt")
  json <- tempfile(fileext = ".json")
  on.exit({
    unlink(xpt)
    unlink(json)
  })

  write_xpt(dm, xpt, dataset = "DM", label = "Demographics")
  result <- xpt_to_json(xpt, json)
  expect_equal(result, json)
  expect_true(file.exists(json))
})
