# Tests for R/write-xpt.R — XPT writer

test_that("write_xpt creates a file", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = c(1, 2, 3))
  write_xpt(df, tmp)

  expect_true(file.exists(tmp))
  expect_gt(file.info(tmp)$size, 0L)
})

test_that("write_xpt output is a multiple of 80 bytes", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = c(1, 2, 3), Y = c("a", "b", "c"))
  write_xpt(df, tmp)

  size <- file.info(tmp)$size

  expect_equal(size %% 80L, 0L)
})

test_that("write_xpt handles numeric data", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(A = c(1.5, 0, -42.195))
  write_xpt(df, tmp)
  expect_true(file.exists(tmp))
})

test_that("write_xpt handles character data", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(
    NAME = c("Alice", "Bob", "Charlie"),
    stringsAsFactors = FALSE
  )
  write_xpt(df, tmp)
  expect_true(file.exists(tmp))
})

test_that("write_xpt handles mixed data", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(
    ID = c(1, 2, 3),
    NAME = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )
  write_xpt(df, tmp)
  expect_true(file.exists(tmp))
})

test_that("write_xpt handles NA values", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = c(1, NA, 3), Y = c("a", NA, "c"))
  write_xpt(df, tmp)
  expect_true(file.exists(tmp))
})

test_that("write_xpt handles zero-row data frame", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = numeric(0), Y = character(0))
  write_xpt(df, tmp)
  expect_true(file.exists(tmp))
  # Should still have headers
  expect_gt(file.info(tmp)$size, 0L)
})

test_that("write_xpt returns path invisibly", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = 1)
  result <- write_xpt(df, tmp)
  # write_xpt returns x invisibly (not the path)
  expect_true(is.data.frame(result))
  expect_true(file.exists(tmp))
})

test_that("write_xpt errors on factor columns", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = factor(c("a", "b")))
  expect_error(write_xpt(df, tmp), "factor")
})

test_that("write_xpt supports V8 format", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(LongVarName = c(1, 2))
  write_xpt(df, tmp, version = 8)
  expect_true(file.exists(tmp))
  size <- file.info(tmp)$size
  expect_equal(size %% 80L, 0L)
})

test_that("write_xpt rejects V5 with long names", {
  df <- data.frame(TOOLONGVAR = 1)
  expect_error(
    write_xpt(df, tempfile(), version = 5),
    "8.*characters"
  )
})

test_that("write_xpt derives dataset name from file path when dataset=NULL", {
  tmp <- file.path(tempdir(), "ae.xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = 1)
  write_xpt(df, tmp)
  expect_true(file.exists(tmp))

  raw_data <- readBin(tmp, "raw", file.info(tmp)$size)
  content <- rawToChar(raw_data[401:480])
  expect_true(grepl("AE", content, fixed = TRUE))
})

test_that("write_xpt uses dataset_name attribute when dataset=NULL", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = 1)
  attr(df, "dataset_name") <- "VS"
  write_xpt(df, tmp)
  expect_true(file.exists(tmp))

  raw_data <- readBin(tmp, "raw", file.info(tmp)$size)
  content <- rawToChar(raw_data[401:480])
  expect_true(grepl("VS", content, fixed = TRUE))
})

test_that("write_xpt handles custom name and label", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = 1)
  write_xpt(df, tmp, dataset = "MYDS", label = "My dataset")
  expect_true(file.exists(tmp))

  # Verify the name appears in the binary
  # Library header = 240 bytes, then member header starts
  # Record 3 of member header (bytes 401-480) contains the dataset name
  raw_data <- readBin(tmp, "raw", file.info(tmp)$size)
  content <- rawToChar(raw_data[401:480])
  expect_true(grepl("MYDS", content, fixed = TRUE))
})

test_that("write_xpt preserves column labels in namestr", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(AGE = c(25, 30))
  attr(df$AGE, "label") <- "Subject Age"
  write_xpt(df, tmp)

  # Label is in the namestr block (starts after 240 + 400 = 640 bytes)
  # Namestr label field is at offset 16 within each 140-byte namestr
  raw_data <- readBin(tmp, "raw", file.info(tmp)$size)
  # Read the namestr area — label is at bytes 641+16 to 641+55
  label_raw <- raw_data[657:696]
  label_str <- rawToChar(label_raw)
  expect_true(grepl("Subject Age", label_str, fixed = TRUE))
})

test_that("write_xpt handles multiple members (list input)", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  data_list <- list(
    DM = data.frame(ID = c(1, 2)),
    AE = data.frame(AETERM = c("Headache", "Nausea"))
  )
  write_xpt(data_list, tmp, version = 5)
  expect_true(file.exists(tmp))
  expect_equal(file.info(tmp)$size %% 80L, 0L)
})

test_that("write_xpt handles Date columns", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(DT = as.Date(c("2024-01-15", "2024-06-30")))
  write_xpt(df, tmp)
  expect_true(file.exists(tmp))
})

test_that("write_xpt handles POSIXct columns", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(
    DTM = as.POSIXct(
      c("2024-01-15 10:30:00", "2024-06-30 14:00:00"),
      tz = "UTC"
    )
  )
  write_xpt(df, tmp)
  expect_true(file.exists(tmp))
})

