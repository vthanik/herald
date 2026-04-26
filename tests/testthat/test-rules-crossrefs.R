# -----------------------------------------------------------------------------
# test-fast-rules-crossrefs.R -- $-prefixed cross-reference resolver
# -----------------------------------------------------------------------------

mk_ctx <- function(datasets, spec = NULL, current = NULL) {
  ctx <- new_herald_ctx()
  ctx$datasets <- datasets
  ctx$spec <- spec
  ctx$crossrefs <- build_crossrefs(datasets, spec)
  if (!is.null(current)) {
    ctx$current_dataset <- current
  }
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
  expect_equal(
    resolve_ref("$usubjids_in_ex", ctx),
    resolve_ref("$ex_usubjid", ctx)
  )
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
    vapply(
      ctx$op_errors,
      function(e) identical(e$token, "$totally_made_up"),
      logical(1)
    )
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
  out <- substitute_crossrefs(
    list(name = "USUBJID", value = "$totally_made_up"),
    ctx
  )
  expect_true(isTRUE(out$unresolved))
})

test_that("substitute_crossrefs expands a resolvable value in place", {
  dm <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  ctx <- mk_ctx(list(DM = dm))
  out <- substitute_crossrefs(
    list(name = "USUBJID", value = "$dm_usubjid"),
    ctx
  )
  expect_false(out$unresolved)
  expect_setequal(out$args$value, c("S1", "S2"))
})

test_that("end-to-end: CG0029 fires exactly on AE rows not in DM", {
  dm <- data.frame(USUBJID = c("S1-001", "S1-002"), stringsAsFactors = FALSE)
  ae <- data.frame(
    USUBJID = c("S1-001", "S1-XXX", "S1-002"),
    stringsAsFactors = FALSE
  )
  r <- validate(files = list(dm, ae), rules = "CG0029", quiet = TRUE)
  fired <- r$findings[r$findings$status == "fired", , drop = FALSE]
  # Only AE row 2 should fire; DM rows and AE rows 1 + 3 are all in DM.USUBJID.
  expect_true(all(fired$dataset == "AE"))
  expect_equal(fired$row, 2L)
})

test_that("end-to-end: CG0029 without the ref target -> advisory only", {
  # DM missing entirely -> $dm_usubjid unresolved -> leaf NA -> advisory.
  ae <- data.frame(USUBJID = c("S1-001"), stringsAsFactors = FALSE)
  r <- validate(files = list(ae), rules = "CG0029", quiet = TRUE)
  expect_true(nrow(r$findings[r$findings$status == "fired", ]) == 0L)
  # Some advisory emission expected on the unresolved ref.
  expect_true(nrow(r$findings[r$findings$status == "advisory", ]) >= 1L)
})

test_that("dotted <DOM>.<COL> refs resolve to target-dataset values", {
  tv <- data.frame(VISITDY = c(1L, 8L, 15L), stringsAsFactors = FALSE)
  ctx <- mk_ctx(list(TV = tv))
  expect_setequal(resolve_ref("TV.VISITDY", ctx), c("1", "8", "15"))
})

test_that("dotted refs that don't match target dataset/column are unresolved", {
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- mk_ctx(list(DM = dm))
  expect_null(resolve_ref("TV.VISITDY", ctx))
  # logged as unresolved
  kinds <- vapply(ctx$op_errors, function(e) e$kind, character(1))
  expect_true("unresolved_crossref" %in% kinds)
})

test_that("substitute_crossrefs recognizes dotted refs in args", {
  tv <- data.frame(VISITDY = c(1L, 8L), stringsAsFactors = FALSE)
  ctx <- mk_ctx(list(TV = tv))
  out <- substitute_crossrefs(list(name = "VISITDY", value = "TV.VISITDY"), ctx)
  expect_false(out$unresolved)
  expect_setequal(out$args$value, c("1", "8"))
})

test_that("plain dotted strings that don't match the pattern are not resolved", {
  ctx <- mk_ctx(list(DM = data.frame(USUBJID = "S1", stringsAsFactors = FALSE)))
  # Lowercase / non-domain forms should NOT trigger resolution.
  expect_null(resolve_ref("v2.0", ctx))
  expect_null(resolve_ref("foo.bar", ctx))
})

# -- resolve_ref edge cases ---------------------------------------------------

