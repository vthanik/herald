# Tests for R/xpt-encoding.R -- resolve_encoding, SAS format helpers,
# date/time converters, convert_preserving_attrs.
# Also contains tests for R/ieee-ibm.R (IEEE 754 <-> IBM 370).

# --------------------------------------------------------------------------
# resolve_encoding
# --------------------------------------------------------------------------

test_that("resolve_encoding maps known SAS names to iconv names", {
  expect_equal(herald:::resolve_encoding("WLATIN1"), "WINDOWS-1252")
  expect_equal(herald:::resolve_encoding("wlatin1"), "WINDOWS-1252")
  expect_equal(herald:::resolve_encoding("UTF-8"), "UTF-8")
  expect_equal(herald:::resolve_encoding("utf8"), "UTF-8")
  expect_equal(herald:::resolve_encoding("latin1"), "ISO-8859-1")
  expect_equal(herald:::resolve_encoding("ANSI"), "US-ASCII")
})

test_that("resolve_encoding returns input unchanged for unknown names", {
  expect_equal(herald:::resolve_encoding("unknown123"), "unknown123")
  expect_equal(herald:::resolve_encoding("MYMADEUP"), "MYMADEUP")
})

test_that("resolve_encoding returns NULL for NULL input", {
  expect_null(herald:::resolve_encoding(NULL))
})

# --------------------------------------------------------------------------
# is_sas_date_format / is_sas_datetime_format / is_sas_time_format
# --------------------------------------------------------------------------

test_that("is_sas_date_format recognises date formats (case-insensitive)", {
  # The format list stores base names without width digits -- callers
  # are expected to pass the extracted format name, not the raw string.
  expect_true(herald:::is_sas_date_format("DATE"))
  expect_true(herald:::is_sas_date_format("date"))
  expect_true(herald:::is_sas_date_format("YYMMDD"))
  expect_false(herald:::is_sas_date_format("DATETIME"))
  expect_false(herald:::is_sas_date_format("TIME"))
  expect_false(herald:::is_sas_date_format("BEST"))
})

test_that("is_sas_datetime_format recognises datetime formats", {
  expect_true(herald:::is_sas_datetime_format("DATETIME"))
  expect_true(herald:::is_sas_datetime_format("datetime"))
  expect_true(herald:::is_sas_datetime_format("B8601DT"))
  expect_false(herald:::is_sas_datetime_format("DATE"))
  expect_false(herald:::is_sas_datetime_format("TIME"))
})

test_that("is_sas_time_format recognises time formats", {
  expect_true(herald:::is_sas_time_format("TIME"))
  expect_true(herald:::is_sas_time_format("time"))
  expect_true(herald:::is_sas_time_format("HHMM"))
  expect_false(herald:::is_sas_time_format("DATE"))
  expect_false(herald:::is_sas_time_format("DATETIME"))
})

# --------------------------------------------------------------------------
# extract_format_name
# --------------------------------------------------------------------------

test_that("extract_format_name strips width/decimal from SAS format strings", {
  expect_equal(herald:::extract_format_name("DATE9."), "DATE")
  # Trailing digits + decimal stripped; BEST12.2 -> "BEST" (all trailing digits removed)
  expect_equal(herald:::extract_format_name("BEST12.2"), "BEST")
  expect_equal(herald:::extract_format_name("DATETIME20."), "DATETIME")
  expect_equal(herald:::extract_format_name("E8601DT26.6"), "E8601DT")
})

test_that("extract_format_name returns empty string for empty input", {
  expect_equal(herald:::extract_format_name(""), "")
})

# --------------------------------------------------------------------------
# sas_date_to_r / sas_datetime_to_r / sas_time_to_r
# --------------------------------------------------------------------------

test_that("sas_date_to_r converts SAS day 0 to 1960-01-01", {
  expect_equal(herald:::sas_date_to_r(0), as.Date("1960-01-01"))
})

test_that("sas_date_to_r converts NA to NA Date", {
  result <- herald:::sas_date_to_r(NA_real_)
  expect_true(is.na(result))
  expect_s3_class(result, "Date")
})

