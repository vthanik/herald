# --------------------------------------------------------------------------
# test-sub-manifest.R -- file_sha256 + build_manifest
# --------------------------------------------------------------------------

# ---- file_sha256 -----------------------------------------------------------

test_that("file_sha256 returns NA for nonexistent file", {
  expect_equal(herald:::file_sha256("/nonexistent/path.xpt"),
               NA_character_)
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