test_that("resolve_ref returns NULL for non-character token", {
  ctx <- mk_ctx(list(DM = data.frame(USUBJID = "S1", stringsAsFactors = FALSE)))
  expect_null(herald:::resolve_ref(123L, ctx))
  expect_null(herald:::resolve_ref(NULL, ctx))
})

test_that("resolve_ref returns NULL for length > 1 character vector", {
  ctx <- mk_ctx(list(DM = data.frame(USUBJID = "S1", stringsAsFactors = FALSE)))
  expect_null(herald:::resolve_ref(c("$dm_usubjid", "$ta_armcd"), ctx))
})

test_that("resolve_ref uses op_results when available", {
  ctx <- mk_ctx(list(DM = data.frame(USUBJID = "S1", stringsAsFactors = FALSE)))
  ctx$op_results[["$computed_vals"]] <- c("V1", "V2")
  result <- herald:::resolve_ref("$computed_vals", ctx)
  expect_setequal(result, c("V1", "V2"))
})

test_that("resolve_ref resolves op_results via lowercased key", {
  ctx <- mk_ctx(list(DM = data.frame(USUBJID = "S1", stringsAsFactors = FALSE)))
  ctx$op_results[["$COMPUTED"]] <- list("A", "B")
  result <- herald:::resolve_ref("$COMPUTED", ctx)
  expect_setequal(result, c("A", "B"))
})

test_that("resolve_ref returns NULL when crossrefs registry is NULL", {
  ctx <- mk_ctx(list())
  ctx$crossrefs <- NULL
  expect_null(herald:::resolve_ref("$dm_usubjid", ctx))
})

test_that("resolve_ref resolves function entries dynamically", {
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  attr(dm, "label") <- "Demographics"
  ctx <- mk_ctx(list(DM = dm), current = "DM")
  # $domain_label is a function entry in crossrefs
  result <- herald:::resolve_ref("$domain_label", ctx)
  expect_equal(result, "Demographics")
})

# -- build_crossrefs with spec ------------------------------------------------

test_that("build_crossrefs with empty datasets returns domain_label function", {
  cr <- herald:::build_crossrefs(list())
  expect_true(is.function(cr[["$domain_label"]]))
})

test_that("build_crossrefs skips non-data-frame entries", {
  datasets <- list(DM = data.frame(USUBJID = "S1"), BAD = "not a data frame")
  cr <- herald:::build_crossrefs(datasets)
  # DM should be indexed, BAD should not create a token
  expect_false(is.null(cr[["$dm_usubjid"]]))
  expect_null(cr[["$bad_usubjid"]])
})

test_that("build_crossrefs creates armcd_list alias for TA.ARMCD", {
  ta <- data.frame(ARMCD = c("A", "B"), stringsAsFactors = FALSE)
  cr <- herald:::build_crossrefs(list(TA = ta))
  expect_setequal(cr[["$armcd_list"]], c("A", "B"))
})

test_that("build_crossrefs creates usubjids_in_<dom> alias for USUBJID cols", {
  ex <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  cr <- herald:::build_crossrefs(list(EX = ex))
  expect_setequal(cr[["$usubjids_in_ex"]], c("S1", "S2"))
})

# -- .spec_cols ---------------------------------------------------------------

