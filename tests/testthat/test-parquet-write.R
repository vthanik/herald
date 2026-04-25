# Tests for R/parquet-write.R (write_parquet function).

test_that("parquet round-trip preserves labels / formats / lengths / type", {
  skip_if_not_installed("arrow")

  dm <- data.frame(
    USUBJID = c("S1", "S2"),
    AGE     = c(65L, 72L),
    stringsAsFactors = FALSE
  )
  attr(dm, "label")                <- "Demographics"
  attr(dm$USUBJID, "label")        <- "Unique Subject Identifier"
  attr(dm$USUBJID, "sas.length")   <- 40L
  attr(dm$USUBJID, "xpt_type")     <- "text"
  attr(dm$AGE,     "label")        <- "Age"
  attr(dm$AGE,     "format.sas")   <- "8."
  attr(dm$AGE,     "sas.length")   <- 8L
  attr(dm$AGE,     "xpt_type")     <- "integer"

  f <- withr::local_tempfile(fileext = ".parquet")
  write_parquet(dm, f)
  expect_true(file.exists(f))
  out <- read_parquet(f)

  expect_equal(attr(out, "label"), "Demographics")
  expect_equal(attr(out$USUBJID, "label"), "Unique Subject Identifier")
  expect_equal(attr(out$USUBJID, "sas.length"), 40L)
  expect_equal(attr(out$USUBJID, "xpt_type"),   "text")
  expect_equal(attr(out$AGE, "label"),       "Age")
  expect_equal(attr(out$AGE, "format.sas"),  "8.")
  expect_equal(attr(out$AGE, "sas.length"),  8L)
  expect_equal(attr(out$AGE, "xpt_type"),    "integer")

  expect_equal(out$USUBJID, c("S1", "S2"), ignore_attr = TRUE)
  expect_equal(out$AGE,     c(65L, 72L),   ignore_attr = TRUE)
})

test_that("write_parquet with dataset param round-trips dataset_name", {
  skip_if_not_installed("arrow")

  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  f  <- withr::local_tempfile(fileext = ".parquet")
  write_parquet(dm, f, dataset = "DM", label = "Demographics")
  out <- read_parquet(f)

  expect_equal(attr(out, "dataset_name"), "DM")
  expect_equal(attr(out, "label"),        "Demographics")
})

test_that("write_parquet infers dataset_name from file stem when no param", {
  skip_if_not_installed("arrow")

  f  <- withr::local_tempfile(pattern = "ae", fileext = ".parquet")
  write_parquet(data.frame(USUBJID = "S1", stringsAsFactors = FALSE), f)  # inline -> no capture
  out <- read_parquet(f)

  expect_equal(attr(out, "dataset_name"), toupper(tools::file_path_sans_ext(basename(f))))
})

test_that("write_parquet infers dataset name from bare variable symbol", {
  skip_if_not_installed("arrow")
  adsl <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  f <- withr::local_tempfile(fileext = ".parquet")
  write_parquet(adsl, f)
  out <- read_parquet(f)
  expect_equal(attr(out, "dataset_name"), "ADSL")
})

test_that("write_parquet explicit dataset= beats variable symbol capture", {
  skip_if_not_installed("arrow")
  adsl <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  f <- withr::local_tempfile(fileext = ".parquet")
  write_parquet(adsl, f, dataset = "CUSTOM")
  out <- read_parquet(f)
  expect_equal(attr(out, "dataset_name"), "CUSTOM")
})

test_that("write_parquet falls through symbol capture for inline expression", {
  skip_if_not_installed("arrow")
  f <- file.path(withr::local_tempdir(), "vs.parquet")
  write_parquet(data.frame(X = 1L), f)
  out <- read_parquet(f)
  expect_equal(attr(out, "dataset_name"), "VS")
})
