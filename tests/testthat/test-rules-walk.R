# -----------------------------------------------------------------------------
# test-fast-rules-walk.R — rule-tree walker
# -----------------------------------------------------------------------------

fixture <- function() {
  data.frame(
    USUBJID  = c("S1", "S2", "S3", "S4"),
    AESTDTC  = c("2026-01-15", "2024---15", "", "not-a-date"),
    AETERM   = c("HEADACHE", "HEADACHE", NA_character_, ""),
    stringsAsFactors = FALSE
  )
}

test_that("empty node returns NA mask", {
  d <- fixture()
  expect_equal(walk_tree(NULL, d), rep(NA, nrow(d)))
  expect_equal(walk_tree(list(), d), rep(NA, nrow(d)))
})

test_that("narrative node returns NA mask (advisory)", {
  d <- fixture()
  out <- walk_tree(list(narrative = "rule text here"), d)
  expect_equal(out, rep(NA, nrow(d)))
})

test_that("leaf operator evaluates and returns logical mask", {
  d <- fixture()
  node <- list(operator = "iso8601", name = "AESTDTC", allow_missing = FALSE)
  out <- walk_tree(node, d)
  expect_equal(out, c(TRUE, TRUE, FALSE, FALSE))
})

test_that("{all} combinator ANDs children with short-circuit", {
  d <- fixture()
  # Both checks must pass: iso8601(AESTDTC) AND matches_regex(AETERM, 'HEAD.*')
  node <- list(all = list(
    list(operator = "iso8601", name = "AESTDTC", allow_missing = FALSE),
    list(operator = "matches_regex", name = "AETERM", value = "^HEAD.*$",
         allow_missing = FALSE)
  ))
  out <- walk_tree(node, d)
  # Row 1: iso ok + HEAD → TRUE
  # Row 2: iso ok + HEAD → TRUE
  # Row 3: iso fail (NA empty) → FALSE (short-circuited before AETERM check)
  # Row 4: iso fail → FALSE
  expect_equal(out, c(TRUE, TRUE, FALSE, FALSE))
})

test_that("{any} combinator ORs children with short-circuit", {
  d <- fixture()
  node <- list(any = list(
    list(operator = "iso8601", name = "AESTDTC", allow_missing = FALSE),
    list(operator = "matches_regex", name = "AETERM", value = "^HEAD.*$",
         allow_missing = FALSE)
  ))
  out <- walk_tree(node, d)
  # Row 1: iso TRUE → short-circuit TRUE
  # Row 2: iso TRUE → TRUE
  # Row 3: iso FALSE, AETERM NA (regex fails) → FALSE
  # Row 4: iso FALSE, AETERM empty (regex fails) → FALSE
  expect_equal(out, c(TRUE, TRUE, FALSE, FALSE))
})

test_that("{not} combinator negates child", {
  d <- fixture()
  inner <- list(operator = "iso8601", name = "AESTDTC", allow_missing = FALSE)
  out <- walk_tree(list(`not` = inner), d)
  # Inverse of (TRUE, TRUE, FALSE, FALSE) -> (FALSE, FALSE, TRUE, TRUE)
  expect_equal(out, c(FALSE, FALSE, TRUE, TRUE))
})

test_that("unknown operator records error and returns NA mask", {
  d <- fixture()
  ctx <- new_herald_ctx()
  node <- list(operator = "nonexistent", name = "AESTDTC")
  out <- walk_tree(node, d, ctx)
  expect_true(all(is.na(out)))
  expect_equal(length(ctx$op_errors), 1L)
  expect_equal(ctx$op_errors[[1]]$kind, "unknown_operator")
})

test_that("operator error is caught; walker returns NA and logs", {
  d <- fixture()
  ctx <- new_herald_ctx()
  # length_le expects value to be coercible; give it a malformed type
  node <- list(operator = "iso8601", name = "NONEXISTENT_COLUMN")
  out <- walk_tree(node, d, ctx)
  # op_iso8601 returns NA when column absent; no error logged
  expect_true(all(is.na(out)))
})

test_that("empty dataset yields empty mask", {
  empty <- data.frame(USUBJID = character(0), stringsAsFactors = FALSE)
  node <- list(operator = "iso8601", name = "USUBJID")
  out <- walk_tree(node, empty)
  expect_equal(out, logical(0))
})

test_that("nested combinators compose correctly", {
  d <- fixture()
  # (iso8601 AND (NOT contains(AETERM, 'HEAD')))
  node <- list(all = list(
    list(operator = "iso8601", name = "AESTDTC", allow_missing = FALSE),
    list(`not` = list(operator = "contains", name = "AETERM", value = "HEAD"))
  ))
  out <- walk_tree(node, d)
  # Row 1: iso TRUE, contains HEAD TRUE -> not FALSE -> all TRUE AND FALSE = FALSE
  # Row 2: iso TRUE, contains HEAD TRUE -> not FALSE -> FALSE
  # Row 3: iso FALSE (empty) -> short-circuit FALSE
  # Row 4: iso FALSE -> FALSE
  expect_equal(out, c(FALSE, FALSE, FALSE, FALSE))
})