# -- From test-write-xpt-extra.R -------------------------------------------

# -- sort_keys attribute: sorting before write --------------------------------

test_that("write_xpt sorts by herald.sort_keys attribute", {
  df <- data.frame(
    STUDYID = c("S1", "S1", "S1"),
    USUBJID = c("S1-003", "S1-001", "S1-002"),
    stringsAsFactors = FALSE
  )
  attr(df, "herald.sort_keys") <- c("STUDYID", "USUBJID")

  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  write_xpt(df, tmp, dataset = "DM")
  result <- read_xpt(tmp)

  # After sorting, USUBJID should be in order
  expect_equal(result$USUBJID, c("S1-001", "S1-002", "S1-003"))
})

test_that("write_xpt with sort_keys that are not in data still writes", {
  df <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  attr(df, "herald.sort_keys") <- c("NONEXISTENT_KEY")

  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  expect_no_error(write_xpt(df, tmp, dataset = "DM"))
})

# -- Logical column conversion ------------------------------------------------

test_that("write_xpt converts logical columns to numeric", {
  df <- data.frame(
    FLAG = c(TRUE, FALSE, NA),
    stringsAsFactors = FALSE
  )

  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  write_xpt(df, tmp, dataset = "TEST")
  result <- read_xpt(tmp)

  # TRUE → 1, FALSE → 0, NA → NA
  expect_equal(result$FLAG[1L], 1)
  expect_equal(result$FLAG[2L], 0)
  expect_true(is.na(result$FLAG[3L]))
})

# -- difftime column conversion -----------------------------------------------

test_that("write_xpt converts difftime (time) columns to numeric seconds", {
  t1 <- as.difftime(3600, units = "secs") # 1 hour = 3600 secs
  df <- data.frame(TMVAL = t1, stringsAsFactors = FALSE)

  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  write_xpt(df, tmp, dataset = "TEST")
  result <- read_xpt(tmp)

  expect_equal(as.numeric(result$TMVAL[1L]), 3600, tolerance = 1e-6)
})

# -- dataset name resolution: fallback to "DATA" ------------------------------

test_that("write_xpt uses 'DATA' when file stem has only special chars", {
  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  # File with only special chars → empty after gsub → "DATA"
  tmp <- file.path(withr::local_tempdir(), "123-!@#.xpt")

  write_xpt(df, tmp)
  # Should not error
  expect_true(file.exists(tmp))
  result <- read_xpt(tmp)
  expect_equal(nrow(result), 1L)
})

# -- dataset_name attribute fallback ------------------------------------------

test_that("write_xpt uses dataset_name attribute when dataset=NULL", {
  df <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  attr(df, "dataset_name") <- "VS"

  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  write_xpt(df, tmp)
  result <- read_xpt(tmp)
  expect_equal(attr(result, "dataset_name"), "VS")
})

# -- write_xpt_multi: non-data.frame element errors --------------------------

test_that("write_xpt errors when list element is not a data frame", {
  dm <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  bad_list <- list(DM = dm, BAD = "not a data frame")

  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  expect_error(write_xpt(bad_list, tmp), "must be a data frame")
})

# -- write_xpt_multi: unnamed list gets auto-names ---------------------------

test_that("write_xpt with unnamed list assigns DATA1, DATA2 names", {
  dm <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  ae <- data.frame(AETERM = "H", stringsAsFactors = FALSE)

  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  # Unnamed list
  expect_no_error(write_xpt(list(dm, ae), tmp))
})

# -- V5 name truncation to 8 chars --------------------------------------------

test_that("write_xpt V5 truncates dataset name to 8 chars", {
  df <- data.frame(X = 1L, stringsAsFactors = FALSE)

  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  write_xpt(df, tmp, dataset = "TOOLONGNAME", version = 5L)
  result <- read_xpt(tmp)
  # Dataset name truncated to 8 chars
  expect_true(nchar(attr(result, "dataset_name")) <= 8L)
})

# -- V8 name truncation to 32 chars -------------------------------------------

test_that("write_xpt V8 truncates dataset name to 32 chars", {
  df <- data.frame(X = 1L, stringsAsFactors = FALSE)

  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  long_name <- paste(rep("A", 40L), collapse = "")
  write_xpt(df, tmp, dataset = long_name, version = 8L)
  result <- read_xpt(tmp)
  expect_true(nchar(attr(result, "dataset_name")) <= 32L)
})

# -- Label attribute on data frame --------------------------------------------

test_that("write_xpt uses label attribute when label=NULL", {
  df <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  attr(df, "label") <- "Demographics"

  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  expect_no_error(write_xpt(df, tmp, dataset = "DM"))
})

# -- Zero-row data frame with write_observations early return ----------------

test_that("write_xpt handles zero-row data frame without error", {
  df <- data.frame(STUDYID = character(0L), stringsAsFactors = FALSE)

  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  expect_no_error(write_xpt(df, tmp, dataset = "DM"))
  expect_true(file.exists(tmp))
})
