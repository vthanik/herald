# -----------------------------------------------------------------------------
# test-fast-ops-temporal-cross.R — temporal + cross-dataset operators
# -----------------------------------------------------------------------------

test_that("is_complete_date / is_incomplete_date", {
  d <- data.frame(
    DTC = c("2026-01-15", "2026-01-15T14:30",
            "2026---15", "--12-15", "2024", "", NA_character_),
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
  expect_equal(op_invalid_date(d, NULL, "DTC"),
               c(FALSE, TRUE, TRUE, NA, NA))
})

test_that("invalid_duration", {
  d <- data.frame(
    X = c("P2Y", "P2Y3M", "PT30M", "2 years", "", NA_character_),
    stringsAsFactors = FALSE
  )
  expect_equal(op_invalid_duration(d, NULL, "X"),
               c(FALSE, FALSE, FALSE, TRUE, NA, NA))
})

test_that("date_greater_than vs literal", {
  d <- data.frame(
    DTC = c("2024-01-15", "2023-06-01", "2024-12-31", "not-a-date"),
    stringsAsFactors = FALSE
  )
  # Against 2024-01-01
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

# --- cross-dataset tests ----------------------------------------------------

mk_ctx_with <- function(named_datasets) {
  ctx <- new_herald_ctx()
  ctx$datasets <- named_datasets
  ctx
}

test_that("is_not_unique_relationship flags inconsistent X->Y mappings", {
  ae <- data.frame(
    AEDECOD = c("HEADACHE", "HEADACHE", "NAUSEA", "HEADACHE"),
    AELLT   = c("HEAD PAIN", "HEADACHE", "NAUSEA", "HEAD PAIN"),
    stringsAsFactors = FALSE
  )
  # HEADACHE maps to both HEAD PAIN and HEADACHE -> inconsistent
  # NAUSEA maps to NAUSEA only -> consistent
  out <- op_is_not_unique_relationship(ae, NULL, "AEDECOD",
                                        list(related_name = "AELLT"))
  expect_equal(out, c(TRUE, TRUE, FALSE, TRUE))
})

test_that("is_inconsistent_across_dataset", {
  dm <- data.frame(USUBJID = c("S1", "S2", "S3"),
                   AGE = c(65, 72, 50),
                   stringsAsFactors = FALSE)
  ae <- data.frame(USUBJID = c("S1", "S2", "S4"),
                   AGE     = c(65, 72, 40),  # S4 missing from DM, age ok; otherwise consistent
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx_with(list(DM = dm, AE = ae))
  out <- op_is_inconsistent_across_dataset(
    ae, ctx, "AGE",
    list(reference_dataset = "DM", by = "USUBJID", column = "AGE")
  )
  # S1, S2 match; S4 not found in DM -> rhs NA -> not flagged
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

test_that("has_next_corresponding_record / does_not_have...", {
  ae     <- data.frame(USUBJID = c("S1","S2","S3"), stringsAsFactors = FALSE)
  suppae <- data.frame(USUBJID = c("S1","S3"),      stringsAsFactors = FALSE)
  ctx <- mk_ctx_with(list(AE = ae, SUPPAE = suppae))

  missing_child <- op_does_not_have_next_corresponding_record(
    ae, ctx, "USUBJID", list(reference_dataset = "SUPPAE", by = "USUBJID")
  )
  expect_equal(missing_child, c(FALSE, TRUE, FALSE))

  has_child <- op_has_next_corresponding_record(
    ae, ctx, "USUBJID", list(reference_dataset = "SUPPAE", by = "USUBJID")
  )
  expect_equal(has_child, c(TRUE, FALSE, TRUE))
})

# --- string op extensions ---------------------------------------------------

test_that("longer_than / shorter_than", {
  d <- data.frame(X = c("abc", "abcdefgh", NA_character_),
                  stringsAsFactors = FALSE)
  expect_equal(op_longer_than(d, NULL, "X", 5), c(FALSE, TRUE, NA))
  expect_equal(op_shorter_than(d, NULL, "X", 5), c(TRUE, FALSE, NA))
})

test_that("not_matches_regex inverts", {
  d <- data.frame(X = c("AE-001", "XX-002"),
                  stringsAsFactors = FALSE)
  expect_equal(op_not_matches_regex(d, NULL, "X", "^AE"),
               c(FALSE, TRUE))
})

test_that("starts_with / ends_with", {
  d <- data.frame(X = c("AEHEAD", "HEADAE", "NAUSEA"),
                  stringsAsFactors = FALSE)
  expect_equal(op_starts_with(d, NULL, "X", "AE"), c(TRUE, FALSE, FALSE))
  expect_equal(op_ends_with(d, NULL, "X", "AE"),   c(FALSE, TRUE, FALSE))
})

test_that("does_not_contain", {
  d <- data.frame(X = c("HEADACHE", "NAUSEA"), stringsAsFactors = FALSE)
  expect_equal(op_does_not_contain(d, NULL, "X", "HEAD"), c(FALSE, TRUE))
})
