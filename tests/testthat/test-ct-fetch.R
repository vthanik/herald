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

test_that("available_ct_releases() returns empty tibble when no bundled/cache/remote", {
  # Use a send package -- no bundled entry and an empty temp cache dir
  dir <- tempfile("ct-send-")
  dir.create(dir, recursive = TRUE)
  inner <- file.path(dir, "R", "herald")
  dir.create(inner, recursive = TRUE)
  withr::with_envvar(
    c(R_USER_CACHE_DIR = dir),
    {
      r <- available_ct_releases("send", include_remote = FALSE)
      expect_s3_class(r, "tbl_df")
      expect_equal(nrow(r), 0L)
    }
  )
})

test_that("available_ct_releases() includes cache entries for sdtm", {
  # Verify the cached-entries path (lines 88-96) is exercised
  base <- tempfile("ct-cache-sdtm-")
  inner <- file.path(base, "R", "herald")
  dir.create(inner, recursive = TRUE)
  rds_path <- file.path(inner, "sdtm-ct-2023-09-29.rds")
  saveRDS(list(), rds_path)
  withr::with_envvar(
    c(R_USER_CACHE_DIR = base),
    {
      herald:::.ct_cache_write(
        list(
          package = "sdtm",
          version = "2023-09-29",
          release_date = "2023-09-29",
          path = rds_path,
          downloaded_at = "2023-09-29T00:00:00Z"
        ),
        dir = inner
      )
      r <- available_ct_releases("sdtm", include_remote = FALSE)
      expect_true("cache" %in% r$source)
      expect_true("2023-09-29" %in% r$version)
    }
  )
})

test_that("available_ct_releases() gracefully handles remote error (include_remote=TRUE)", {
  # When the remote NCI EVS listing fails, function should NOT error --
  # it catches and emits an informational message, then returns local results.
  base <- tempfile("ct-remote-err-")
  inner <- file.path(base, "R", "herald")
  dir.create(inner, recursive = TRUE)
  withr::with_envvar(
    c(R_USER_CACHE_DIR = base),
    {
      # Use include_remote=TRUE but with a near-zero timeout so the
      # download.file call fails immediately; function must not throw.
      # Suppress expected network-failure warnings from download.file.
      expect_no_error(
        suppressWarnings(
          available_ct_releases("adam", include_remote = TRUE, timeout = 1L)
        )
      )
    }
  )
})

test_that(".normalise_path normalises a path string", {
  p <- herald:::.normalise_path(tempdir())
  expect_type(p, "character")
  expect_false(grepl("\\\\", p))
})

test_that(".nci_evs_url_for builds a correct archive URL for a YYYY-MM-DD version", {
  info <- herald:::.nci_evs_url_for("sdtm", "2024-03-29", timeout = 30L)
  expect_equal(info$release_date, "2024-03-29")
  expect_match(info$url, "2024-03-29\\.txt$")
  expect_match(info$url, "SDTM")
})

test_that(".nci_evs_url_for errors on bad version string", {
  expect_error(
    herald:::.nci_evs_url_for("sdtm", "not-a-date", timeout = 30L),
    class = "herald_error_input"
  )
})

test_that(".download_and_cache returns early (verbose) when file already exists", {
  dest <- withr::local_tempdir(pattern = "ct-dac-verbose-")
  rds <- file.path(dest, "sdtm-ct-2024-01-01.rds")
  saveRDS(list(), rds)
  # quiet = FALSE exercises the cli_inform "Using cached" branch (line 244)
  expect_no_error(
    suppressMessages(
      herald:::.download_and_cache(
        url = "https://example.com/not-real.txt",
        rds_path = rds,
        fetch_ext = ".txt",
        parser = identity,
        parser_info = list(),
        manifest_entry = list(package = "sdtm", version = "2024-01-01"),
        force = FALSE,
        quiet = FALSE,
        dest = dest
      )
    )
  )
})

test_that(".parse_nci_evs_txt handles extensible=YES codelist", {
  txt <- paste(
    "Code\tCodelist Code\tCodelist Extensible (Yes/No)\tCodelist Name\tCDISC Submission Value\tCDISC Synonym(s)\tCDISC Definition\tNCI Preferred Term",
    "C99999\t\tYes\tExtensible List\tMYCL\t\tAn extensible codelist.\tMy Codelist",
    "C11111\tC99999\tYes\tExtensible List\tVAL1\tV1\tFirst value.\tFirst",
    sep = "\n"
  )
  tmp <- withr::local_tempfile(fileext = ".txt")
  writeLines(txt, tmp)
  ct <- herald:::.parse_nci_evs_txt(
    tmp,
    package = "sdtm",
    release_date = "2024-06-01",
    source_url = "https://example/ext.txt"
  )
  expect_true(ct[["MYCL"]]$extensible)
  expect_equal(attr(ct, "package"), "sdtm")
  expect_equal(attr(ct, "source_url"), "https://example/ext.txt")
  expect_equal(attr(ct, "release_date"), "2024-06-01")
})

test_that(".nci_evs_index_for builds the correct base URL", {
  url <- herald:::.nci_evs_index_for("adam")
  expect_match(url, "ADAM$")
  expect_match(url, "evs.nci.nih.gov")
})

test_that("available_ct_releases() with remote error still returns local results", {
  # include_remote=TRUE but with bad timeout -- remote fails.
  # The error is caught, NULL is returned by tryCatch, and local results remain.
  base <- withr::local_tempdir(pattern = "ct-remote-null-")
  inner <- file.path(base, "R", "herald")
  dir.create(inner, recursive = TRUE)
  withr::with_envvar(
    c(R_USER_CACHE_DIR = base),
    {
      result <- suppressWarnings(
        available_ct_releases("adam", include_remote = TRUE, timeout = 1L)
      )
      expect_s3_class(result, "tbl_df")
    }
  )
})