test_that(".spec_cols returns required variables from spec var_spec", {
  var_spec <- data.frame(
    dataset = c("DM", "DM", "AE"),
    variable = c("USUBJID", "AGE", "AETERM"),
    required = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  spec <- structure(
    list(var_spec = var_spec),
    class = c("herald_spec", "list")
  )
  result <- herald:::.spec_cols(spec, "DM", c("required", "Required"))
  expect_equal(result, "USUBJID")
})

test_that(".spec_cols returns empty when no matching dataset", {
  var_spec <- data.frame(
    dataset = "DM",
    variable = "USUBJID",
    required = TRUE,
    stringsAsFactors = FALSE
  )
  spec <- structure(
    list(var_spec = var_spec),
    class = c("herald_spec", "list")
  )
  result <- herald:::.spec_cols(spec, "AE", c("required"))
  expect_equal(result, character(0))
})

test_that(".spec_cols returns empty when var_spec is not a data frame", {
  spec <- structure(list(var_spec = NULL), class = c("herald_spec", "list"))
  expect_equal(herald:::.spec_cols(spec, "DM", "required"), character(0))
})

test_that(".spec_cols handles string-truthy flag columns", {
  var_spec <- data.frame(
    dataset = c("DM", "DM"),
    variable = c("USUBJID", "AGE"),
    required = c("Y", "N"),
    stringsAsFactors = FALSE
  )
  spec <- structure(
    list(var_spec = var_spec),
    class = c("herald_spec", "list")
  )
  result <- herald:::.spec_cols(spec, "DM", c("required"))
  expect_equal(result, "USUBJID")
})

test_that(".spec_cols returns empty when flag column is absent", {
  var_spec <- data.frame(
    dataset = "DM",
    variable = "USUBJID",
    stringsAsFactors = FALSE
  )
  spec <- structure(
    list(var_spec = var_spec),
    class = c("herald_spec", "list")
  )
  result <- herald:::.spec_cols(spec, "DM", c("required"))
  expect_equal(result, character(0))
})

# -- build_crossrefs with spec-driven refs ------------------------------------

test_that("build_crossrefs registers required_variables closure when spec has ds_spec", {
  var_spec <- data.frame(
    dataset = "DM",
    variable = "USUBJID",
    required = TRUE,
    stringsAsFactors = FALSE
  )
  ds_spec <- data.frame(dataset = "DM", stringsAsFactors = FALSE)
  spec <- structure(
    list(ds_spec = ds_spec, var_spec = var_spec),
    class = c("herald_spec", "list")
  )
  cr <- herald:::build_crossrefs(list(), spec = spec)
  expect_true(is.function(cr[["$required_variables"]]))
  expect_true(is.function(cr[["$allowed_variables"]]))
})

# -- substitute_crossrefs edge cases ------------------------------------------

test_that("substitute_crossrefs handles empty args list", {
  ctx <- mk_ctx(list())
  out <- herald:::substitute_crossrefs(list(), ctx)
  expect_false(out$unresolved)
  expect_equal(out$args, list())
})

test_that("substitute_crossrefs skips non-character arg values", {
  ctx <- mk_ctx(list())
  out <- herald:::substitute_crossrefs(list(n = 5L, flag = TRUE), ctx)
  expect_false(out$unresolved)
})

test_that("substitute_crossrefs skips args with no $ or dotted refs", {
  ctx <- mk_ctx(list())
  out <- herald:::substitute_crossrefs(list(name = "USUBJID", value = "S1-001"), ctx)
  expect_false(out$unresolved)
  expect_equal(out$args$value, "S1-001")
})

# -- build_crossrefs closures with spec ----------------------------------------

test_that("$domain_label closure returns character(0) when ctx has no current_dataset", {
  cr <- herald:::build_crossrefs(list(), spec = NULL)
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list()
  ctx$current_dataset <- NULL
  result <- cr[["$domain_label"]](ctx)
  expect_equal(result, character(0))
})

test_that("build_crossrefs with spec creates $required_variables closure", {
  ds_spec <- data.frame(dataset = "DM", class = "FINDINGS", stringsAsFactors = FALSE)
  var_spec <- data.frame(dataset = "DM", variable = "USUBJID", required = TRUE,
                         stringsAsFactors = FALSE)
  spec <- structure(list(ds_spec = ds_spec, var_spec = var_spec),
                    class = c("herald_spec", "list"))
  cr <- herald:::build_crossrefs(list(DM = data.frame(x = 1L)), spec = spec)
  expect_true(is.function(cr[["$required_variables"]]))
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list(DM = data.frame(x = 1L))
  ctx$spec <- spec
  ctx$current_dataset <- "DM"
  result <- cr[["$required_variables"]](ctx)
  expect_true(is.character(result))
})

test_that("build_crossrefs with spec creates $allowed_variables closure", {
  ds_spec <- data.frame(dataset = "DM", class = "FINDINGS", stringsAsFactors = FALSE)
  var_spec <- data.frame(dataset = "DM", variable = "USUBJID", allowed = TRUE,
                         stringsAsFactors = FALSE)
  spec <- structure(list(ds_spec = ds_spec, var_spec = var_spec),
                    class = c("herald_spec", "list"))
  cr <- herald:::build_crossrefs(list(DM = data.frame(x = 1L)), spec = spec)
  expect_true(is.function(cr[["$allowed_variables"]]))
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list(DM = data.frame(x = 1L))
  ctx$spec <- spec
  ctx$current_dataset <- "DM"
  result <- cr[["$allowed_variables"]](ctx)
  expect_true(is.character(result))
})

test_that(".log_unresolved returns invisibly NULL when ctx is NULL", {
  result <- herald:::.log_unresolved(NULL, "$token")
  expect_null(result)
})
