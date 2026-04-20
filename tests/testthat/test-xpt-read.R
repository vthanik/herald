# Tests for R/read-xpt.R — XPT reader (round-trip with write_xpt)

test_that("read_xpt preserves dataset_name attribute", {
  tmp <- file.path(tempdir(), "dm_attr.xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = 1L)
  write_xpt(df, tmp, dataset = "DM")
  result <- read_xpt(tmp)
  expect_equal(attr(result, "dataset_name"), "DM")
})

test_that("read_xpt round-trips numeric data", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = c(1, 2.5, 0, -100))
  write_xpt(df, tmp)
  result <- read_xpt(tmp)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 4L)
  expect_equal(ncol(result), 1L)
  expect_equal(names(result), "X")
  expect_equal(result$X, df$X, tolerance = 1e-10)
})

test_that("read_xpt round-trips character data", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(NAME = c("Alice", "Bob", "C"), stringsAsFactors = FALSE)
  write_xpt(df, tmp)
  result <- read_xpt(tmp)

  expect_equal(nrow(result), 3L)
  expect_equal(result$NAME, df$NAME)
})

test_that("read_xpt round-trips mixed data", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(
    ID = c(1, 2, 3),
    NAME = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )
  write_xpt(df, tmp)
  result <- read_xpt(tmp)

  expect_equal(nrow(result), 3L)
  expect_equal(ncol(result), 2L)
  expect_equal(result$ID, df$ID, tolerance = 1e-10)
  expect_equal(result$NAME, df$NAME)
})

test_that("read_xpt handles numeric NA as SAS missing", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = c(1, NA, 3))
  write_xpt(df, tmp)
  result <- read_xpt(tmp)

  expect_equal(result$X[1], 1, tolerance = 1e-10)
  expect_true(is.na(result$X[2]))
  expect_equal(result$X[3], 3, tolerance = 1e-10)
})

test_that("read_xpt converts character blanks to NA", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(Y = c("a", NA, "c"), stringsAsFactors = FALSE)
  write_xpt(df, tmp)
  result <- read_xpt(tmp)

  expect_equal(result$Y[1], "a")
  expect_true(is.na(result$Y[2]))
  expect_equal(result$Y[3], "c")
})

test_that("read_xpt preserves column labels", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(AGE = c(25, 30))
  attr(df$AGE, "label") <- "Subject Age"
  write_xpt(df, tmp)
  result <- read_xpt(tmp)

  expect_equal(attr(result$AGE, "label"), "Subject Age")
})

test_that("read_xpt handles zero-row data frame", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = numeric(0), Y = character(0))
  write_xpt(df, tmp)
  result <- read_xpt(tmp)

  expect_equal(nrow(result), 0L)
  expect_equal(names(result), c("X", "Y"))
})

test_that("read_xpt supports col_select", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(A = 1:3, B = c("x", "y", "z"), C = 4:6)
  write_xpt(df, tmp)
  result <- read_xpt(tmp, col_select = c("A", "C"))

  expect_equal(ncol(result), 2L)
  expect_equal(names(result), c("A", "C"))
})

test_that("read_xpt supports n_max", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = seq_len(10))
  write_xpt(df, tmp)
  result <- read_xpt(tmp, n_max = 3)

  expect_equal(nrow(result), 3L)
  expect_equal(result$X, c(1, 2, 3), tolerance = 1e-10)
})

test_that("read_xpt errors on non-existent file", {
  expect_error(read_xpt("/no/such/file.xpt"), "does not exist")
})

test_that("read_xpt round-trips V8 format", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(LongVarName = c(1, 2, 3))
  write_xpt(df, tmp, version = 8)
  result <- read_xpt(tmp)

  expect_equal(nrow(result), 3L)
  expect_equal(names(result), "LongVarName")
  expect_equal(result$LongVarName, c(1, 2, 3), tolerance = 1e-10)
})

test_that("read_xpt V5 uppercases column names", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(age = c(25, 30))
  write_xpt(df, tmp, version = 5)
  result <- read_xpt(tmp)

  expect_equal(names(result), "AGE")
})

