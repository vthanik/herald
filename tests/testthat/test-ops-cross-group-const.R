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

# =============================================================================
# op_base_not_equal_abl_row
# =============================================================================

test_that("base_not_equal_abl_row fires when b_var differs from anchor a_var", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    PARAMCD = c("HR", "HR", "HR"),
    ABLFL   = c("Y",  NA,   NA),
    AVAL    = c(70,   75,   80),
    BASE    = c(70,   75,   75),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d, ctx_empty, b_var = "BASE", a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"), basetype_gate = "any"
  )
  # anchor AVAL=70; row2 BASE=75 != 70 -> fires; row3 BASE=75 != 70 -> fires
  expect_true(out[[2L]])
  expect_true(out[[3L]])
  expect_false(isTRUE(out[[1L]]))  # anchor row itself: BASE=70 == AVAL=70 -> pass
})

test_that("base_not_equal_abl_row passes when b_var matches anchor a_var", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    PARAMCD = c("HR", "HR"),
    ABLFL   = c("Y",  NA),
    AVAL    = c(70,   70),
    BASE    = c(70,   70),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d, ctx_empty, b_var = "BASE", a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"), basetype_gate = "any"
  )
  expect_true(all(!out))
})

test_that("base_not_equal_abl_row passes when b_var is not populated", {
  d <- data.frame(
    USUBJID = "S1",
    PARAMCD = "HR",
    ABLFL   = "Y",
    AVAL    = 70,
    BASE    = NA_real_,
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d, ctx_empty, b_var = "BASE", a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"), basetype_gate = "any"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("base_not_equal_abl_row returns NA when group has no anchor row", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    PARAMCD = c("HR", "HR"),
    ABLFL   = c(NA,   NA),
    AVAL    = c(70,   75),
    BASE    = c(70,   75),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d, ctx_empty, b_var = "BASE", a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"), basetype_gate = "any"
  )
  expect_true(all(is.na(out)))
})

test_that("base_not_equal_abl_row skips dataset when basetype_gate=absent and BASETYPE present", {
  d <- data.frame(
    USUBJID  = c("S1", "S1"),
    PARAMCD  = c("HR", "HR"),
    ABLFL    = c("Y",  NA),
    AVAL     = c(70,   70),
    BASE     = c(70,   99),
    BASETYPE = c("Last", "Last"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d, ctx_empty, b_var = "BASE", a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"), basetype_gate = "absent"
  )
  expect_true(all(!out))
})

test_that("base_not_equal_abl_row runs when basetype_gate=absent and BASETYPE absent", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    PARAMCD = c("HR", "HR"),
    ABLFL   = c("Y",  NA),
    AVAL    = c(70,   70),
    BASE    = c(70,   99),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d, ctx_empty, b_var = "BASE", a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"), basetype_gate = "absent"
  )
  expect_true(out[[2L]])
})

test_that("base_not_equal_abl_row skips null-BASETYPE rows when gate=populated", {
  d <- data.frame(
    USUBJID  = c("S1", "S1", "S1"),
    PARAMCD  = c("HR", "HR", "HR"),
    ABLFL    = c("Y",  NA,   NA),
    AVAL     = c(70,   70,   70),
    BASE     = c(70,   99,   99),
    BASETYPE = c(NA,   NA,   "Last"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d, ctx_empty, b_var = "BASE", a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD", "BASETYPE"), basetype_gate = "populated"
  )
  # row1: b_var=70 == anchor (same group key includes BASETYPE=NA) -> varies
  # row2: BASETYPE is NA -> skipped (FALSE)
  # row3: BASETYPE="Last" -> active; anchor in "Last" group? anchor ABLFL="Y" is
  #   in BASETYPE=NA group, so no anchor for "Last" group -> NA advisory
  expect_false(isTRUE(out[[2L]]))
  expect_true(is.na(out[[3L]]))
})

test_that("base_not_equal_abl_row returns NA advisory for absent b_var column", {
  d <- data.frame(USUBJID = "S1", AVAL = 70, ABLFL = "Y", stringsAsFactors = FALSE)
  out <- herald:::op_base_not_equal_abl_row(
    d, ctx_empty, b_var = "BASE", a_var = "AVAL",
    group_by = list("USUBJID"), basetype_gate = "any"
  )
  expect_true(is.na(out[[1L]]))
})

# =============================================================================
# op_max_n_records_per_group_matching
# =============================================================================

test_that("max_n_records_per_group_matching fires all rows in violating group", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1", "S2"),
    DSSCAT  = c("STUDY PARTICIPATION", "STUDY PARTICIPATION", "OTHER",
                "STUDY PARTICIPATION"),
    stringsAsFactors = FALSE
  )
  # S1: 2 matches > max_n=1 -> ALL S1 rows fire (including OTHER row)
  # S2: 1 match == max_n=1 -> does not fire
  out <- herald:::op_max_n_records_per_group_matching(
    d, ctx_empty,
    name       = "DSSCAT",
    value      = "STUDY PARTICIPATION",
    group_keys = "USUBJID",
    max_n      = 1L
  )
  expect_true(out[[1L]])
  expect_true(out[[2L]])
  expect_true(out[[3L]])   # OTHER row still in S1 group -> fires
  expect_false(out[[4L]])
})

