# -----------------------------------------------------------------------------
# test-fast-rules-crossrefs.R -- $-prefixed cross-reference resolver
# -----------------------------------------------------------------------------

mk_ctx <- function(datasets, spec = NULL, current = NULL) {
  ctx <- new_herald_ctx()
  ctx$datasets <- datasets
  ctx$spec     <- spec
  ctx$crossrefs <- build_crossrefs(datasets, spec)
  if (!is.null(current)) ctx$current_dataset <- current
  ctx
}

test_that("$<dom>_<col> resolves to unique non-NA column values", {
  dm <- data.frame(USUBJID = c("S1", "S2", NA, "S1"), stringsAsFactors = FALSE)
  ctx <- mk_ctx(list(DM = dm))
  expect_setequal(resolve_ref("$dm_usubjid", ctx), c("S1", "S2"))
})

test_that("$ta_armcd resolves from the TA dataset", {
  ta <- data.frame(ARMCD = c("A", "B", "B", "C"), stringsAsFactors = FALSE)
  ctx <- mk_ctx(list(TA = ta))
  expect_setequal(resolve_ref("$ta_armcd", ctx), c("A", "B", "C"))
})

test_that("$list_dataset_names returns uppercase dataset names", {
  ctx <- mk_ctx(list(DM = data.frame(X = 1), AE = data.frame(X = 1)))
  expect_setequal(resolve_ref("$list_dataset_names", ctx), c("DM", "AE"))
  expect_setequal(resolve_ref("$study_domains", ctx), c("DM", "AE"))
})

test_that("$usubjids_in_<dom> is an alias for $<dom>_usubjid", {
  ex <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  ctx <- mk_ctx(list(EX = ex))
  expect_equal(resolve_ref("$usubjids_in_ex", ctx),
               resolve_ref("$ex_usubjid", ctx))
})

test_that("Missing dataset returns NULL and logs an op_errors entry", {
  ctx <- mk_ctx(list(DM = data.frame(USUBJID = "S1", stringsAsFactors = FALSE)))
  expect_null(resolve_ref("$xx_usubjid", ctx))
  kinds <- vapply(ctx$op_errors, function(e) e$kind, character(1))
  expect_true("unresolved_crossref" %in% kinds)
})

test_that("Unknown token returns NULL + logs", {
  ctx <- mk_ctx(list(DM = data.frame(USUBJID = "S1", stringsAsFactors = FALSE)))
  expect_null(resolve_ref("$totally_made_up", ctx))
  expect_true(any(
    vapply(ctx$op_errors, function(e) identical(e$token, "$totally_made_up"),
           logical(1))
  ))
})

test_that("$domain_label resolves dynamically from current_dataset attr", {
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  attr(dm, "label") <- "Demographics"
  ctx <- mk_ctx(list(DM = dm), current = "DM")
  expect_equal(resolve_ref("$domain_label", ctx), "Demographics")
})

test_that("$domain_label for a dataset with no label is unresolved", {
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- mk_ctx(list(DM = dm), current = "DM")
  expect_null(resolve_ref("$domain_label", ctx))
})

test_that("substitute_crossrefs flags unresolved refs", {
  ctx <- mk_ctx(list(DM = data.frame(USUBJID = "S1", stringsAsFactors = FALSE)))
  out <- substitute_crossrefs(list(name = "USUBJID",
                                   value = "$totally_made_up"), ctx)
  expect_true(isTRUE(out$unresolved))
})

test_that("substitute_crossrefs expands a resolvable value in place", {
  dm <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  ctx <- mk_ctx(list(DM = dm))
  out <- substitute_crossrefs(list(name = "USUBJID",
                                   value = "$dm_usubjid"), ctx)
  expect_false(out$unresolved)
  expect_setequal(out$args$value, c("S1", "S2"))
})

test_that("end-to-end: CORE-000201 fires exactly on AE rows not in DM", {
  dm <- data.frame(USUBJID = c("S1-001", "S1-002"), stringsAsFactors = FALSE)
  ae <- data.frame(USUBJID = c("S1-001", "S1-XXX", "S1-002"),
                   stringsAsFactors = FALSE)
  r <- validate(files = list(dm, ae),
                rules = "CORE-000201", quiet = TRUE)
  fired <- r$findings[r$findings$status == "fired", , drop = FALSE]
  # Only AE row 2 should fire; DM rows and AE rows 1 + 3 are all in DM.USUBJID.
  expect_true(all(fired$dataset == "AE"))
  expect_equal(fired$row, 2L)
})

test_that("end-to-end: CORE-000201 without the ref target -> advisory only", {
  # DM missing entirely -> $dm_usubjid unresolved -> leaf NA -> advisory.
  ae <- data.frame(USUBJID = c("S1-001"), stringsAsFactors = FALSE)
  r <- validate(files = list(ae),
                rules = "CORE-000201", quiet = TRUE)
  expect_true(nrow(r$findings[r$findings$status == "fired", ]) == 0L)
  # Some advisory emission expected on the unresolved ref.
  expect_true(nrow(r$findings[r$findings$status == "advisory", ]) >= 1L)
})
