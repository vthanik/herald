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
  expect_error(
    herald:::check_scalar_chr(c("a", "b")),
    class = "herald_error_input"
  )
})

# ---- check_scalar_int -------------------------------------------------------

test_that("check_scalar_int passes for a positive integer", {
  expect_no_error(herald:::check_scalar_int(5L))
})

test_that("check_scalar_int errors on zero", {
  expect_error(herald:::check_scalar_int(0L), class = "herald_error_input")
})

test_that("check_scalar_int errors on NA", {
  expect_error(
    herald:::check_scalar_int(NA_integer_),
    class = "herald_error_input"
  )
})

# ---- check_data_frame -------------------------------------------------------

test_that("check_data_frame passes for a data frame", {
  expect_no_error(herald:::check_data_frame(data.frame(x = 1)))
})

test_that("check_data_frame errors on non-data-frame", {
  expect_error(
    herald:::check_data_frame(list(x = 1)),
    class = "herald_error_input"
  )
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

# ---- herald_warning ---------------------------------------------------------

test_that("herald_warning signals herald_warning class", {
  expect_warning(
    herald:::herald_warning("Something iffy."),
    class = "herald_warning"
  )
})

test_that("herald_warning does not error when called", {
  expect_no_error(
    withCallingHandlers(
      herald:::herald_warning("Watch out."),
      warning = function(w) invokeRestart("muffleWarning")
    )
  )
})

# ---- herald_error_file: path metadata ---------------------------------------

test_that("herald_error_file stores path in condition", {
  err <- tryCatch(
    herald:::herald_error_file("File missing.", path = "/data/dm.xpt"),
    error = function(e) e
  )
  expect_s3_class(err, "herald_error_file")
  expect_equal(err$path, "/data/dm.xpt")
})

# ---- herald_error_spec: slot metadata ---------------------------------------

test_that("herald_error_spec stores slot in condition", {
  err <- tryCatch(
    herald:::herald_error_spec("Bad ds_spec.", slot = "ds_spec"),
    error = function(e) e
  )
  expect_s3_class(err, "herald_error_spec")
  expect_equal(err$slot, "ds_spec")
})

# ---- herald_error_rule: rule_id metadata ------------------------------------

test_that("herald_error_rule stores rule_id in condition", {
  err <- tryCatch(
    herald:::herald_error_rule("Bad rule.", rule_id = "ADaM-001"),
    error = function(e) e
  )
  expect_s3_class(err, "herald_error_rule")
  expect_equal(err$rule_id, "ADaM-001")
})

# ---- check_herald_spec -------------------------------------------------------

test_that("check_herald_spec passes for a herald_spec", {
  spec <- herald::as_herald_spec(
    ds_spec = data.frame(
      dataset = "DM",
      label = "Demo",
      stringsAsFactors = FALSE
    ),
    var_spec = data.frame(
      dataset = "DM",
      variable = "STUDYID",
      stringsAsFactors = FALSE
    )
  )
  expect_no_error(herald:::check_herald_spec(spec))
})

test_that("check_herald_spec errors on non-spec input", {
  expect_error(
    herald:::check_herald_spec(list(x = 1)),
    class = "herald_error_input"
  )
})

test_that("check_herald_spec errors on data frame input", {
  expect_error(
    herald:::check_herald_spec(data.frame(x = 1)),
    class = "herald_error_input"
  )
})

# ---- check_herald_validation -------------------------------------------------

test_that("check_herald_validation errors on non-validation input", {
  expect_error(
    herald:::check_herald_validation(list(x = 1)),
    class = "herald_error_input"
  )
})

test_that("check_herald_validation errors on NULL", {
  expect_error(
    herald:::check_herald_validation(NULL),
    class = "herald_error_input"
  )
})

# ---- check_scalar_int: additional edge cases --------------------------------

test_that("check_scalar_int errors on non-integer numeric (float)", {
  expect_error(herald:::check_scalar_int(1.5), class = "herald_error_input")
})

test_that("check_scalar_int errors on negative value", {
  expect_error(herald:::check_scalar_int(-3L), class = "herald_error_input")
})

test_that("check_scalar_int errors on length-2 vector", {
  expect_error(
    herald:::check_scalar_int(c(1L, 2L)),
    class = "herald_error_input"
  )
})

test_that("check_scalar_int errors on character input", {
  expect_error(
    herald:::check_scalar_int("1"),
    class = "herald_error_input"
  )
})

# ---- check_dir_exists -------------------------------------------------------

test_that("check_dir_exists passes for an existing directory", {
  tmp <- withr::local_tempdir()
  expect_no_error(herald:::check_dir_exists(tmp))
})

test_that("check_dir_exists errors for a nonexistent directory", {
  expect_error(
    herald:::check_dir_exists("/nonexistent/path/abc123"),
    class = "herald_error_file"
  )
})

test_that("check_dir_exists errors on non-string input", {
  expect_error(
    herald:::check_dir_exists(42L),
    class = "herald_error_input"
  )
})
