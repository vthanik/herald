# -----------------------------------------------------------------------------
# test-fast-rules-wildcard.R — --VAR resolution for SDTM + ADaM + SUPP
# -----------------------------------------------------------------------------

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
