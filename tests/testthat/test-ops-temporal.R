# Tests for R/ops-temporal.R

test_that("is_complete_date / is_incomplete_date", {
  d <- data.frame(
    DTC = c(
      "2026-01-15",
      "2026-01-15T14:30",
      "2026---15",
      "--12-15",
      "2024",
      "",
      NA_character_
    ),
    stringsAsFactors = FALSE
  )
  comp <- op_is_complete_date(d, NULL, "DTC")
  expect_equal(comp, c(TRUE, TRUE, FALSE, FALSE, FALSE, NA, NA))
  incomp <- op_is_incomplete_date(d, NULL, "DTC")
  expect_equal(incomp, c(FALSE, FALSE, TRUE, TRUE, TRUE, NA, NA))
})

test_that("invalid_date", {
  d <- data.frame(
    DTC = c("2024-01-15", "not-a-date", "2024/01/15", "", NA_character_),
    stringsAsFactors = FALSE
  )
  expect_equal(op_invalid_date(d, NULL, "DTC"), c(FALSE, TRUE, TRUE, NA, NA))
})

test_that("invalid_duration", {
  d <- data.frame(
    X = c("P2Y", "P2Y3M", "PT30M", "2 years", "", NA_character_),
    stringsAsFactors = FALSE
  )
  expect_equal(
    op_invalid_duration(d, NULL, "X"),
    c(FALSE, FALSE, FALSE, TRUE, NA, NA)
  )
})

test_that("date_greater_than vs literal", {
  d <- data.frame(
    DTC = c("2024-01-15", "2023-06-01", "2024-12-31", "not-a-date"),
    stringsAsFactors = FALSE
  )
  out <- op_date_greater_than(d, NULL, "DTC", "2024-01-01")
  expect_equal(out, c(TRUE, FALSE, TRUE, NA))
})

test_that("date_greater_than column-vs-column", {
  d <- data.frame(
    AESTDTC = c("2024-03-10", "2024-05-01", "2024-01-15"),
    EXSTDTC = c("2024-01-01", "2024-06-01", "2024-01-01"),
    stringsAsFactors = FALSE
  )
  out <- op_date_greater_than(d, NULL, "AESTDTC", "EXSTDTC")
  expect_equal(out, c(TRUE, FALSE, TRUE))
})

test_that("date_less_than_or_equal_to behaves", {
  d <- data.frame(
    A = c("2024-01-01", "2024-06-01", "2024-12-31"),
    stringsAsFactors = FALSE
  )
  out <- op_date_less_than_or_equal_to(d, NULL, "A", "2024-06-01")
  expect_equal(out, c(TRUE, TRUE, FALSE))
})

