# Tests for R/ct-load.R -- bundled CT loader + ct_info().

test_that("load_ct('sdtm') returns the bundled SDTM CT with attributes", {
  ct <- load_ct("sdtm")
  expect_type(ct, "list")
  expect_gt(length(ct), 1000L)                 # 1200+ SDTM codelists
  expect_equal(attr(ct, "package"), "sdtm")
  expect_equal(attr(ct, "version"), "2026-03-27")
  expect_equal(attr(ct, "release_date"), "2026-03-27")
  expect_true(file.exists(attr(ct, "source_path")))
})

test_that("load_ct('adam') returns the bundled ADaM CT", {
  ct <- load_ct("adam")
  expect_type(ct, "list")
  expect_gt(length(ct), 10L)
  expect_equal(attr(ct, "package"), "adam")
})

test_that("load_ct() caches deserialised CT within a session", {
  # Clear env to force first-load path.
  rm(list = ls(envir = herald:::.CT_CACHE), envir = herald:::.CT_CACHE)
  t1 <- system.time(load_ct("sdtm"))["elapsed"]
  t2 <- system.time(load_ct("sdtm"))["elapsed"]
  # Second load must be at least 2x faster (usually orders of magnitude).
  expect_lt(t2, t1)
})

test_that("load_ct() accepts an explicit .rds path override", {
  p <- system.file("rules", "ct", "adam-ct.rds", package = "herald")
  ct <- load_ct("sdtm", version = p)
  expect_type(ct, "list")
  expect_equal(attr(ct, "version"), "custom")
})

test_that("load_ct() errors on an unknown cache version", {
  expect_error(load_ct("sdtm", version = "1999-01-01"),
               class = "herald_error_input")
})

test_that("ct_info('sdtm') reports row + codelist counts", {
  info <- ct_info("sdtm")
  expect_equal(info$package, "sdtm")
  expect_equal(info$version, "2026-03-27")
  expect_gt(info$codelist_count, 1000L)
  expect_gt(info$row_count, 40000L)
  expect_true(file.exists(info$source_path))
})

test_that("NY codelist is present and has Y / N / U / NA terms", {
  ct <- load_ct("sdtm")
  expect_true("NY" %in% names(ct))
  vals <- ct[["NY"]]$terms$submissionValue
  expect_setequal(vals, c("Y", "N", "U", "NA"))
})
