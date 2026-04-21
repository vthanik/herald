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

test_that(".expand_indexed produces {any} of concrete instantiations", {
  ct <- list(
    expand = "xx",
    all = list(
      list(name = "TRTxxPN", operator = "exists"),
      list(name = "TRTxxP",  operator = "not_exists")
    )
  )
  data <- data.frame(TRT01PN = 1, TRT02PN = 2, TRT02P = "x",
                     stringsAsFactors = FALSE)
  expanded <- herald:::.expand_indexed(ct, data)
  expect_named(expanded, "any")
  # Two xx-values in data (01, 02) -> two instantiations
  expect_equal(length(expanded$any), 2L)
  inst_names <- sort(vapply(expanded$any, function(n) n$all[[1L]]$name,
                            character(1L)))
  expect_equal(inst_names, c("TRT01PN", "TRT02PN"))
})

test_that(".expand_indexed returns narrative stub when no cols match", {
  ct <- list(expand = "xx", all = list(
    list(name = "TRTxxPN", operator = "exists"),
    list(name = "TRTxxP",  operator = "not_exists")
  ))
  data <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  expanded <- herald:::.expand_indexed(ct, data)
  expect_true(is.list(expanded) && !is.null(expanded$narrative))
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