test_that("op_value_not_iso8601 kind=date delegates to op_invalid_date", {
  d <- data.frame(
    TSVAL = c("2026-01-15", "not-a-date", "", NA_character_),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_value_not_iso8601(d, NULL, "TSVAL", kind = "date")
  expect_equal(out, c(FALSE, TRUE, NA, NA))
})

test_that("op_value_not_iso8601 kind=duration delegates to op_invalid_duration", {
  d <- data.frame(
    TDSTOFF = c("P1Y", "P2Y3M", "NOT-DUR", "", NA_character_),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_value_not_iso8601(d, NULL, "TDSTOFF", kind = "duration")
  expect_equal(out, c(FALSE, FALSE, TRUE, NA, NA))
})

test_that("op_value_not_iso8601 default kind is date", {
  d <- data.frame(X = c("2026-01-15", "bad"), stringsAsFactors = FALSE)
  expect_equal(
    herald:::op_value_not_iso8601(d, NULL, "X"),
    herald:::op_invalid_date(d, NULL, "X")
  )
})

test_that("op_value_not_iso8601 returns NA on absent column", {
  d <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  expect_equal(
    herald:::op_value_not_iso8601(d, NULL, "TSVAL", kind = "date"),
    NA
  )
})

test_that("op_value_not_iso8601 is registered", {
  expect_true("value_not_iso8601" %in% herald:::.list_ops())
})

# ---- null column branches ----------------------------------------------------

test_that("op_is_complete_date returns all-NA for absent column", {
  d <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  result <- herald:::op_is_complete_date(d, NULL, "DTC")
  expect_equal(result, c(NA, NA))
})

test_that("op_invalid_date returns all-NA for absent column", {
  d <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  result <- herald:::op_invalid_date(d, NULL, "DTC")
  expect_equal(result, c(NA, NA))
})

test_that("op_invalid_duration returns all-NA for absent column", {
  d <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  result <- herald:::op_invalid_duration(d, NULL, "DUR")
  expect_equal(result, c(NA, NA))
})

# ---- .parse_sdtm_dt out-of-range bounds --------------------------------------

test_that(".parse_sdtm_dt returns NA for out-of-range month", {
  result <- herald:::.parse_sdtm_dt("2024-13-01")
  expect_true(is.na(result))
})

test_that(".parse_sdtm_dt returns NA for out-of-range day", {
  result <- herald:::.parse_sdtm_dt("2024-01-32")
  expect_true(is.na(result))
})

test_that(".parse_sdtm_dt returns NA for out-of-range hour", {
  result <- herald:::.parse_sdtm_dt("2024-01-15T25:00:00")
  expect_true(is.na(result))
})

test_that(".parse_sdtm_dt returns NA for out-of-range minute", {
  result <- herald:::.parse_sdtm_dt("2024-01-15T12:61:00")
  expect_true(is.na(result))
})

test_that(".parse_sdtm_dt returns NA for out-of-range second (>60)", {
  result <- herald:::.parse_sdtm_dt("2024-01-15T12:00:61")
  expect_true(is.na(result))
})

test_that(".parse_sdtm_dt returns NA for non-matching string", {
  result <- herald:::.parse_sdtm_dt("not-a-date-at-all")
  expect_true(is.na(result))
})

test_that(".parse_sdtm_dt returns NA for empty string", {
  result <- herald:::.parse_sdtm_dt("")
  expect_true(is.na(result))
})

test_that(".parse_sdtm_dt returns NA for NA input", {
  result <- herald:::.parse_sdtm_dt(NA_character_)
  expect_true(is.na(result))
})

test_that(".parse_sdtm_dt parses year-only to year floor", {
  result <- herald:::.parse_sdtm_dt("2024")
  expect_false(is.na(result))
  expect_equal(format(result, "%Y-%m-%d", tz = "UTC"), "2024-01-01")
})

test_that(".parse_sdtm_dt parses YYYY-MM to month floor", {
  result <- herald:::.parse_sdtm_dt("2024-06")
  expect_false(is.na(result))
  expect_equal(format(result, "%Y-%m-%d", tz = "UTC"), "2024-06-01")
})

# ---- .date_cmp multi-element value path --------------------------------------

test_that(".date_cmp with multi-element value returns all NA", {
  d <- data.frame(
    DTC = c("2024-01-15", "2024-06-01"),
    stringsAsFactors = FALSE
  )
  result <- herald:::op_date_greater_than(d, NULL, "DTC", c("2024-01-01", "2024-05-01"))
  expect_equal(result, c(NA, NA))
})

# ---- date_cmp null column ----------------------------------------------------

test_that("op_date_greater_than returns all NA for absent column", {
  d <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  result <- herald:::op_date_greater_than(d, NULL, "DTC", "2024-01-01")
  expect_equal(result, c(NA, NA))
})

# ---- remaining date comparison ops -------------------------------------------

test_that("op_date_equal_to matches exact date", {
  d <- data.frame(
    A = c("2024-06-01", "2024-06-02", "2024-06-01"),
    stringsAsFactors = FALSE
  )
  result <- herald:::op_date_equal_to(d, NULL, "A", "2024-06-01")
  expect_equal(result, c(TRUE, FALSE, TRUE))
})

test_that("op_date_not_equal_to inverts equality", {
  d <- data.frame(
    A = c("2024-06-01", "2024-06-02", NA_character_),
    stringsAsFactors = FALSE
  )
  result <- herald:::op_date_not_equal_to(d, NULL, "A", "2024-06-01")
  expect_equal(result, c(FALSE, TRUE, NA))
})

test_that("op_date_greater_than_or_equal_to covers boundary", {
  d <- data.frame(
    A = c("2024-06-01", "2024-06-02", "2024-05-31"),
    stringsAsFactors = FALSE
  )
  result <- herald:::op_date_greater_than_or_equal_to(d, NULL, "A", "2024-06-01")
  expect_equal(result, c(TRUE, TRUE, FALSE))
})

test_that("op_date_less_than fires correctly", {
  d <- data.frame(
    A = c("2024-05-31", "2024-06-01", "2024-06-02"),
    stringsAsFactors = FALSE
  )
  result <- herald:::op_date_less_than(d, NULL, "A", "2024-06-01")
  expect_equal(result, c(TRUE, FALSE, FALSE))
})

test_that("op_date_equal_to returns NA when lhs is not parseable", {
  d <- data.frame(
    A = c("not-a-date", "2024-06-01"),
    stringsAsFactors = FALSE
  )
  result <- herald:::op_date_equal_to(d, NULL, "A", "2024-06-01")
  expect_equal(result, c(NA, TRUE))
})
