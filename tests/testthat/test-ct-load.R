# Tests for R/ct-load.R -- bundled CT loader + ct_info().

test_that("load_ct('sdtm') returns the bundled SDTM CT with attributes", {
  ct <- load_ct("sdtm")
  expect_type(ct, "list")
  expect_gt(length(ct), 1000L) # 1200+ SDTM codelists
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
  expect_error(
    load_ct("sdtm", version = "1999-01-01"),
    class = "herald_error_input"
  )
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

# ---------- .resolve_ct_source -- explicit .rds path (missing file) ----------

test_that(".resolve_ct_source errors when an explicit .rds path does not exist", {
  missing <- file.path(tempdir(), "does-not-exist-ct.rds")
  expect_error(
    load_ct("sdtm", version = missing),
    class = "herald_error_input"
  )
})

# ---------- .resolve_ct_source -- latest-cache branch ----------

test_that("load_ct('latest-cache') errors when cache is empty", {
  base <- withr::local_tempdir(pattern = "ct-empty-cache-")
  inner <- file.path(base, "R", "herald")
  dir.create(inner, recursive = TRUE)
  withr::with_envvar(
    c(R_USER_CACHE_DIR = base),
    {
      expect_error(
        load_ct("sdtm", version = "latest-cache"),
        class = "herald_error_input"
      )
    }
  )
})

test_that("load_ct('latest-cache') resolves the most recent cached release", {
  base <- withr::local_tempdir(pattern = "ct-latest-cache-")
  inner <- file.path(base, "R", "herald")
  dir.create(inner, recursive = TRUE)
  rds_path <- file.path(inner, "sdtm-ct-2024-09-27.rds")
  fake_ct <- list(
    NY = list(
      codelist_code = "C66742",
      codelist_name = "No Yes Response",
      extensible = FALSE,
      terms = data.frame(
        submissionValue = c("Y", "N"),
        conceptId = c("C49488", "C49487"),
        preferredTerm = c("Yes", "No"),
        stringsAsFactors = FALSE
      )
    )
  )
  attr(fake_ct, "package") <- "sdtm"
  attr(fake_ct, "version") <- "2024-09-27"
  attr(fake_ct, "release_date") <- "2024-09-27"
  attr(fake_ct, "source_url") <- NA_character_
  saveRDS(fake_ct, rds_path)
  herald:::.ct_cache_write(
    list(
      package = "sdtm",
      version = "2024-09-27",
      release_date = "2024-09-27",
      path = rds_path,
      downloaded_at = "2024-09-27T00:00:00Z"
    ),
    dir = inner
  )
  withr::with_envvar(
    c(R_USER_CACHE_DIR = base),
    {
      rm(list = ls(envir = herald:::.CT_CACHE), envir = herald:::.CT_CACHE)
      ct <- load_ct("sdtm", version = "latest-cache")
      expect_type(ct, "list")
      expect_equal(attr(ct, "version"), "2024-09-27")
    }
  )
})

# ---------- .resolve_ct_source -- specific YYYY-MM-DD cache lookup ----------

test_that("load_ct(version = 'YYYY-MM-DD') loads a specific cached release", {
  base <- withr::local_tempdir(pattern = "ct-specific-ver-")
  inner <- file.path(base, "R", "herald")
  dir.create(inner, recursive = TRUE)
  rds_path <- file.path(inner, "adam-ct-2023-12-22.rds")
  fake_ct <- list(
    DTYPE = list(
      codelist_code = "C81226",
      codelist_name = "Derived Type",
      extensible = FALSE,
      terms = data.frame(
        submissionValue = "LOCF",
        conceptId = "C81223",
        preferredTerm = "Last Observation Carried Forward",
        stringsAsFactors = FALSE
      )
    )
  )
  attr(fake_ct, "package") <- "adam"
  attr(fake_ct, "version") <- "2023-12-22"
  attr(fake_ct, "release_date") <- "2023-12-22"
  attr(fake_ct, "source_url") <- NA_character_
  saveRDS(fake_ct, rds_path)
  herald:::.ct_cache_write(
    list(
      package = "adam",
      version = "2023-12-22",
      release_date = "2023-12-22",
      path = rds_path,
      downloaded_at = "2023-12-22T00:00:00Z"
    ),
    dir = inner
  )
  withr::with_envvar(
    c(R_USER_CACHE_DIR = base),
    {
      rm(list = ls(envir = herald:::.CT_CACHE), envir = herald:::.CT_CACHE)
      ct <- load_ct("adam", version = "2023-12-22")
      expect_type(ct, "list")
      expect_equal(attr(ct, "version"), "2023-12-22")
    }
  )
})

# ---------- .bundled_ct_manifest cache hit ----------

test_that(".bundled_ct_manifest returns cached result on second call", {
  rm(list = ls(envir = herald:::.CT_CACHE), envir = herald:::.CT_CACHE)
  m1 <- herald:::.bundled_ct_manifest()
  # Second call must use the .CT_CACHE$manifest shortcut
  m2 <- herald:::.bundled_ct_manifest()
  expect_identical(m1, m2)
  expect_false(is.null(herald:::.CT_CACHE$manifest))
})
