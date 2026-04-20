# Tests for R/ieee-ibm.R — IEEE 754 <-> IBM 370 float conversion

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
