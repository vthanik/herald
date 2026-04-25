# --------------------------------------------------------------------------
# test-herald-conditions.R -- herald_error_* constructors
# --------------------------------------------------------------------------

# ---- herald_error_file -----------------------------------------------------

test_that("herald_error_file signals herald_error_file class", {
  expect_error(
    herald:::herald_error_file("File not found."),
    class = "herald_error_file"
  )
})

test_that("herald_error_file inherits herald_error", {
  expect_error(
    herald:::herald_error_file("x"),
    class = "herald_error"
  )
})

# ---- herald_error_spec ------------------------------------------------------

test_that("herald_error_spec signals herald_error_spec class", {
  expect_error(
    herald:::herald_error_spec("Bad spec."),
    class = "herald_error_spec"
  )
})

# ---- herald_error_xpt -------------------------------------------------------

test_that("herald_error_xpt signals herald_error_xpt class", {
  expect_error(
    herald:::herald_error_xpt("Bad XPT."),
    class = "herald_error_xpt"
  )
})

# ---- herald_error_rule ------------------------------------------------------

test_that("herald_error_rule signals herald_error_rule class", {
  expect_error(
    herald:::herald_error_rule("Bad rule."),
    class = "herald_error_rule"
  )
})

# ---- herald_error_validation ------------------------------------------------

test_that("herald_error_validation signals herald_error_validation class", {
  expect_error(
    herald:::herald_error_validation("Validation failed."),
    class = "herald_error_validation"
  )
})

# ---- herald_error_define ----------------------------------------------------

test_that("herald_error_define signals herald_error_define class", {
  expect_error(
    herald:::herald_error_define("Bad define."),
    class = "herald_error_define"
  )
})

# ---- herald_error_io --------------------------------------------------------

test_that("herald_error_io signals herald_error_io class", {
  expect_error(
    herald:::herald_error_io("I/O failed."),
    class = "herald_error_io"
  )
})

test_that("herald_error_io accepts path metadata", {
  err <- tryCatch(
    herald:::herald_error_io("I/O failed.", path = "/tmp/x.json"),
    error = function(e) e
  )
  expect_equal(err$path, "/tmp/x.json")
})

# ---- herald_error_runtime ---------------------------------------------------

test_that("herald_error_runtime signals herald_error_runtime class", {
  expect_error(
    herald:::herald_error_runtime("Internal error."),
    class = "herald_error_runtime"
  )
})

# ---- herald_error_report ----------------------------------------------------

test_that("herald_error_report signals herald_error_report class", {
  expect_error(
    herald:::herald_error_report("Report failed."),
    class = "herald_error_report"
  )
})

# ---- herald_error_missing_pkg -----------------------------------------------

test_that("herald_error_missing_pkg signals class and includes pkg name", {
  err <- tryCatch(
    herald:::herald_error_missing_pkg("nonexistentpkg999", "for testing"),
    error = function(e) e
  )
  expect_s3_class(err, "herald_error_missing_pkg")
  expect_equal(err$pkg, "nonexistentpkg999")
})

# ---- require_pkg ------------------------------------------------------------

test_that("require_pkg aborts when package is absent", {
  expect_error(
    herald:::require_pkg("nonexistentpkg999", "for testing"),
    class = "herald_error_missing_pkg"
  )
})

test_that("require_pkg is silent when package is present", {
  expect_no_error(herald:::require_pkg("stats", "for testing"))
})

# ---- check_scalar_chr -------------------------------------------------------

test_that("check_scalar_chr passes for a string", {
  expect_no_error(herald:::check_scalar_chr("hello"))
})

test_that("check_scalar_chr errors on non-string", {
  expect_error(herald:::check_scalar_chr(1L), class = "herald_error_input")
})

test_that("check_scalar_chr errors on length-2 character", {
  expect_error(herald:::check_scalar_chr(c("a", "b")), class = "herald_error_input")
})

# ---- check_scalar_int -------------------------------------------------------

test_that("check_scalar_int passes for a positive integer", {
  expect_no_error(herald:::check_scalar_int(5L))
})

test_that("check_scalar_int errors on zero", {
  expect_error(herald:::check_scalar_int(0L), class = "herald_error_input")
})

test_that("check_scalar_int errors on NA", {
  expect_error(herald:::check_scalar_int(NA_integer_), class = "herald_error_input")
})

# ---- check_data_frame -------------------------------------------------------

test_that("check_data_frame passes for a data frame", {
  expect_no_error(herald:::check_data_frame(data.frame(x = 1)))
})

test_that("check_data_frame errors on non-data-frame", {
  expect_error(herald:::check_data_frame(list(x = 1)), class = "herald_error_input")
})

# ---- check_file_exists ------------------------------------------------------

test_that("check_file_exists passes for an existing file", {
  tmp <- withr::local_tempfile()
  writeLines("x", tmp)
  expect_no_error(herald:::check_file_exists(tmp))
})

test_that("check_file_exists errors for missing file", {
  expect_error(
    herald:::check_file_exists("/nonexistent/path.xpt"),
    class = "herald_error_file"
  )
})
