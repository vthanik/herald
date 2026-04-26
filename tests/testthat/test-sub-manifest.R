# --------------------------------------------------------------------------
# test-sub-manifest.R -- file_sha256 + build_manifest
# --------------------------------------------------------------------------

# ---- file_sha256 -----------------------------------------------------------

test_that("file_sha256 returns NA for nonexistent file", {
  expect_equal(herald:::file_sha256("/nonexistent/path.xpt"), NA_character_)
})

test_that("file_sha256 matches digest::digest", {
  skip_if_not_installed("digest")
  tmp <- withr::local_tempfile(fileext = ".txt")
  writeLines("hello herald", tmp)
  expect_equal(
    herald:::file_sha256(tmp),
    digest::digest(tmp, algo = "sha256", file = TRUE)
  )
})

test_that("file_sha256 returns a 64-character hex string", {
  skip_if_not_installed("digest")
  tmp <- withr::local_tempfile(fileext = ".bin")
  writeBin(as.raw(0:255), tmp)
  result <- herald:::file_sha256(tmp)
  expect_type(result, "character")
  expect_equal(nchar(result), 64L)
  expect_true(grepl("^[0-9a-f]{64}$", result))
})

# ---- build_manifest: basic structure ----------------------------------------

test_that("build_manifest returns a list with required fields", {
  skip_if_not_installed("digest")
  tmp_dir <- withr::local_tempdir()
  result <- herald:::build_manifest(tmp_dir)
  expect_type(result, "list")
  expect_true("herald_version" %in% names(result))
  expect_true("r_version" %in% names(result))
  expect_true("platform" %in% names(result))
  expect_true("timestamp" %in% names(result))
  expect_true("checksums_algorithm" %in% names(result))
  expect_equal(result$checksums_algorithm, "sha256")
})

test_that("build_manifest writes manifest.json to output_dir", {
  skip_if_not_installed("digest")
  skip_if_not_installed("jsonlite")
  tmp_dir <- withr::local_tempdir()
  herald:::build_manifest(tmp_dir)
  expect_true(file.exists(file.path(tmp_dir, "manifest.json")))
})

test_that("build_manifest includes dataset checksums for XPT files", {
  skip_if_not_installed("digest")
  tmp_dir <- withr::local_tempdir()
  # Write a dummy xpt file
  writeLines("dummy xpt content", file.path(tmp_dir, "dm.xpt"))
  result <- herald:::build_manifest(tmp_dir)
  expect_true("datasets" %in% names(result))
  ds_names <- vapply(result$datasets, function(d) d$name, character(1L))
  expect_true("DM" %in% ds_names)
})

test_that("build_manifest includes row/col counts when datasets provided", {
  skip_if_not_installed("digest")
  tmp_dir <- withr::local_tempdir()
  writeLines("dummy", file.path(tmp_dir, "dm.xpt"))
  dm <- data.frame(USUBJID = letters[1:5], AGE = 20:24)
  result <- herald:::build_manifest(tmp_dir, datasets = list(DM = dm))
  dm_entry <- result$datasets[[which(
    vapply(result$datasets, function(d) d$name, character(1L)) == "DM"
  )]]
  expect_equal(dm_entry$rows, 5L)
  expect_equal(dm_entry$columns, 2L)
})

test_that("build_manifest includes define_xml entry when define_path provided", {
  skip_if_not_installed("digest")
  tmp_dir <- withr::local_tempdir()
  define_path <- file.path(tmp_dir, "define.xml")
  writeLines("<ODM/>", define_path)
  result <- herald:::build_manifest(tmp_dir, define_path = define_path)
  expect_true("define_xml" %in% names(result))
  expect_equal(result$define_xml$file, "define.xml")
  expect_true(nchar(result$define_xml$sha256) == 64L)
})

test_that("build_manifest skips define_xml when file does not exist", {
  skip_if_not_installed("digest")
  tmp_dir <- withr::local_tempdir()
  result <- herald:::build_manifest(
    tmp_dir,
    define_path = "/nonexistent/define.xml"
  )
  expect_false("define_xml" %in% names(result))
})

test_that("build_manifest includes validation summary when validation provided", {
  skip_if_not_installed("digest")
  tmp_dir <- withr::local_tempdir()
  fake_validation <- list(
    summary = list(errors = 2L, warnings = 5L, notes = 1L, total = 8L)
  )
  class(fake_validation) <- "herald_validation"
  result <- herald:::build_manifest(tmp_dir, validation = fake_validation)
  expect_true("validation" %in% names(result))
  expect_equal(result$validation$errors, 2L)
  expect_equal(result$validation$warnings, 5L)
  expect_equal(result$validation$notes, 1L)
  expect_equal(result$validation$total, 8L)
})

test_that("build_manifest includes report entries for existing report files", {
  skip_if_not_installed("digest")
  tmp_dir <- withr::local_tempdir()
  report_path <- file.path(tmp_dir, "report.html")
  writeLines("<html/>", report_path)
  result <- herald:::build_manifest(tmp_dir, report_paths = report_path)
  expect_true("reports" %in% names(result))
  expect_equal(length(result$reports), 1L)
  expect_equal(result$reports[[1L]]$format, "html")
  expect_equal(result$reports[[1L]]$file, "report.html")
})

test_that("build_manifest skips nonexistent report paths", {
  skip_if_not_installed("digest")
  tmp_dir <- withr::local_tempdir()
  result <- herald:::build_manifest(
    tmp_dir,
    report_paths = "/nonexistent/report.html"
  )
  # reports key present but empty after filtering NULLs
  if ("reports" %in% names(result)) {
    expect_equal(length(result$reports), 0L)
  } else {
    succeed()
  }
})

test_that("build_manifest works with no files at all in empty dir", {
  skip_if_not_installed("digest")
  tmp_dir <- withr::local_tempdir()
  result <- herald:::build_manifest(tmp_dir)
  expect_type(result, "list")
  expect_equal(length(result$datasets), 0L)
})
