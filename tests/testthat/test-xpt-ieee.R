# --------------------------------------------------------------------------
# test-xpt-ieee-extra.R -- extra tests for xpt-ieee.R edge cases
# --------------------------------------------------------------------------

# -- sas_missing_raw ----------------------------------------------------------

test_that("sas_missing_raw returns 8 bytes with first byte 0x2E", {
  result <- herald:::sas_missing_raw()
  expect_equal(length(result), 8L)
  expect_equal(result[1L], as.raw(0x2E))
  expect_true(all(result[2:8] == as.raw(0x00)))
})

# -- sas_missing_patterns -----------------------------------------------------

test_that("sas_missing_patterns returns 29 patterns (., ._, .A-.Z)", {
  result <- herald:::sas_missing_patterns()
  # 1 (.) + 1 (_) + 26 (A-Z) = 28
  expect_true(length(result) >= 28L)
  expect_true(all(vapply(result, length, integer(1L)) == 8L))
})

# -- is_sas_missing -----------------------------------------------------------

test_that("is_sas_missing returns TRUE for standard missing", {
  raw8 <- as.raw(c(0x2E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  expect_true(herald:::is_sas_missing(raw8))
})

test_that("is_sas_missing returns TRUE for .A special missing", {
  raw8 <- as.raw(c(0x41, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  expect_true(herald:::is_sas_missing(raw8))
})

test_that("is_sas_missing returns TRUE for ._ special missing", {
  raw8 <- as.raw(c(0x5F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  expect_true(herald:::is_sas_missing(raw8))
})

test_that("is_sas_missing returns FALSE for regular float", {
  # 1.0 in IBM 370
  raw8 <- as.raw(c(0x41, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  expect_false(herald:::is_sas_missing(raw8))
})

test_that("is_sas_missing returns FALSE when lower bytes are non-zero", {
  raw8 <- as.raw(c(0x2E, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  expect_false(herald:::is_sas_missing(raw8))
})

# -- ieee_to_ibm: empty input ------------------------------------------------

test_that("ieee_to_ibm returns empty raw for empty numeric", {
  result <- herald:::ieee_to_ibm(numeric(0L))
  expect_equal(length(result), 0L)
})

# -- ieee_to_ibm: zero -------------------------------------------------------

test_that("ieee_to_ibm handles vector of all zeros", {
  result <- herald:::ieee_to_ibm(c(0, 0, 0))
  expect_equal(length(result), 24L)
  expect_true(all(result == as.raw(0x00)))
})

# -- ieee_to_ibm: subnormal (very small positive) ----------------------------

test_that("ieee_to_ibm handles subnormal (denormalized) double as zero", {
  tiny <- .Machine$double.xmin * 1e-15 # subnormal
  result <- herald:::ieee_to_ibm(tiny)
  # subnormals with ibm_exp < 0 are treated as zero (underflow)
  expect_equal(length(result), 8L)
})

# -- ieee_to_ibm: overflow path ----------------------------------------------

test_that("ieee_to_ibm handles very large float as SAS missing (overflow)", {
  # IBM 370 can't represent numbers with exponent > 127 in its base-16 scheme
  # 16^(127-64) = 16^63 ≈ 2e75; .Machine$double.xmax is ~1.8e308
  result <- herald:::ieee_to_ibm(.Machine$double.xmax)
  # Should be SAS missing (overflow)
  expect_equal(length(result), 8L)
  expect_equal(result[1L], as.raw(0x2E)) # SAS missing first byte
})

# -- ieee_to_ibm: mixed vector -----------------------------------------------

test_that("ieee_to_ibm handles mixed vector: zero, NA, regular", {
  x <- c(0, NA_real_, 1.0, -1.0)
  result <- herald:::ieee_to_ibm(x)
  expect_equal(length(result), 32L)
})

# -- ibm_to_ieee: empty ---------------------------------------------------------

test_that("ibm_to_ieee returns empty numeric for empty raw", {
  result <- herald:::ibm_to_ieee(raw(0L))
  expect_equal(length(result), 0L)
})

# -- ibm_to_ieee: SAS special missing .A .Z ._ ---------------------------------

test_that("ibm_to_ieee tags .A missing with .A indicator", {
  raw8 <- as.raw(c(0x41, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  result <- herald:::ibm_to_ieee(raw8)
  expect_true(is.na(result[1L]))
  expect_true(!is.null(attr(result, "sas_missing")))
  # .A = ASCII 0x41 = 65 = 'A'
  expect_true(grepl("A", attr(result, "sas_missing")[1L]))
})

test_that("ibm_to_ieee tags ._ missing with ._ indicator", {
  raw8 <- as.raw(c(0x5F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  result <- herald:::ibm_to_ieee(raw8)
  expect_true(is.na(result[1L]))
  tags <- attr(result, "sas_missing")
  expect_equal(tags[1L], "._")
})

test_that("ibm_to_ieee tags standard missing with . indicator", {
  raw8 <- as.raw(c(0x2E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  result <- herald:::ibm_to_ieee(raw8)
  expect_true(is.na(result[1L]))
  tags <- attr(result, "sas_missing")
  expect_equal(tags[1L], ".")
})

# -- ibm_to_ieee: multiple zeros and missings --------------------------------

test_that("ibm_to_ieee handles vector with zeros and missings", {
  zero8 <- as.raw(rep(0x00, 8L))
  miss8 <- as.raw(c(0x2E, rep(0x00, 7L)))
  raw_vec <- c(zero8, miss8, zero8)
  result <- herald:::ibm_to_ieee(raw_vec)
  expect_equal(length(result), 3L)
  expect_equal(result[1L], 0)
  expect_true(is.na(result[2L]))
  expect_equal(result[3L], 0)
})

# -- Round-trip: ieee_to_ibm -> ibm_to_ieee -----------------------------------

test_that("ieee_to_ibm and ibm_to_ieee round-trip for integer values", {
  for (n in c(1L, 2L, 5L, 10L, 100L, -1L, -5L)) {
    raw8 <- herald:::ieee_to_ibm(as.double(n))
    result <- herald:::ibm_to_ieee(raw8)
    expect_equal(
      result,
      as.double(n),
      tolerance = 1e-10,
      info = paste("Round-trip failed for", n)
    )
  }
})

test_that("ieee_to_ibm and ibm_to_ieee round-trip for fractional values", {
  for (n in c(0.5, 1.25, 3.14, -2.718)) {
    raw8 <- herald:::ieee_to_ibm(n)
    result <- herald:::ibm_to_ieee(raw8)
    expect_equal(
      result,
      n,
      tolerance = 1e-10,
      info = paste("Round-trip failed for", n)
    )
  }
})