test_that("sas_date_to_r converts a positive day value correctly", {
  # 1 day after SAS epoch = 1960-01-02
  expect_equal(herald:::sas_date_to_r(1), as.Date("1960-01-02"))
  # 366 days = 1961-01-01 (1960 is a leap year)
  expect_equal(herald:::sas_date_to_r(366), as.Date("1961-01-01"))
})

test_that("sas_datetime_to_r converts SAS second 0 to 1960-01-01 UTC", {
  result <- herald:::sas_datetime_to_r(0)
  expect_s3_class(result, "POSIXct")
  expect_equal(format(result, "%Y-%m-%d %H:%M:%S", tz = "UTC"), "1960-01-01 00:00:00")
})

test_that("sas_datetime_to_r converts NA to NA POSIXct", {
  result <- herald:::sas_datetime_to_r(NA_real_)
  expect_true(is.na(result))
  expect_s3_class(result, "POSIXct")
})

test_that("sas_time_to_r converts seconds to difftime", {
  result <- herald:::sas_time_to_r(3600)
  expect_s3_class(result, "difftime")
  expect_equal(as.numeric(result, units = "secs"), 3600)
})

test_that("sas_time_to_r converts 0 seconds correctly", {
  result <- herald:::sas_time_to_r(0)
  expect_equal(as.numeric(result, units = "secs"), 0)
})

# --------------------------------------------------------------------------
# convert_preserving_attrs
# --------------------------------------------------------------------------

test_that("convert_preserving_attrs preserves label attribute", {
  df <- data.frame(x = c(0, 1, 366), stringsAsFactors = FALSE)
  attr(df$x, "label") <- "Study Day"
  df2 <- herald:::convert_preserving_attrs(df, "x", herald:::sas_date_to_r)
  expect_equal(attr(df2$x, "label"), "Study Day")
  expect_s3_class(df2$x, "Date")
})

test_that("convert_preserving_attrs preserves format.sas attribute", {
  df <- data.frame(x = 0, stringsAsFactors = FALSE)
  attr(df$x, "format.sas") <- "DATE9"
  df2 <- herald:::convert_preserving_attrs(df, "x", herald:::sas_date_to_r)
  expect_equal(attr(df2$x, "format.sas"), "DATE9")
})

test_that("convert_preserving_attrs preserves informat.sas attribute", {
  df <- data.frame(x = 0, stringsAsFactors = FALSE)
  attr(df$x, "informat.sas") <- "DATE9"
  df2 <- herald:::convert_preserving_attrs(df, "x", herald:::sas_date_to_r)
  expect_equal(attr(df2$x, "informat.sas"), "DATE9")
})

test_that("convert_preserving_attrs works when no attrs are set", {
  df <- data.frame(x = 0, stringsAsFactors = FALSE)
  df2 <- herald:::convert_preserving_attrs(df, "x", herald:::sas_date_to_r)
  expect_s3_class(df2$x, "Date")
  expect_null(attr(df2$x, "label"))
})

# --------------------------------------------------------------------------
# Tests for R/ieee-ibm.R  --  IEEE 754 <-> IBM 370 float conversion

# Known IBM 370 representations:
# 1.0  = 0x41 0x10 0x00 0x00 0x00 0x00 0x00 0x00
# -1.0 = 0xC1 0x10 0x00 0x00 0x00 0x00 0x00 0x00
# 0.0  = 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
# SAS missing (.) = 0x2E 0x00 0x00 0x00 0x00 0x00 0x00 0x00

# --- ieee_to_ibm tests ---

test_that("ieee_to_ibm converts zero correctly", {
  result <- ieee_to_ibm(0)
  expect_equal(result, raw(8L))
})