test_that("read_xpt round-trips typical clinical data", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(
    SUBJID = c(1001, 1002, 1003),
    SEX = c("M", "F", "M"),
    AGE = c(65, 42, 78),
    WEIGHT = c(80.5, 62.3, 91.0),
    stringsAsFactors = FALSE
  )
  attr(df$SUBJID, "label") <- "Subject ID"
  attr(df$SEX, "label") <- "Sex"
  attr(df$AGE, "label") <- "Age in Years"
  attr(df$WEIGHT, "label") <- "Body Weight (kg)"

  write_xpt(df, tmp)
  result <- read_xpt(tmp)

  expect_equal(nrow(result), 3L)
  expect_equal(result$SUBJID, df$SUBJID, tolerance = 1e-10)
  expect_equal(result$SEX, df$SEX)
  expect_equal(result$AGE, df$AGE, tolerance = 1e-10)
  expect_equal(result$WEIGHT, df$WEIGHT, tolerance = 1e-6)
  expect_equal(attr(result$SUBJID, "label"), "Subject ID")
  expect_equal(attr(result$AGE, "label"), "Age in Years")
})

test_that("read_xpt handles multiple members", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  data_list <- list(
    DM = data.frame(ID = c(1, 2)),
    AE = data.frame(TERM = c("Headache", "Nausea"), stringsAsFactors = FALSE)
  )
  write_xpt(data_list, tmp, version = 5)
  result <- read_xpt(tmp)

  expect_type(result, "list")
  expect_length(result, 2L)
  expect_true("DM" %in% names(result))
  expect_true("AE" %in% names(result))
  expect_equal(nrow(result$DM), 2L)
  expect_equal(nrow(result$AE), 2L)
})

test_that("read_xpt preserves dataset label", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = 1)
  write_xpt(df, tmp, label = "My Dataset")
  result <- read_xpt(tmp)

  expect_equal(attr(result, "label"), "My Dataset")
})

# ---- Encoding tests ----

test_that("read_xpt emits message for non-UTF-8 bytes when encoding = NULL", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  # Write a file with a non-UTF-8 byte (0x92 = right single quote in Windows-1252)
  df <- data.frame(X = 1, Y = "test")
  write_xpt(df, tmp)

  # Manually patch the character data to contain a non-UTF-8 byte
  raw_data <- readBin(tmp, "raw", file.info(tmp)$size)
  test_bytes <- charToRaw("test")
  for (i in seq_len(length(raw_data) - 3L)) {
    if (identical(raw_data[i:(i + 3L)], test_bytes)) {
      raw_data[i] <- as.raw(0x92)
      break
    }
  }
  writeBin(raw_data, tmp)

  # With encoding = NULL (no conversion), should emit message
  expect_message(
    result <- read_xpt(tmp, encoding = NULL),
    "Non-UTF-8 bytes detected"
  )
})

test_that("read_xpt default encoding handles non-ASCII without message", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  # Write a file then patch in a Windows-1252 byte

  df <- data.frame(X = 1, Y = "test")
  write_xpt(df, tmp)

  raw_data <- readBin(tmp, "raw", file.info(tmp)$size)
  test_bytes <- charToRaw("test")
  for (i in seq_len(length(raw_data) - 3L)) {
    if (identical(raw_data[i:(i + 3L)], test_bytes)) {
      raw_data[i] <- as.raw(0x92)
      break
    }
  }
  writeBin(raw_data, tmp)

  # Default encoding = "WINDOWS-1252" should convert silently
  expect_no_message(result <- read_xpt(tmp))
  expect_true(validUTF8(result$Y[1]))
})

test_that("read_xpt converts encoding when encoding is specified", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  # Write a file, then patch in a Latin-1 byte

  df <- data.frame(X = 1, Y = "Alzheimer_s")
  write_xpt(df, tmp)

  # Patch the underscore (0x5F) with Windows-1252 right single quote (0x92)
  raw_data <- readBin(tmp, "raw", file.info(tmp)$size)
  underscore <- charToRaw("_")
  for (i in seq_len(length(raw_data))) {
    if (raw_data[i] == underscore) {
      raw_data[i] <- as.raw(0x92)
      break
    }
  }
  writeBin(raw_data, tmp)

  # With encoding specified, should convert to UTF-8
  result <- read_xpt(tmp, encoding = "WINDOWS-1252")
  expect_true(validUTF8(result$Y[1]))
  # The right single quote in UTF-8 is U+2019
  expect_true(grepl("\u2019", result$Y[1]))
})

