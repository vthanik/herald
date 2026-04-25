# Tests for Parquet I/O. Requires the `arrow` package (Suggests); skipped
# in CI environments that don't have it installed.

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

  f <- tempfile(fileext = ".parquet")
  write_parquet(dm, f)
  expect_true(file.exists(f))
  out <- read_parquet(f)
  unlink(f)

  expect_equal(attr(out, "label"), "Demographics")
  expect_equal(attr(out$USUBJID, "label"), "Unique Subject Identifier")
  expect_equal(attr(out$USUBJID, "sas.length"), 40L)
  expect_equal(attr(out$USUBJID, "xpt_type"),   "text")
  expect_equal(attr(out$AGE, "label"),       "Age")
  expect_equal(attr(out$AGE, "format.sas"),  "8.")
  expect_equal(attr(out$AGE, "sas.length"),  8L)
  expect_equal(attr(out$AGE, "xpt_type"),    "integer")

  expect_equal(out$USUBJID, c("S1", "S2"))
  expect_equal(out$AGE,     c(65L, 72L))
})

test_that("write_parquet with dataset param round-trips dataset_name", {
  skip_if_not_installed("arrow")

  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  f  <- tempfile(fileext = ".parquet")
  on.exit(unlink(f))
  write_parquet(dm, f, dataset = "DM", label = "Demographics")
  out <- read_parquet(f)

  expect_equal(attr(out, "dataset_name"), "DM")
  expect_equal(attr(out, "label"),        "Demographics")
})

test_that("write_parquet infers dataset_name from file stem when no param", {
  skip_if_not_installed("arrow")

  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  f  <- tempfile(pattern = "ae", fileext = ".parquet")
  on.exit(unlink(f))
  write_parquet(dm, f)
  out <- read_parquet(f)

  expect_equal(attr(out, "dataset_name"), toupper(tools::file_path_sans_ext(basename(f))))
})

test_that("read_parquet errors when the file is missing", {
  skip_if_not_installed("arrow")
  expect_error(read_parquet("/definitely/not/here.parquet"))
})

# Note: a mocked-requireNamespace() test was considered for the "arrow not
# installed" path but the file.exists() check fires first in read_parquet()
# so it adds no real coverage. Left as documentation-only behaviour.

# -- xpt_to_parquet -----------------------------------------------------------

test_that("xpt_to_parquet() converts XPT to Parquet preserving attributes", {
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
  write_xpt(dm, xpt, dataset = "DM")

  result <- xpt_to_parquet(xpt, pq)
  expect_equal(result, pq)
  expect_true(file.exists(pq))

  out <- read_parquet(pq)
  expect_equal(out$USUBJID, dm$USUBJID)
  expect_equal(out$AGE,     dm$AGE)
  expect_equal(attr(out, "dataset_name"), "DM")
})

test_that("xpt_to_parquet() infers dataset name from XPT file name", {
  skip_if_not_installed("arrow")

  dm  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  xpt <- withr::local_tempfile(pattern = "dm", fileext = ".xpt")
  pq  <- withr::local_tempfile(fileext = ".parquet")
  write_xpt(dm, xpt, dataset = "DM")
  xpt_to_parquet(xpt, pq)
  out <- read_parquet(pq)
  expect_equal(attr(out, "dataset_name"), "DM")
})

test_that("xpt_to_parquet() errors on missing input file", {
  skip_if_not_installed("arrow")
  pq <- withr::local_tempfile(fileext = ".parquet")
  expect_error(xpt_to_parquet("/no/such.xpt", pq))
})

# -- json_to_parquet ----------------------------------------------------------

test_that("json_to_parquet() converts Dataset-JSON to Parquet preserving attributes", {
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

  result <- json_to_parquet(json, pq)
  expect_equal(result, pq)
  expect_true(file.exists(pq))

  out <- read_parquet(pq)
  expect_equal(out$USUBJID, dm$USUBJID)
  expect_equal(out$AGE,     dm$AGE)
  expect_equal(attr(out, "dataset_name"), "DM")
  expect_equal(attr(out, "label"),        "Demographics")
})

test_that("json_to_parquet() errors on missing input file", {
  skip_if_not_installed("arrow")
  pq <- withr::local_tempfile(fileext = ".parquet")
  expect_error(json_to_parquet("/no/such.json", pq))
})
