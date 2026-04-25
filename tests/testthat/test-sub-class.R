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
  expect_no_error(capture.output(print(s)))
})
