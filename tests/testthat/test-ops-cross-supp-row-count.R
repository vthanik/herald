# -----------------------------------------------------------------------------
# test-ops-cross-supp-row-count.R -- op_supp_row_count_exceeds + CG0140/CG0527
# -----------------------------------------------------------------------------

.mk_ctx_with <- function(datasets) {
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- datasets
  ctx
}

.count_fired_supp <- function(res, rule_id) {
  f <- res$findings[res$findings$rule_id == rule_id &
                      res$findings$status == "fired", , drop = FALSE]
  nrow(f)
}

test_that("supp_row_count_exceeds fires when SUPP has >threshold matching QNAM rows", {
  dm <- data.frame(
    USUBJID = c("S1", "S2", "S3"),
    RACE    = c("ASIAN", "WHITE", "MULTIPLE"),
    stringsAsFactors = FALSE
  )
  supp <- data.frame(
    USUBJID = c("S1", "S1", "S2", "S3", "S3"),
    RDOMAIN = rep("DM", 5L),
    QNAM    = c("RACE1", "RACE2", "RACEOTH", "RACE1", "RACE2"),
    QLABEL  = rep("Race", 5L),
    QVAL    = c("ASIAN", "WHITE", "Other", "ASIAN", "WHITE"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm, ctx,
    ref_dataset  = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold    = 1L
  )
  # S1 has 2 RACE-prefixed rows (>1); S2 has 1; S3 has 2.
  expect_equal(mask, c(TRUE, FALSE, TRUE))
})

test_that("supp_row_count_exceeds returns FALSE at or below threshold", {
  dm <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  supp <- data.frame(
    USUBJID = c("S1", "S2"),
    QNAM    = c("RACE1", "RACEOTH"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm, ctx,
    ref_dataset  = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold    = 1L
  )
  expect_equal(mask, c(FALSE, FALSE))
})

test_that("supp_row_count_exceeds returns NA when SUPP dataset is absent", {
  dm <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  ctx <- .mk_ctx_with(list(DM = dm))
  mask <- herald:::op_supp_row_count_exceeds(
    dm, ctx,
    ref_dataset  = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold    = 1L
  )
  expect_equal(mask, rep(NA, 2L))
})

test_that("supp_row_count_exceeds returns FALSE when QNAM pattern matches nothing", {
  dm <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  supp <- data.frame(
    USUBJID = c("S1", "S2"),
    QNAM    = c("ETHNICITY", "SEXNOTE"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm, ctx,
    ref_dataset  = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold    = 1L
  )
  expect_equal(mask, c(FALSE, FALSE))
})

test_that("supp_row_count_exceeds returns FALSE when subject has no SUPP rows", {
  dm <- data.frame(
    USUBJID = c("S1", "S2", "S_MISSING"),
    stringsAsFactors = FALSE
  )
  supp <- data.frame(
    USUBJID = c("S1", "S1", "S2"),
    QNAM    = c("RACE1", "RACE2", "RACE1"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm, ctx,
    ref_dataset  = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold    = 1L
  )
  # S1: 2 -> TRUE, S2: 1 -> FALSE, S_MISSING: 0 -> FALSE
  expect_equal(mask, c(TRUE, FALSE, FALSE))
})

test_that("supp_row_count_exceeds honours a custom threshold", {
  dm <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  supp <- data.frame(
    USUBJID = c("S1", "S1", "S1", "S2", "S2"),
    QNAM    = c("RACE1", "RACE2", "RACE3", "RACE1", "RACE2"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm, ctx,
    ref_dataset  = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold    = 2L
  )
  # threshold=2 -> only fires when count > 2. S1=3 fires; S2=2 does not.
  expect_equal(mask, c(TRUE, FALSE))
})

test_that("supp_row_count_exceeds returns NA when SUPP lacks QNAM column", {
  dm <- data.frame(USUBJID = c("S1"), stringsAsFactors = FALSE)
  supp <- data.frame(USUBJID = "S1", QVAL = "ASIAN", stringsAsFactors = FALSE)
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm, ctx,
    ref_dataset  = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold    = 1L
  )
  expect_equal(mask, NA)
})

test_that("supp_row_count_exceeds is discoverable via the op registry", {
  expect_true("supp_row_count_exceeds" %in% herald:::.list_ops())
  meta <- herald:::.op_meta("supp_row_count_exceeds")
  expect_equal(meta$kind, "cross")
})

# ---------------------------------------------------------------------------
# Integration: CG0140 + CG0527 as predicate rules
# ---------------------------------------------------------------------------
# Row semantics for both rules (same check_tree):
#   S1: 2 RACE-prefixed SUPPDM rows AND DM.RACE != 'MULTIPLE' -> fire
#   S2: 2 RACE-prefixed SUPPDM rows AND DM.RACE == 'MULTIPLE' -> no fire
#   S3: 1 RACE-prefixed SUPPDM row (guard false) -> no fire
#   S4: no SUPPDM rows (guard false) -> no fire

.dm_suppdm_fixture <- function() {
  dm <- data.frame(
    STUDYID = rep("STUDY", 4L),
    DOMAIN  = rep("DM", 4L),
    USUBJID = c("S1", "S2", "S3", "S4"),
    RACE    = c("ASIAN", "MULTIPLE", "WHITE", "ASIAN"),
    stringsAsFactors = FALSE
  )
  supp <- data.frame(
    STUDYID = rep("STUDY", 5L),
    RDOMAIN = rep("DM", 5L),
    USUBJID = c("S1", "S1", "S2", "S2", "S3"),
    IDVAR   = rep("", 5L),
    IDVARVAL= rep("", 5L),
    QNAM    = c("RACE1", "RACE2", "RACE1", "RACE2", "RACE1"),
    QLABEL  = rep("Race", 5L),
    QVAL    = c("ASIAN", "WHITE", "ASIAN", "BLACK", "WHITE"),
    QORIG   = rep("CRF", 5L),
    QEVAL   = rep("", 5L),
    stringsAsFactors = FALSE
  )
  list(DM = dm, SUPPDM = supp)
}

test_that("CG0140 fires only when DM.RACE != 'MULTIPLE' AND SUPPDM has >1 RACE rows", {
  fx <- .dm_suppdm_fixture()
  r <- herald::validate(
    files = fx,
    rules = "CG0140",
    quiet = TRUE
  )
  expect_equal(.count_fired_supp(r, "CG0140"), 1L)
})

test_that("CG0527 uses the same predicate as CG0140", {
  fx <- .dm_suppdm_fixture()
  r <- herald::validate(
    files = fx,
    rules = "CG0527",
    quiet = TRUE
  )
  expect_equal(.count_fired_supp(r, "CG0527"), 1L)
})

test_that("CG0140 emits no fire when SUPPDM dataset absent", {
  fx <- .dm_suppdm_fixture()
  r <- herald::validate(
    files = list(DM = fx$DM),   # no SUPPDM
    rules = "CG0140",
    quiet = TRUE
  )
  expect_equal(.count_fired_supp(r, "CG0140"), 0L)
})
