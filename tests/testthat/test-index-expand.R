# -----------------------------------------------------------------------------
# test-fast-index-expand.R -- xx / y / zz placeholder expansion
# -----------------------------------------------------------------------------
# ADaMIG index conventions:
#   xx -- 01-99 zero-padded
#   y  -- 1-9 single digit
#   zz -- 01-99 zero-padded (second slot)
#
# A check_tree carrying `expand: xx` (etc.) gets rewritten against the
# dataset's columns before the walker sees it; each matching concrete value
# instantiates a copy of the subtree under an implicit {any}.

test_that(".index_values_in_cols finds concrete xx values", {
  cols <- c("USUBJID", "TRT01PN", "TRT02PN", "TRT04PN", "AGE")
  vals <- herald:::.index_values_in_cols("TRTxxPN", cols, "xx")
  expect_setequal(vals, c("01", "02", "04"))
})

test_that(".index_values_in_cols returns empty when template doesn't match", {
  cols <- c("USUBJID", "AGE")
  expect_equal(herald:::.index_values_in_cols("TRTxxPN", cols, "xx"),
               character())
})

test_that("y (single digit) extraction", {
  cols <- c("USUBJID", "TRTPG1N", "TRTPG3N")
  expect_setequal(herald:::.index_values_in_cols("TRTPGyN", cols, "y"),
                  c("1", "3"))
})

test_that(".substitute_index rewrites leaf names", {
  tree <- list(all = list(
    list(name = "TRTxxPN", operator = "exists"),
    list(name = "TRTxxP",  operator = "not_exists")
  ))
  out <- herald:::.substitute_index(tree, "xx", "01")
  expect_equal(out$all[[1L]]$name, "TRT01PN")
  expect_equal(out$all[[2L]]$name, "TRT01P")
})

test_that(".expand_indexed returns per-instance tree map for indexed rules", {
  ct <- list(
    expand = "xx",
    all = list(
      list(name = "TRTxxPN", operator = "exists"),
      list(name = "TRTxxP",  operator = "not_exists")
    )
  )
  data <- data.frame(TRT01PN = 1, TRT02PN = 2, TRT02P = "x",
                     stringsAsFactors = FALSE)
  xp <- herald:::.expand_indexed(ct, data)
  expect_true(isTRUE(xp$indexed))
  expect_equal(xp$placeholder, "xx")
  expect_setequal(names(xp$instances), c("01", "02"))
  # Each instance carries the substituted name in its leaves.
  expect_equal(xp$instances[["01"]]$all[[1L]]$name, "TRT01PN")
  expect_equal(xp$instances[["02"]]$all[[1L]]$name, "TRT02PN")
  # Legacy `$tree` still holds the `{any}` combinator for a single walk.
  expect_named(xp$tree, "any")
  expect_equal(length(xp$tree$any), 2L)
})

test_that(".expand_indexed returns empty instances + narrative when no cols match", {
  ct <- list(expand = "xx", all = list(
    list(name = "TRTxxPN", operator = "exists"),
    list(name = "TRTxxP",  operator = "not_exists")
  ))
  data <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  xp <- herald:::.expand_indexed(ct, data)
  expect_true(isTRUE(xp$indexed))
  expect_equal(length(xp$instances), 0L)
  expect_true(is.list(xp$tree) && !is.null(xp$tree$narrative))
})

test_that("non-indexed check_tree passes through unchanged", {
  ct <- list(all = list(
    list(name = "AETERM", operator = "exists")
  ))
  xp <- herald:::.expand_indexed(ct, data.frame(AETERM = "x"))
  expect_false(xp$indexed)
  expect_equal(length(xp$instances), 0L)
  expect_identical(xp$tree, ct)
})

test_that("fired finding carries RESOLVED message, not the template", {
  # Dataset has TRT01PN and TRT04PN (no pair) -> two separate violations
  # with distinct resolved messages.
  ds <- data.frame(
    USUBJID = "S1",
    TRT01PN = 1L,
    TRT04PN = 4L,
    TRT02PN = 2L,
    TRT02P  = "Placebo",   # 02 is complete -> no fire for 02
    stringsAsFactors = FALSE
  )
  spec <- structure(list(ds_spec = data.frame(
    dataset = "ADSL", class = "SUBJECT LEVEL ANALYSIS DATASET",
    stringsAsFactors = FALSE
  )), class = c("herald_spec", "list"))
  r <- herald::validate(files = list(ADSL = ds), spec = spec,
                        rules = "75", quiet = TRUE)
  fired <- r$findings[r$findings$status == "fired", , drop = FALSE]
  expect_equal(nrow(fired), 2L)
  # Messages must carry the concrete index values, not "xx".
  msgs <- sort(fired$message)
  expect_equal(msgs[[1L]], "TRT01PN is present and TRT01P is not present")
  expect_equal(msgs[[2L]], "TRT04PN is present and TRT04P is not present")
  # Template placeholder must NOT leak into any finding message.
  expect_false(any(grepl("xx", fired$message)))
})

test_that("end-to-end: ADaM-75 fires on TRT01PN-present / TRT01P-missing", {
  ds <- data.frame(USUBJID = c("S1", "S2"),
                   TRT01PN = c(1L, 1L),
                   TRT02PN = c(2L, 2L),
                   TRT02P  = c("Placebo", "Placebo"),
                   stringsAsFactors = FALSE)
  spec <- structure(list(ds_spec = data.frame(
    dataset = "ADSL", class = "SUBJECT LEVEL ANALYSIS DATASET",
    stringsAsFactors = FALSE
  )), class = c("herald_spec","list"))
  r <- herald::validate(files = list(ADSL = ds), spec = spec,
                        rules = "75", quiet = TRUE)
  fired <- r$findings[r$findings$status == "fired", ]
  expect_equal(nrow(fired), 1L)
})

test_that("end-to-end: ADaM-75 does NOT fire when all pairs are complete", {
  ds <- data.frame(USUBJID = "S1",
                   TRT01PN = 1L, TRT01P = "Placebo",
                   TRT02PN = 2L, TRT02P = "Drug",
                   stringsAsFactors = FALSE)
  spec <- structure(list(ds_spec = data.frame(
    dataset = "ADSL", class = "SUBJECT LEVEL ANALYSIS DATASET",
    stringsAsFactors = FALSE
  )), class = c("herald_spec","list"))
  r <- herald::validate(files = list(ADSL = ds), spec = spec,
                        rules = "75", quiet = TRUE)
  expect_equal(nrow(r$findings[r$findings$status == "fired", ]), 0L)
})