test_that("ieee_to_ibm converts 1.0 correctly", {
  result <- ieee_to_ibm(1)
  expect_equal(
    result,
    as.raw(c(0x41, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  )
})

test_that("ieee_to_ibm converts -1.0 correctly", {
  result <- ieee_to_ibm(-1)
  expect_equal(
    result,
    as.raw(c(0xC1, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  )
})

test_that("ieee_to_ibm converts NA to SAS missing", {
  result <- ieee_to_ibm(NA_real_)
  expect_equal(
    result,
    as.raw(c(0x2E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  )
})

test_that("ieee_to_ibm converts NaN to SAS missing", {
  result <- ieee_to_ibm(NaN)
  expect_equal(
    result,
    as.raw(c(0x2E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  )
})

test_that("ieee_to_ibm converts Inf to SAS missing", {
  result <- ieee_to_ibm(Inf)
  expect_equal(
    result,
    as.raw(c(0x2E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  )
})

test_that("ieee_to_ibm converts -Inf to SAS missing", {
  result <- ieee_to_ibm(-Inf)
  expect_equal(
    result,
    as.raw(c(0x2E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  )
})

test_that("ieee_to_ibm handles empty input", {
  result <- ieee_to_ibm(numeric(0L))
  expect_equal(result, raw(0L))
})

test_that("ieee_to_ibm is vectorised", {
  result <- ieee_to_ibm(c(1, 0, NA))
  expect_equal(length(result), 24L)

  # Check each 8-byte segment
  expect_equal(
    result[1:8],
    as.raw(c(0x41, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  )
  expect_equal(result[9:16], raw(8L))
  expect_equal(
    result[17:24],
    as.raw(c(0x2E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  )
})

# --- ibm_to_ieee tests ---

test_that("ibm_to_ieee converts zero correctly", {
  result <- ibm_to_ieee(raw(8L))
  expect_equal(result, 0)
})

test_that("ibm_to_ieee converts 1.0 correctly", {
  ibm_raw <- as.raw(c(0x41, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  result <- ibm_to_ieee(ibm_raw)
  expect_equal(result, 1)
})

test_that("ibm_to_ieee converts -1.0 correctly", {
  ibm_raw <- as.raw(c(0xC1, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  result <- ibm_to_ieee(ibm_raw)
  expect_equal(result, -1)
})

test_that("ibm_to_ieee converts SAS missing to NA", {
  missing_raw <- as.raw(c(0x2E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  result <- ibm_to_ieee(missing_raw)
  expect_true(is.na(result))
})

test_that("ibm_to_ieee converts SAS .A missing to NA", {
  raw_a <- as.raw(c(0x41, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  result <- ibm_to_ieee(raw_a)
  expect_true(is.na(result))
})

test_that("ibm_to_ieee handles empty input", {
  result <- ibm_to_ieee(raw(0L))
  expect_equal(result, numeric(0L))
})

# --- Round-trip tests ---

test_that("round-trip preserves common values", {
  values <- c(0, 1, -1, 100, -100, 0.5, 0.25, 0.125)
  for (val in values) {
    ibm_raw <- ieee_to_ibm(val)
    back <- ibm_to_ieee(ibm_raw)
    expect_equal(
      back,
      val,
      tolerance = 1e-10,
      label = paste("round-trip for", val)
    )
  }
})

test_that("round-trip preserves NA", {
  ibm_raw <- ieee_to_ibm(NA_real_)
  back <- ibm_to_ieee(ibm_raw)
  expect_true(is.na(back))
})

test_that("round-trip preserves typical clinical values", {
  # Typical values seen in clinical trial data
  values <- c(65.5, 120.7, 0.001, 99.99, 1234.5678, 0.1)
  for (val in values) {
    ibm_raw <- ieee_to_ibm(val)
    back <- ibm_to_ieee(ibm_raw)
    # IBM 370 has ~7 decimal digits of precision
    expect_equal(
      back,
      val,
      tolerance = 1e-6,
      label = paste("round-trip for", val)
    )
  }
})

test_that("round-trip for large values", {
  val <- 1e10
  ibm_raw <- ieee_to_ibm(val)
  back <- ibm_to_ieee(ibm_raw)
  expect_equal(back, val, tolerance = val * 1e-10)
})

test_that("round-trip for small positive values", {
  val <- 1e-10
  ibm_raw <- ieee_to_ibm(val)
  back <- ibm_to_ieee(ibm_raw)
  expect_equal(back, val, tolerance = 1e-14)
})

test_that("round-trip for negative values", {
  val <- -42.195
  ibm_raw <- ieee_to_ibm(val)
  back <- ibm_to_ieee(ibm_raw)
  expect_equal(back, val, tolerance = 1e-6)
})