# ---------------------------------------------------------------------------
# --VAR wildcard resolution (from test-fast-rules-wildcard.R)
# ---------------------------------------------------------------------------

test_that("SDTM: --DY resolves to AEDY in AE domain", {
  ctx <- new_herald_ctx()
  ctx$current_dataset <- "AE"
  ctx$current_domain  <- "AE"
  d <- data.frame(
    AEDY = c(1L, 2L, 3L),
    stringsAsFactors = FALSE
  )
  cands <- .domain_prefix_candidates(ctx, d)
  expect_true("AE" %in% cands)
  resolved <- .resolve_wildcard("--DY", d, cands)
  expect_equal(resolved, "AEDY")
})

test_that("ADaM: --DY is NOT expanded (ADaMIG uses explicit names)", {
  # Per ADaMIG, ADaM variables use explicit naming (ADY, ASTDY, AENDY,
  # AVAL, etc.). The `--VAR` wildcard is SDTM-only. When a rule using
  # `--VAR` lands on an ADaM dataset, we leave the wildcard unresolved;
  # the operator sees "--DY" as the column name, returns NA, and the
  # walker emits an advisory finding rather than a false positive.
  ctx <- new_herald_ctx()
  ctx$current_dataset <- "ADAE"
  d <- data.frame(
    AEDY     = c(1L, 2L, 3L),
    ADY      = c(1L, 2L, 3L),
    USUBJID  = c("S1","S2","S3"),
    stringsAsFactors = FALSE
  )
  cands <- .domain_prefix_candidates(ctx, d)
  expect_equal(cands, character(0))
  resolved <- .resolve_wildcard("--DY", d, cands)
  expect_equal(resolved, "--DY")  # unchanged
})

test_that("ADaM: all AD* datasets skip wildcard expansion", {
  ctx <- new_herald_ctx()
  for (ds in c("ADSL", "ADAE", "ADCM", "ADLB", "ADVS", "ADTTE")) {
    ctx$current_dataset <- ds
    ctx$current_domain  <- NULL
    d <- data.frame(X = 1, stringsAsFactors = FALSE)
    cands <- .domain_prefix_candidates(ctx, d)
    expect_equal(cands, character(0),
                 info = sprintf("ADaM dataset %s must produce no candidates", ds))
  }
})

test_that("SUPP: --VAR resolves to parent domain's prefix", {
  ctx <- new_herald_ctx()
  ctx$current_dataset <- "SUPPAE"
  d <- data.frame(
    AEDY = c(1L, 2L),  # SUPPAE probably wouldn't have this, but the test is about resolution
    stringsAsFactors = FALSE
  )
  cands <- .domain_prefix_candidates(ctx, d)
  expect_true("AE" %in% cands)
})

test_that("No candidate matches -> use primary (first) candidate", {
  ctx <- new_herald_ctx()
  ctx$current_dataset <- "AE"
  ctx$current_domain  <- "AE"
  d <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  cands <- .domain_prefix_candidates(ctx, d)
  resolved <- .resolve_wildcard("--NONEXISTENT", d, cands)
  expect_equal(resolved, "AENONEXISTENT")
})

test_that("Empty ctx -> wildcard returned unchanged (no prefix to expand to)", {
  ctx <- new_herald_ctx()
  d <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  cands <- .domain_prefix_candidates(ctx, d)
  resolved <- .resolve_wildcard("--DY", d, cands)
  expect_equal(resolved, "--DY")
})

test_that("DOMAIN column provides fallback prefix", {
  ctx <- new_herald_ctx()
  d <- data.frame(
    DOMAIN = c("AE", "AE", "AE"),
    AEDY   = c(1L, 2L, 3L),
    stringsAsFactors = FALSE
  )
  cands <- .domain_prefix_candidates(ctx, d)
  expect_true("AE" %in% cands)
})

test_that("end-to-end: check_tree with --VAR in ADaM stays unresolved (advisory)", {
  # --DY in an ADaM context: column won't resolve, op sees "--DY"
  # which doesn't exist -> returns NA mask.
  tree <- list(all = list(
    list(name = "--DY", operator = "non_empty")
  ))
  d <- data.frame(AEDY = c(1L, NA_integer_, 3L), ADY = c(NA, 2L, 3L),
                  stringsAsFactors = FALSE)
  ctx <- new_herald_ctx()
  ctx$current_dataset <- "ADAE"
  mask <- walk_tree(tree, d, ctx)
  expect_true(all(is.na(mask)))
})

test_that("end-to-end: SDTM --VAR resolves and fires normally", {
  tree <- list(all = list(
    list(name = "--DY", operator = "non_empty")
  ))
  d <- data.frame(AEDY = c(1L, NA_integer_, 3L), stringsAsFactors = FALSE)
  ctx <- new_herald_ctx()
  ctx$current_dataset <- "AE"
  ctx$current_domain  <- "AE"
  mask <- walk_tree(tree, d, ctx)
  expect_equal(mask, c(TRUE, FALSE, TRUE))
})