test_that("read_xpt with encoding = NULL passes bytes through (like haven)", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = 1, Y = "hello")
  write_xpt(df, tmp)

  # No encoding conversion — just read as-is
  suppressMessages(result <- read_xpt(tmp, encoding = NULL))
  expect_equal(result$Y, "hello")
})

test_that("write_xpt encoding converts UTF-8 to target encoding", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  # Write UTF-8 data with encoding conversion to latin1
  df <- data.frame(X = 1, Y = "caf\u00e9")
  write_xpt(df, tmp, encoding = "latin1")

  # Read back with matching encoding — should round-trip
  result <- read_xpt(tmp, encoding = "latin1")
  expect_equal(result$Y, "caf\u00e9")
})

test_that("read_xpt/write_xpt round-trip with default wlatin1 encoding", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  # UTF-8 right single quote → WLATIN1 byte 0x92 → back to UTF-8
  df <- data.frame(X = 1, Y = "Alzheimer\u2019s Disease")
  write_xpt(df, tmp)
  result <- read_xpt(tmp)

  expect_equal(result$Y, "Alzheimer\u2019s Disease")
})

test_that("read_xpt accepts SAS encoding names", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(X = 1, Y = "hello")
  write_xpt(df, tmp)

  # All these should work without error
  expect_equal(read_xpt(tmp, encoding = "wlatin1")$Y, "hello")
  expect_equal(read_xpt(tmp, encoding = "wlt1")$Y, "hello")
  expect_equal(read_xpt(tmp, encoding = "utf-8")$Y, "hello")
  expect_equal(read_xpt(tmp, encoding = "ascii")$Y, "hello")
})

# -- From test-xpt-v8-roundtrip.R -----------------------------------------

# Writing a V8 XPT and reading it back exercises the LABELV8 label extension
# path in parse_label_extension().

test_that("V8 XPT roundtrip preserves data values", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(
    STUDYID = c("S1", "S1"),
    USUBJID = c("S1-001", "S1-002"),
    AGE = c(25L, 40L),
    stringsAsFactors = FALSE
  )
  write_xpt(df, tmp, dataset = "DM", version = 8)
  result <- read_xpt(tmp)
  expect_equal(result$STUDYID, c("S1", "S1"))
  expect_equal(result$USUBJID, c("S1-001", "S1-002"))
})

test_that("V8 XPT roundtrip preserves variable labels", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(AGE = c(25L, 40L), stringsAsFactors = FALSE)
  attr(df$AGE, "label") <- "Age in Years"
  write_xpt(df, tmp, dataset = "DM", version = 8)
  result <- read_xpt(tmp)
  expect_equal(attr(result$AGE, "label"), "Age in Years")
})

test_that("V8 XPT roundtrip preserves long variable names (>8 chars)", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(LONGVARNAME = c("X", "Y"), stringsAsFactors = FALSE)
  write_xpt(df, tmp, dataset = "DM", version = 8)
  result <- read_xpt(tmp)
  expect_true("LONGVARNAME" %in% names(result))
})

test_that("V8 XPT roundtrip works with a numeric column", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(VALUE = c(1.1, 2.2, 3.3), stringsAsFactors = FALSE)
  write_xpt(df, tmp, dataset = "LB", version = 8)
  result <- read_xpt(tmp)
  expect_equal(result$VALUE, c(1.1, 2.2, 3.3), tolerance = 1e-6)
})

test_that("V8 XPT roundtrip for 0-row data frame works", {
  tmp <- tempfile(fileext = ".xpt")
  on.exit(unlink(tmp))

  df <- data.frame(
    STUDYID = character(0),
    AGE = integer(0),
    stringsAsFactors = FALSE
  )
  write_xpt(df, tmp, dataset = "DM", version = 8)
  result <- read_xpt(tmp)
  expect_equal(nrow(result), 0L)
  expect_true("STUDYID" %in% names(result))
})
