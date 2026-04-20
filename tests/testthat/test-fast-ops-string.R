# -----------------------------------------------------------------------------
# test-fast-ops-string.R  — string operator tests
# -----------------------------------------------------------------------------

test_that(".valid_iso8601_sdtm accepts full date+time", {
  good <- c(
    "2026-01-15",
    "2026-01-15T14:30",
    "2026-01-15T14:30:00",
    "2026-01-15T14:30:00.123",
    "2026-01-15T14:30:00Z",
    "2026-01-15T14:30:00+05:30"
  )
  expect_true(all(.valid_iso8601_sdtm(good)))
})

test_that(".valid_iso8601_sdtm accepts dash-substituted missing components", {
  partial <- c(
    "2026",                # year only
    "2026-01",             # year + month
    "2026----01",          # yyyy + unknown month + dd
    "----01-15",           # unknown year + month + dd
    "2026---",             # year + unknown month
    "T14:30",              # time only
    "2026-01-15T--:30"     # date + unknown hour + minute
  )
  expect_true(all(.valid_iso8601_sdtm(partial)))
})

test_that(".valid_iso8601_sdtm accepts all 6 SDTMIG §4.1.4 spec examples", {
  # Verbatim from SDTMIG Section 4.1.4 ISO 8601 examples table
  expect_true(.valid_iso8601_sdtm("2003-12-15T13:15:17"))   # full
  expect_true(.valid_iso8601_sdtm("2003-12-15T-:15"))       # unknown hour
  expect_true(.valid_iso8601_sdtm("2003-12-15T13:-:17"))    # unknown minute
  expect_true(.valid_iso8601_sdtm("2003---15"))             # unknown month
  expect_true(.valid_iso8601_sdtm("--12-15"))               # unknown year
  expect_true(.valid_iso8601_sdtm("-----T07:15"))           # unknown date
})

test_that(".valid_iso8601_sdtm rejects ill-formed strings", {
  bad <- c(
    "",                # empty
    "T",               # bare T
    "2026/01/15",      # slash separator
    "26-01-15",        # 2-digit year
    "2026-1-15",       # 1-digit month
    "2026-01-15 14:30", # space instead of T
    "not a date"
  )
  expect_false(any(.valid_iso8601_sdtm(bad)))
})

test_that("op_iso8601 treats NA / empty as pass with allow_missing=TRUE", {
  df <- data.frame(
    DTC = c(NA_character_, "", "2026-01-15", "not-a-date"),
    stringsAsFactors = FALSE
  )
  out <- op_iso8601(df, ctx = NULL, name = "DTC", allow_missing = TRUE)
  expect_equal(out, c(TRUE, TRUE, TRUE, FALSE))
})

test_that("op_iso8601 with allow_missing=FALSE fails NA / empty", {
  df <- data.frame(
    DTC = c(NA_character_, "", "2026-01-15"),
    stringsAsFactors = FALSE
  )
  out <- op_iso8601(df, ctx = NULL, name = "DTC", allow_missing = FALSE)
  expect_equal(out, c(FALSE, FALSE, TRUE))
})

test_that("op_iso8601 returns NA when column is absent", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  out <- op_iso8601(df, ctx = NULL, name = "AESTDTC")
  expect_equal(out, NA)
})

test_that("op_matches_regex works for fixed + pattern cases", {
  df <- data.frame(
    X = c("AE-001", "AE-002", "XX-003"),
    stringsAsFactors = FALSE
  )
  out <- op_matches_regex(df, ctx = NULL, name = "X",
                          value = "^AE-\\d{3}$")
  expect_equal(out, c(TRUE, TRUE, FALSE))
})

test_that("op_length_le respects byte width", {
  df <- data.frame(
    X = c("abc", "abcdefgh", "", NA_character_),
    stringsAsFactors = FALSE
  )
  out <- op_length_le(df, ctx = NULL, name = "X", value = 5)
  expect_equal(out, c(TRUE, FALSE, TRUE, TRUE))
})

test_that("op_contains substring match", {
  df <- data.frame(
    X = c("HEADACHE", "Headache", "MIGRAINE", NA_character_),
    stringsAsFactors = FALSE
  )
  out <- op_contains(df, ctx = NULL, name = "X", value = "HEAD")
  expect_equal(out, c(TRUE, FALSE, FALSE, FALSE))

  out_ci <- op_contains(df, ctx = NULL, name = "X", value = "head",
                        ignore_case = TRUE)
  expect_equal(out_ci, c(TRUE, TRUE, FALSE, FALSE))
})

test_that("string operators are all registered", {
  expect_true(all(c("iso8601", "matches_regex", "length_le", "contains")
                  %in% .list_ops()))
})
