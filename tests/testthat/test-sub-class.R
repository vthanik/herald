# --------------------------------------------------------------------------
# test-sub-class.R -- herald_submission S7 class + S3 dispatch
# --------------------------------------------------------------------------

mk_sub <- function() {
  new_herald_submission(
    output_dir = "/tmp",
    xpt_files = c("/tmp/dm.xpt", "/tmp/ae.xpt"),
    json_files = c("/tmp/dm.json"),
    define_path = "/tmp/define.xml",
    report_paths = c("/tmp/report.html", "/tmp/report.xlsx")
  )
}

# ---- $ derived views -------------------------------------------------------

test_that("$ returns derived xpt_files", {
  s <- mk_sub()
  expect_equal(s$xpt_files, c("/tmp/dm.xpt", "/tmp/ae.xpt"))
})

test_that("$ returns derived json_files", {
  s <- mk_sub()
  expect_equal(s$json_files, c("/tmp/dm.json"))
})

test_that("$ returns derived define_path", {
  s <- mk_sub()
  expect_equal(s$define_path, "/tmp/define.xml")
})

test_that("$ returns NULL define_path when absent", {
  s <- new_herald_submission(output_dir = "/tmp")
  expect_null(s$define_path)
})

test_that("$ returns derived report_paths", {
  s <- mk_sub()
  expect_equal(s$report_paths, c("/tmp/report.html", "/tmp/report.xlsx"))
})

test_that("$ returns raw S7 prop for output_dir", {
  s <- mk_sub()
  expect_equal(s$output_dir, "/tmp")
})

# ---- [[ dispatch does not recurse ------------------------------------------

test_that("[[ delegates to $ without recursing", {
  s <- mk_sub()
  expect_equal(s[["xpt_files"]], s$xpt_files)
  expect_equal(s[["output_dir"]], s$output_dir)
})

# ---- print does not error --------------------------------------------------

test_that("print.herald_submission runs without error", {
  s <- mk_sub()
  expect_no_error(print(s))
})

test_that("print.herald_submission snapshot", {
  s <- mk_sub()
  expect_snapshot(print(s))
})

# ---- print with validation --------------------------------------------------

test_that("print.herald_submission shows validation counts snapshot", {
  # Build a fake herald_validation-like object
  fake_val <- structure(
    list(
      summary = list(reject = 1L, high = 2L, medium = 3L, notes = 0L)
    ),
    class = "herald_validation"
  )
  s <- new_herald_submission(
    output_dir = "/tmp",
    xpt_files = c("/tmp/dm.xpt"),
    validation = fake_val
  )
  expect_no_error(print(s))
  expect_snapshot(print(s))
})

# ---- print with manifest ----------------------------------------------------

test_that("print.herald_submission shows manifest included when non-empty", {
  s <- new_herald_submission(
    output_dir = "/tmp",
    manifest = list(herald_version = "1.0.0")
  )
  expect_no_error(print(s))
  expect_snapshot(print(s))
})

# ---- new_herald_submission with json/define/report types -------------------

test_that("new_herald_submission assigns correct types for report extensions", {
  s <- new_herald_submission(
    output_dir = "/tmp",
    report_paths = c("/tmp/r.html", "/tmp/r.xlsx", "/tmp/r.csv", "/tmp/r.json", "/tmp/r.pdf")
  )
  types <- s@files$type
  expect_true("report-html" %in% types)
  expect_true("report-xlsx" %in% types)
  expect_true("report-csv" %in% types)
  expect_true("report-json" %in% types)
  expect_true("pdf" %in% types)  # fallback: uses raw extension
})

test_that("new_herald_submission produces empty files df when no inputs", {
  s <- new_herald_submission(output_dir = "/tmp")
  expect_equal(nrow(s@files), 0L)
  expect_named(s@files, c("path", "type", "size"))
})

# ---- $<- assignment ---------------------------------------------------------

test_that("$<- updates an S7 property on herald_submission", {
  s <- mk_sub()
  s$output_dir <- "/new/dir"
  expect_equal(s$output_dir, "/new/dir")
})
