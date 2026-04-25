# Tests for R/ct-fetch.R -- available_ct_releases() + download_ct() parser.
# Network tests skip when unreachable; parser tests run offline against
# an NCI-EVS-shaped fixture.

test_that("available_ct_releases() returns bundled entries offline", {
  r <- available_ct_releases("sdtm", include_remote = FALSE)
  expect_s3_class(r, "tbl_df")
  expect_true("bundled" %in% r$source)
  expect_true("2026-03-27" %in% r$version)
})

test_that("available_ct_releases() merges bundled with cache entries", {
  # Populate a fake cache entry for adam (different version than bundled)
  dir <- tempfile("ct-cache-")
  dir.create(dir)
  stub_rds <- file.path(dir, "adam-ct-2024-06-21.rds")
  saveRDS(list(), stub_rds)
  herald:::.ct_cache_write(
    list(
      package = "adam",
      version = "2024-06-21",
      release_date = "2024-06-21",
      path = stub_rds,
      downloaded_at = "2024-06-21T00:00:00Z"
    ),
    dir = dir
  )
  withr::with_envvar(
    c(R_USER_CACHE_DIR = dir),
    {
      # R_USER_CACHE_DIR is honoured by tools::R_user_dir on modern R.
      r <- available_ct_releases("adam", include_remote = FALSE)
      expect_true("bundled" %in% r$source)
    }
  )
})

test_that(".parse_nci_evs_txt handles a minimal tab-delimited fixture", {
  txt <- paste(
    "Code\tCodelist Code\tCodelist Extensible (Yes/No)\tCodelist Name\tCDISC Submission Value\tCDISC Synonym(s)\tCDISC Definition\tNCI Preferred Term",
    # Header row: codelist NY (No Yes Response)
    "C66742\t\tNo\tNo Yes Response\tNY\t\tRepresentation of yes/no responses.\tNo Yes Response Terminology",
    # Two term rows linked to NY via Codelist Code == header's Code
    "C49488\tC66742\tNo\tNo Yes Response\tY\tYes\tAffirmative response.\tYes",
    "C49487\tC66742\tNo\tNo Yes Response\tN\tNo\tNegative response.\tNo",
    sep = "\n"
  )
  tmp <- tempfile(fileext = ".txt")
  writeLines(txt, tmp)
  ct <- herald:::.parse_nci_evs_txt(
    tmp,
    package = "sdtm",
    release_date = "2024-01-01",
    source_url = "https://example/NY.txt"
  )
  unlink(tmp)

  expect_true("NY" %in% names(ct))
  expect_equal(ct[["NY"]]$codelist_code, "C66742")
  expect_equal(ct[["NY"]]$codelist_name, "No Yes Response")
  expect_false(ct[["NY"]]$extensible)
  expect_setequal(ct[["NY"]]$terms$submissionValue, c("Y", "N"))
  expect_equal(attr(ct, "version"), "2024-01-01")
})

test_that(".parse_nci_evs_txt flags missing required columns", {
  tmp <- withr::local_tempfile(fileext = ".txt")
  writeLines("Foo\tBar\n1\t2", tmp)
  expect_error(
    herald:::.parse_nci_evs_txt(
      tmp,
      "sdtm",
      "2024-01-01",
      "https://example/none.txt"
    ),
    class = "herald_error_runtime"
  )
})

test_that("download_ct rejects malformed version strings", {
  expect_error(
    download_ct(
      "sdtm",
      version = "not-a-date",
      dest = tempfile("ct-dest-"),
      quiet = TRUE
    ),
    class = "herald_error_input"
  )
})

test_that("download_ct returns existing RDS without re-fetching (force=FALSE)", {
  dest <- withr::local_tempdir(pattern = "ct-dest-")
  # Pre-plant the expected output so the function short-circuits.
  rds <- file.path(dest, "sdtm-ct-2024-01-01.rds")
  saveRDS(list(), rds)
  path <- download_ct("sdtm", version = "2024-01-01", dest = dest, quiet = TRUE)
  expect_equal(normalizePath(path), normalizePath(rds))
})