test_that("max_n_records_per_group_matching does not fire when count equals max_n", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    FLAG    = c("Y", "N"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_max_n_records_per_group_matching(
    d, ctx_empty,
    name       = "FLAG",
    value      = "Y",
    group_keys = "USUBJID",
    max_n      = 1L
  )
  expect_equal(out, c(FALSE, FALSE))
})

test_that("max_n_records_per_group_matching returns NA when name column absent", {
  d <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  out <- herald:::op_max_n_records_per_group_matching(
    d, ctx_empty,
    name       = "DSSCAT",
    value      = "STUDY PARTICIPATION",
    group_keys = "USUBJID",
    max_n      = 1L
  )
  expect_equal(out, c(NA, NA))
})

test_that("max_n_records_per_group_matching returns NA when group_keys col absent", {
  d <- data.frame(
    DSSCAT = c("STUDY PARTICIPATION", "OTHER"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_max_n_records_per_group_matching(
    d, ctx_empty,
    name       = "DSSCAT",
    value      = "STUDY PARTICIPATION",
    group_keys = "USUBJID",
    max_n      = 1L
  )
  expect_equal(out, c(NA, NA))
})

test_that("max_n_records_per_group_matching handles empty dataset", {
  d <- data.frame(
    USUBJID = character(0L),
    DSSCAT  = character(0L),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_max_n_records_per_group_matching(
    d, ctx_empty,
    name       = "DSSCAT",
    value      = "STUDY PARTICIPATION",
    group_keys = "USUBJID",
    max_n      = 1L
  )
  expect_length(out, 0L)
})

test_that("max_n_records_per_group_matching works with composite group_keys", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1", "S1"),
    PARAMCD = c("HR", "HR", "SBP", "SBP"),
    ABLFL   = c("Y",  "Y",  "Y",   "N"),
    stringsAsFactors = FALSE
  )
  # HR group: 2 matches > max_n=1 -> fires all HR rows
  # SBP group: 1 match <= max_n=1 -> no fire
  out <- herald:::op_max_n_records_per_group_matching(
    d, ctx_empty,
    name       = "ABLFL",
    value      = "Y",
    group_keys = c("USUBJID", "PARAMCD"),
    max_n      = 1L
  )
  expect_true(out[[1L]])
  expect_true(out[[2L]])
  expect_false(out[[3L]])
  expect_false(out[[4L]])
})

test_that("max_n_records_per_group_matching trims trailing whitespace before match", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    DSSCAT  = c("STUDY PARTICIPATION  ", "STUDY PARTICIPATION"),
    stringsAsFactors = FALSE
  )
  # Both rtrim to same -> 2 matches -> fires
  out <- herald:::op_max_n_records_per_group_matching(
    d, ctx_empty,
    name       = "DSSCAT",
    value      = "STUDY PARTICIPATION",
    group_keys = "USUBJID",
    max_n      = 1L
  )
  expect_true(all(out))
})
