test_that("convert_dataset() errors when input has no extension and from= not given", {
  xpt <- withr::local_tempfile(fileext = ".xpt")
  out <- withr::local_tempfile(fileext = ".json")
  dm  <- data.frame(STUDYID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  write_xpt(dm, xpt, dataset = "DM")

  expect_error(
    convert_dataset(xpt, out, from = "noext_input"),
    class = "herald_error_io"
  )
})

test_that("convert_dataset() errors when output has no extension and to= not given", {
  dm  <- data.frame(STUDYID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  xpt <- withr::local_tempfile(fileext = ".xpt")
  write_xpt(dm, xpt, dataset = "DM")

  expect_error(
    convert_dataset(xpt, tempfile()),
    class = "herald_error_io"
  )
})

test_that("convert_dataset() errors on unknown from= format", {
  xpt <- withr::local_tempfile(fileext = ".xpt")
  json <- withr::local_tempfile(fileext = ".json")
  dm  <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  write_xpt(dm, xpt, dataset = "DM")

  expect_error(
    convert_dataset(xpt, json, from = "csv"),
    class = "herald_error_io"
  )
})

test_that("convert_dataset() errors on unknown to= format", {
  xpt <- withr::local_tempfile(fileext = ".xpt")
  json <- withr::local_tempfile(fileext = ".json")
  dm  <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  write_xpt(dm, xpt, dataset = "DM")

  expect_error(
    convert_dataset(xpt, json, to = "xlsx"),
    class = "herald_error_io"
  )
})

test_that("convert_dataset() returns output path invisibly", {
  dm   <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  xpt  <- withr::local_tempfile(fileext = ".xpt")
  json <- withr::local_tempfile(fileext = ".json")
  write_xpt(dm, xpt, dataset = "DM")

  result <- convert_dataset(xpt, json)
  expect_equal(result, json)
})

test_that("convert_dataset() xpt -> json preserves data and attributes", {
  dm <- data.frame(
    STUDYID = c("STUDY1", "STUDY1"),
    USUBJID = c("S1-001", "S1-002"),
    AGE     = c(65L, 72L),
    stringsAsFactors = FALSE
  )
  attr(dm, "label")          <- "Demographics"
  attr(dm$USUBJID, "label")  <- "Unique Subject Identifier"
  attr(dm$STUDYID, "label")  <- "Study Identifier"

  xpt  <- withr::local_tempfile(fileext = ".xpt")
  json <- withr::local_tempfile(fileext = ".json")
  write_xpt(dm, xpt, dataset = "DM", label = "Demographics")
  convert_dataset(xpt, json)

  out <- read_json(json)
  expect_equal(out$STUDYID, dm$STUDYID, ignore_attr = TRUE)
  expect_equal(out$AGE,     dm$AGE,     ignore_attr = TRUE)
  expect_equal(attr(out, "label"), "Demographics")
})

test_that("convert_dataset() json -> xpt preserves data and attributes", {
  dm <- data.frame(
    STUDYID = c("STUDY1", "STUDY1"),
    AGE     = c(65L, 72L),
    stringsAsFactors = FALSE
  )
  attr(dm, "label") <- "Demographics"

  json <- withr::local_tempfile(fileext = ".json")
  xpt  <- withr::local_tempfile(fileext = ".xpt")
  write_json(dm, json, dataset = "DM", label = "Demographics")
  convert_dataset(json, xpt)

  out <- read_xpt(xpt)
  expect_equal(out$STUDYID, dm$STUDYID, ignore_attr = TRUE)
  expect_equal(out$AGE,     dm$AGE,     ignore_attr = TRUE)
  expect_equal(attr(out, "label"), "Demographics")
})

test_that("convert_dataset() xpt -> xpt same-format round-trip", {
  dm <- data.frame(
    STUDYID = "S1",
    AGE     = 63L,
    stringsAsFactors = FALSE
  )
  attr(dm, "label") <- "DM Label"

  xpt1 <- withr::local_tempfile(fileext = ".xpt")
  xpt2 <- withr::local_tempfile(fileext = ".xpt")
  write_xpt(dm, xpt1, dataset = "DM", label = "DM Label")
  convert_dataset(xpt1, xpt2)

  out <- read_xpt(xpt2)
  expect_equal(out$STUDYID, "S1",   ignore_attr = TRUE)
  expect_equal(out$AGE,     63L,    ignore_attr = TRUE)
  expect_equal(attr(out, "label"), "DM Label")
})

test_that("convert_dataset() json -> json same-format round-trip", {
  dm <- data.frame(STUDYID = "S1", AGE = 63L, stringsAsFactors = FALSE)
  attr(dm, "label") <- "DM Label"

  j1 <- withr::local_tempfile(fileext = ".json")
  j2 <- withr::local_tempfile(fileext = ".json")
  write_json(dm, j1, dataset = "DM", label = "DM Label")
  convert_dataset(j1, j2)

  out <- read_json(j2)
  expect_equal(out$STUDYID, "S1", ignore_attr = TRUE)
  expect_equal(attr(out, "label"), "DM Label")
})

test_that("convert_dataset() version= arg is honoured for xpt output", {
  dm  <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  json <- withr::local_tempfile(fileext = ".json")
  xpt  <- withr::local_tempfile(fileext = ".xpt")
  write_json(dm, json, dataset = "DM")

  expect_no_error(convert_dataset(json, xpt, version = 8L))
  expect_true(file.exists(xpt))
})

test_that("convert_dataset() explicit from=/to= overrides extension inference", {
  dm <- data.frame(STUDYID = "S1", AGE = 63L, stringsAsFactors = FALSE)

  xpt  <- withr::local_tempfile(fileext = ".xpt")
  json <- withr::local_tempfile(fileext = ".json")
  write_xpt(dm, xpt, dataset = "DM")

  convert_dataset(xpt, json, from = "xpt", to = "json")
  out <- read_json(json)
  expect_equal(out$STUDYID, "S1", ignore_attr = TRUE)
})

test_that("convert_dataset() dataset= and label= overrides are applied", {
  dm   <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  xpt  <- withr::local_tempfile(fileext = ".xpt")
  json <- withr::local_tempfile(fileext = ".json")
  write_xpt(dm, xpt, dataset = "DM")

  convert_dataset(xpt, json, dataset = "VS", label = "Vital Signs")
  out <- read_json(json)
  expect_equal(attr(out, "dataset_name"), "VS")
  expect_equal(attr(out, "label"),        "Vital Signs")
})

# -- parquet directions (skip when arrow not installed) -----------------------

test_that("convert_dataset() xpt -> parquet preserves data and attributes", {
  skip_if_not_installed("arrow")

  dm <- data.frame(
    USUBJID = c("S1", "S2"),
    AGE     = c(65L, 72L),
    stringsAsFactors = FALSE
  )
  attr(dm, "label")         <- "Demographics"
  attr(dm$USUBJID, "label") <- "Unique Subject Identifier"

  xpt <- withr::local_tempfile(fileext = ".xpt")
  pq  <- withr::local_tempfile(fileext = ".parquet")
  write_xpt(dm, xpt, dataset = "DM", label = "Demographics")

  result <- convert_dataset(xpt, pq)
  expect_equal(result, pq)

  out <- read_parquet(pq)
  expect_equal(out$USUBJID, dm$USUBJID, ignore_attr = TRUE)
  expect_equal(out$AGE,     dm$AGE,     ignore_attr = TRUE)
  expect_equal(attr(out, "dataset_name"), "DM")
  expect_equal(attr(out, "label"),        "Demographics")
  expect_equal(attr(out$USUBJID, "label"), "Unique Subject Identifier")
})

test_that("convert_dataset() parquet -> xpt preserves data and attributes", {
  skip_if_not_installed("arrow")

  dm <- data.frame(
    USUBJID = c("S1", "S2"),
    AGE     = c(65L, 72L),
    stringsAsFactors = FALSE
  )
  attr(dm, "label")         <- "Demographics"
  attr(dm$USUBJID, "label") <- "Subject ID"

  pq  <- withr::local_tempfile(fileext = ".parquet")
  xpt <- withr::local_tempfile(fileext = ".xpt")
  write_parquet(dm, pq, dataset = "DM", label = "Demographics")

  result <- convert_dataset(pq, xpt)
  expect_equal(result, xpt)

  out <- read_xpt(xpt)
  expect_equal(out$USUBJID, dm$USUBJID, ignore_attr = TRUE)
  expect_equal(out$AGE,     dm$AGE,     ignore_attr = TRUE)
  expect_equal(attr(out, "label"), "Demographics")
})

test_that("convert_dataset() json -> parquet preserves data and attributes", {
  skip_if_not_installed("arrow")

  dm <- data.frame(
    USUBJID = c("S1", "S2"),
    AGE     = c(65L, 72L),
    stringsAsFactors = FALSE
  )
  attr(dm, "label") <- "Demographics"

  json <- withr::local_tempfile(fileext = ".json")
  pq   <- withr::local_tempfile(fileext = ".parquet")
  write_json(dm, json, dataset = "DM", label = "Demographics")

  result <- convert_dataset(json, pq)
  expect_equal(result, pq)

  out <- read_parquet(pq)
  expect_equal(out$USUBJID, dm$USUBJID, ignore_attr = TRUE)
  expect_equal(out$AGE,     dm$AGE,     ignore_attr = TRUE)
  expect_equal(attr(out, "dataset_name"), "DM")
  expect_equal(attr(out, "label"),        "Demographics")
})

test_that("convert_dataset() parquet -> json preserves data and attributes", {
  skip_if_not_installed("arrow")

  dm <- data.frame(
    USUBJID = c("S1", "S2"),
    AGE     = c(65L, 72L),
    stringsAsFactors = FALSE
  )
  attr(dm, "label") <- "Demographics"

  pq   <- withr::local_tempfile(fileext = ".parquet")
  json <- withr::local_tempfile(fileext = ".json")
  write_parquet(dm, pq, dataset = "DM", label = "Demographics")

  result <- convert_dataset(pq, json)
  expect_equal(result, json)

  out <- read_json(json)
  expect_equal(out$USUBJID, dm$USUBJID, ignore_attr = TRUE)
  expect_equal(out$AGE,     dm$AGE,     ignore_attr = TRUE)
  expect_equal(attr(out, "label"), "Demographics")
})

test_that("convert_dataset() parquet -> parquet same-format round-trip", {
  skip_if_not_installed("arrow")

  dm <- data.frame(USUBJID = "S1", AGE = 63L, stringsAsFactors = FALSE)
  attr(dm, "label") <- "DM Label"

  p1 <- withr::local_tempfile(fileext = ".parquet")
  p2 <- withr::local_tempfile(fileext = ".parquet")
  write_parquet(dm, p1, dataset = "DM", label = "DM Label")
  convert_dataset(p1, p2)

  out <- read_parquet(p2)
  expect_equal(out$USUBJID, "S1",     ignore_attr = TRUE)
  expect_equal(attr(out, "label"),    "DM Label")
})

test_that("convert_dataset() parquet -> xpt version= arg works", {
  skip_if_not_installed("arrow")

  dm  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  pq  <- withr::local_tempfile(fileext = ".parquet")
  xpt <- withr::local_tempfile(fileext = ".xpt")
  write_parquet(dm, pq, dataset = "DM")

  expect_no_error(convert_dataset(pq, xpt, version = 8L))
  expect_true(file.exists(xpt))
})
