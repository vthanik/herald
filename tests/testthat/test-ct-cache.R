# Tests for R/ct-cache.R -- internal cache helpers.

test_that(".ct_cache_dir(create = FALSE) returns path without creating it", {
  # Call with create = FALSE -- must return the path string without
  # creating the directory (directory creation is not tested here).
  p <- herald:::.ct_cache_dir(create = FALSE)
  expect_type(p, "character")
  expect_true(nzchar(p))
})

test_that(".ct_cache_read returns empty list when dir does not exist", {
  missing_dir <- file.path(tempdir(), paste0("no-such-dir-", Sys.getpid()))
  result <- herald:::.ct_cache_read(dir = missing_dir)
  expect_identical(result, list())
})

test_that(".ct_cache_read returns empty list when manifest is malformed JSON", {
  d <- withr::local_tempdir(pattern = "ct-bad-json-")
  bad <- file.path(d, "cache-manifest.json")
  writeLines("{ this is not valid json ~~~", bad)
  result <- herald:::.ct_cache_read(dir = d)
  expect_identical(result, list())
})

test_that(".ct_cache_write errors on missing package field", {
  d <- withr::local_tempdir(pattern = "ct-write-err-")
  expect_error(
    herald:::.ct_cache_write(list(version = "2024-01-01"), dir = d),
    class = "herald_error_runtime"
  )
})

test_that(".ct_cache_write errors on missing version field", {
  d <- withr::local_tempdir(pattern = "ct-write-err2-")
  expect_error(
    herald:::.ct_cache_write(list(package = "sdtm"), dir = d),
    class = "herald_error_runtime"
  )
})

test_that(".ct_cache_write errors on non-list entry", {
  d <- withr::local_tempdir(pattern = "ct-write-err3-")
  expect_error(
    herald:::.ct_cache_write("not-a-list", dir = d),
    class = "herald_error_runtime"
  )
})

test_that(".cache_path composes the canonical cache file name", {
  d <- withr::local_tempdir(pattern = "ct-path-")
  p <- herald:::.cache_path("sdtm", "2024-03-29", dir = d)
  expect_equal(basename(p), "sdtm-ct-2024-03-29.rds")
  expect_equal(dirname(p), d)
})

test_that(".ct_cache_write and .ct_cache_read round-trip an entry", {
  d <- withr::local_tempdir(pattern = "ct-roundtrip-")
  entry <- list(
    package = "sdtm",
    version = "2024-06-28",
    release_date = "2024-06-28",
    path = "/tmp/sdtm-ct-2024-06-28.rds",
    downloaded_at = "2024-06-28T00:00:00Z"
  )
  herald:::.ct_cache_write(entry, dir = d)
  m <- herald:::.ct_cache_read(dir = d)
  expect_true("sdtm@2024-06-28" %in% names(m))
  expect_equal(m[["sdtm@2024-06-28"]]$version, "2024-06-28")
})

test_that(".ct_cache_read returns empty list when manifest file is absent", {
  d <- withr::local_tempdir(pattern = "ct-no-manifest-")
  # Directory exists but no manifest file inside
  result <- herald:::.ct_cache_read(dir = d)
  expect_identical(result, list())
})
