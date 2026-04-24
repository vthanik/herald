# -----------------------------------------------------------------------------
# test-ops-cross-group-const.R -- op_is_not_constant_per_group +
#                                  op_no_baseline_record
# -----------------------------------------------------------------------------

# ---- helpers ----------------------------------------------------------------

.mk_ctx_empty <- function() {
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list()
  ctx
}

ctx_empty <- .mk_ctx_empty()

# =============================================================================
# op_is_not_constant_per_group
# =============================================================================

test_that("is_not_constant_per_group fires all rows in a violating group", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR", "SBP", "SBP"),
    CRITTY1 = c("A",  "B",  "A",  "X",   "X"),
    stringsAsFactors = FALSE
  )
  # HR has 2 distinct values of CRITTY1 -> all 3 rows fire.
  # SBP has 1 distinct value -> no fire.
  out <- herald:::op_is_not_constant_per_group(
    d, ctx_empty, name = "CRITTY1", group_by = list("PARAMCD")
  )
  expect_equal(out, c(TRUE, TRUE, TRUE, FALSE, FALSE))
})

test_that("is_not_constant_per_group returns FALSE when all groups are constant", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "SBP"),
    CRITy   = c("A",  "A",  "X"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_is_not_constant_per_group(
    d, ctx_empty, name = "CRITy", group_by = list("PARAMCD")
  )
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

test_that("is_not_constant_per_group ignores NA values in name column", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR"),
    BASETYPE = c(NA, NA, NA),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_is_not_constant_per_group(
    d, ctx_empty, name = "BASETYPE", group_by = list("PARAMCD")
  )
  # All NA -> group is not flagged (no non-NA values to count).
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

test_that("is_not_constant_per_group returns NA when name column absent", {
  d <- data.frame(PARAMCD = c("HR", "SBP"), stringsAsFactors = FALSE)
  out <- herald:::op_is_not_constant_per_group(
    d, ctx_empty, name = "MISSING_COL", group_by = list("PARAMCD")
  )
  expect_equal(out, c(NA, NA))
})

test_that("is_not_constant_per_group returns NA when group_by col absent", {
  d <- data.frame(
    CRITy = c("A", "B"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_is_not_constant_per_group(
    d, ctx_empty, name = "CRITy", group_by = list("PARAMCD")
  )
  expect_equal(out, c(NA, NA))
})

test_that("is_not_constant_per_group handles empty dataset", {
  d <- data.frame(
    PARAMCD = character(0L),
    CRITy   = character(0L),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_is_not_constant_per_group(
    d, ctx_empty, name = "CRITy", group_by = list("PARAMCD")
  )
  expect_length(out, 0L)
})

test_that("is_not_constant_per_group works with composite group_by", {
  d <- data.frame(
    PARAMCD  = c("HR", "HR", "HR", "HR"),
    BASETYPE = c("A",  "B",  "A",  "A"),
    USUBJID  = c("S1", "S1", "S2", "S2"),
    stringsAsFactors = FALSE
  )
  # group_by=[PARAMCD,USUBJID]:
  # (HR,S1): BASETYPE has A and B -> fires
  # (HR,S2): BASETYPE has A only -> no fire
  out <- herald:::op_is_not_constant_per_group(
    d, ctx_empty, name = "BASETYPE",
    group_by = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(TRUE, TRUE, FALSE, FALSE))
})

test_that("is_not_constant_per_group trims trailing whitespace before comparing", {
  d <- data.frame(
    PARAMCD = c("HR", "HR"),
    CRITy   = c("High blood pressure", "High blood pressure  "),
    stringsAsFactors = FALSE
  )
  # Both should resolve to the same rtrimmed value -> constant -> no fire.
  out <- herald:::op_is_not_constant_per_group(
    d, ctx_empty, name = "CRITy", group_by = list("PARAMCD")
  )
  expect_equal(out, c(FALSE, FALSE))
})

# =============================================================================
# op_no_baseline_record
# =============================================================================

test_that("no_baseline_record fires when BASE populated but no ABLFL=Y", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR"),
    USUBJID = c("S1", "S1", "S1"),
    BASE    = c(70,   70,   NA),
    ABLFL   = c(NA,   NA,   NA),
    stringsAsFactors = FALSE
  )
  # S1/HR: BASE is populated on rows 1 and 2; no ABLFL='Y' -> fires all rows.
  out <- herald:::op_no_baseline_record(
    d, ctx_empty,
    name       = "BASE",
    flag_var   = "ABLFL",
    flag_value = "Y",
    group_by   = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(TRUE, TRUE, TRUE))
})

test_that("no_baseline_record does not fire when ABLFL=Y present", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR"),
    USUBJID = c("S1", "S1", "S1"),
    BASE    = c(70,   70,   70),
    ABLFL   = c("Y",  NA,   NA),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d, ctx_empty,
    name       = "BASE",
    flag_var   = "ABLFL",
    flag_value = "Y",
    group_by   = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

test_that("no_baseline_record does not fire when BASE not populated in group", {
  d <- data.frame(
    PARAMCD = c("HR", "HR"),
    USUBJID = c("S1", "S1"),
    BASE    = c(NA,   NA),
    ABLFL   = c(NA,   NA),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d, ctx_empty,
    name       = "BASE",
    flag_var   = "ABLFL",
    flag_value = "Y",
    group_by   = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(FALSE, FALSE))
})

test_that("no_baseline_record returns NA when name column absent", {
  d <- data.frame(
    PARAMCD = c("HR"),
    ABLFL   = c("Y"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d, ctx_empty,
    name       = "BASE",
    flag_var   = "ABLFL",
    flag_value = "Y",
    group_by   = list("PARAMCD")
  )
  expect_equal(out, NA)
})

test_that("no_baseline_record returns NA when flag_var column absent", {
  d <- data.frame(
    PARAMCD = c("HR"),
    BASE    = c(70),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d, ctx_empty,
    name       = "BASE",
    flag_var   = "ABLFL",
    flag_value = "Y",
    group_by   = list("PARAMCD")
  )
  expect_equal(out, NA)
})

test_that("no_baseline_record handles multiple groups independently", {
  d <- data.frame(
    PARAMCD = c("HR",  "HR",  "SBP", "SBP"),
    USUBJID = c("S1",  "S1",  "S2",  "S2"),
    BASE    = c(70,    70,    NA,    NA),
    ABLFL   = c(NA,    NA,    NA,    NA),
    stringsAsFactors = FALSE
  )
  # HR/S1: BASE populated, no flag -> fires.
  # SBP/S2: BASE not populated -> no fire.
  out <- herald:::op_no_baseline_record(
    d, ctx_empty,
    name       = "BASE",
    flag_var   = "ABLFL",
    flag_value = "Y",
    group_by   = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(TRUE, TRUE, FALSE, FALSE))
})

test_that("no_baseline_record handles empty dataset", {
  d <- data.frame(
    PARAMCD = character(0L),
    USUBJID = character(0L),
    BASE    = numeric(0L),
    ABLFL   = character(0L),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d, ctx_empty,
    name       = "BASE",
    flag_var   = "ABLFL",
    flag_value = "Y",
    group_by   = list("PARAMCD", "USUBJID")
  )
  expect_length(out, 0L)
})

test_that("no_baseline_record uses exact flag_value match (case-sensitive)", {
  d <- data.frame(
    PARAMCD = c("HR", "HR"),
    USUBJID = c("S1", "S1"),
    BASE    = c(70,   70),
    ABLFL   = c("y",  NA),   # lowercase 'y' -- CDISC expects uppercase 'Y'
    stringsAsFactors = FALSE
  )
  # No row with ABLFL='Y' (uppercase) -> should fire.
  out <- herald:::op_no_baseline_record(
    d, ctx_empty,
    name       = "BASE",
    flag_var   = "ABLFL",
    flag_value = "Y",
    group_by   = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(TRUE, TRUE))
})
