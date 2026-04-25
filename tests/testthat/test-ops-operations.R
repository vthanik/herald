# test-ops-operations.R -- Operations pre-compute registry + new check-side ops

mk_ctx <- function(datasets = list(), current_dataset = NULL, spec = NULL) {
  e <- herald:::new_herald_ctx()
  e$datasets        <- datasets
  e$spec            <- spec
  e$crossrefs       <- herald:::build_crossrefs(datasets, spec)
  e$current_dataset <- current_dataset
  e$current_domain  <- if (!is.null(current_dataset)) toupper(substr(current_dataset, 1, 2)) else ""
  e
}

# ---------- Operations registry basics ----------------------------------------

test_that(".list_operations() returns all 19 registered operations", {
  ops <- herald:::.list_operations()
  expect_true(length(ops) >= 19L)
  expect_true("domain_label"           %in% ops)
  expect_true("distinct"               %in% ops)
  expect_true("record_count"           %in% ops)
  expect_true("domain_is_custom"       %in% ops)
  expect_true("study_domains"          %in% ops)
  expect_true("dataset_names"          %in% ops)
  expect_true("max_date"               %in% ops)
  expect_true("min_date"               %in% ops)
  expect_true("dy"                     %in% ops)
  expect_true("get_column_order_from_dataset" %in% ops)
  expect_true("expected_variables"     %in% ops)
  expect_true("required_variables"     %in% ops)
  expect_true("get_codelist_attributes"%in% ops)
  expect_true("extract_metadata"       %in% ops)
})

# ---------- domain_label -------------------------------------------------------

test_that("domain_label returns attr label when set", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  attr(df, "label") <- "Adverse Events"
  ctx <- mk_ctx(datasets = list(AE = df), current_dataset = "AE")
  res <- herald:::.apply_operations(
    list(list(id = "$domain_label", operator = "domain_label")),
    df, list(AE = df), ctx
  )
  expect_equal(res[["$domain_label"]][[1L]], "Adverse Events")
})

test_that("domain_label returns NA_character_ when no label", {
  df  <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(AE = df), current_dataset = "AE")
  res <- herald:::.apply_operations(
    list(list(id = "$domain_label", operator = "domain_label")),
    df, list(AE = df), ctx
  )
  expect_true(is.na(res[["$domain_label"]][[1L]]))
})

# ---------- distinct -----------------------------------------------------------

test_that("distinct returns unique non-NA column values", {
  df  <- data.frame(DOMAIN = c("AE", "AE", "LB", NA), stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(MULTI = df), current_dataset = "MULTI")
  res <- herald:::.apply_operations(
    list(list(id = "$domain_list", name = "DOMAIN", operator = "distinct")),
    df, list(MULTI = df), ctx
  )
  vals <- unlist(res[["$domain_list"]][[1L]])
  expect_setequal(vals, c("AE", "LB"))
})

# ---------- record_count -------------------------------------------------------

test_that("record_count returns nrow as scalar", {
  df  <- data.frame(x = 1:5, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DS = df), current_dataset = "DS")
  res <- herald:::.apply_operations(
    list(list(id = "$n_rows", operator = "record_count")),
    df, list(DS = df), ctx
  )
  expect_equal(res[["$n_rows"]][[1L]], 5L)
})

# ---------- domain_is_custom ---------------------------------------------------

test_that("domain_is_custom TRUE for non-standard domain", {
  df  <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(XY = df), current_dataset = "XY")
  res <- herald:::.apply_operations(
    list(list(id = "$is_custom", operator = "domain_is_custom")),
    df, list(XY = df), ctx
  )
  expect_true(isTRUE(res[["$is_custom"]][[1L]]))
})

test_that("domain_is_custom FALSE for standard SDTM domain", {
  df  <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(AE = df), current_dataset = "AE")
  res <- herald:::.apply_operations(
    list(list(id = "$is_custom", operator = "domain_is_custom")),
    df, list(AE = df), ctx
  )
  expect_false(isTRUE(res[["$is_custom"]][[1L]]))
})

# ---------- max_date / min_date ------------------------------------------------

test_that("max_date returns lexicographic maximum date string", {
  df  <- data.frame(EXSTDTC = c("2021-03-01","2022-11-30","2020-01-01"),
                    stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(EX = df), current_dataset = "EX")
  res <- herald:::.apply_operations(
    list(list(id = "$max_exstdtc", name = "EXSTDTC", operator = "max_date")),
    df, list(EX = df), ctx
  )
  expect_equal(res[["$max_exstdtc"]][[1L]], "2022-11-30")
})

test_that("min_date returns lexicographic minimum date string", {
  df  <- data.frame(EXSTDTC = c("2021-03-01","2022-11-30","2020-01-01"),
                    stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(EX = df), current_dataset = "EX")
  res <- herald:::.apply_operations(
    list(list(id = "$min_exstdtc", name = "EXSTDTC", operator = "min_date")),
    df, list(EX = df), ctx
  )
  expect_equal(res[["$min_exstdtc"]][[1L]], "2020-01-01")
})

# ---------- study_domains / dataset_names -------------------------------------

test_that("study_domains returns uppercase dataset names", {
  ctx <- mk_ctx(datasets = list(DM = data.frame(x=1), AE = data.frame(x=1)))
  df  <- ctx$datasets[["DM"]]
  res <- herald:::.apply_operations(
    list(list(id = "$dnames", operator = "study_domains")),
    df, ctx$datasets, ctx
  )
  vals <- unlist(res[["$dnames"]][[1L]])
  expect_setequal(vals, c("DM", "AE"))
})

# ---------- .apply_operations unknown op is logged ----------------------------

test_that(".apply_operations logs op_errors for unknown operator", {
  df  <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DS = df), current_dataset = "DS")
  res <- herald:::.apply_operations(
    list(list(id = "$fake", operator = "totally_made_up_op")),
    df, list(DS = df), ctx
  )
  expect_false("$fake" %in% names(res))
  kinds <- vapply(ctx$op_errors, function(e) e$kind, character(1))
  expect_true("unknown_operation" %in% kinds)
})

# ---------- Operations end-to-end via validate() -------------------------------

test_that("CORE-000272: domain_label operation fires when --CAT equals label", {
  lb <- data.frame(LBCAT = c("LABORATORY TEST RESULTS", "Chemistry"),
                   stringsAsFactors = FALSE)
  attr(lb, "label") <- "Laboratory Test Results"
  r <- validate(files = list(LB = lb), rules = "CORE-000272", quiet = TRUE)
  expect_equal(r$rules_applied, 1L)
  fired <- r$findings[r$findings$status == "fired", , drop = FALSE]
  expect_equal(nrow(fired), 1L)
  expect_equal(fired$row, 1L)
})

# ---------- prefix_is_not_contained_by ----------------------------------------

test_that("prefix_is_not_contained_by fires when prefix not in allowed set", {
  df <- data.frame(VARNAME = c("AESTDTC", "LBSTDTC"), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  res <- op_prefix_is_not_contained_by(df, ctx, name = "VARNAME", prefix = 2L,
                                        value = c("AE", "DM"))
  expect_false(res[[1L]])  # AE is allowed
  expect_true(res[[2L]])   # LB is not in c("AE","DM")
})

# ---------- has_same_values ----------------------------------------------------

test_that("has_same_values TRUE when all rows have same value", {
  df  <- data.frame(MHCAT = rep("MEDICAL HISTORY", 5L), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  res <- op_has_same_values(df, ctx, name = "MHCAT")
  expect_true(all(res))
})

test_that("has_same_values FALSE when values differ", {
  df  <- data.frame(MHCAT = c("HISTORY", "DIAGNOSIS"), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  res <- op_has_same_values(df, ctx, name = "MHCAT")
  expect_true(all(!res))
})

# ---------- target_is_not_sorted_by -------------------------------------------

test_that("target_is_not_sorted_by detects descending --SEQ within USUBJID", {
  df <- data.frame(
    USUBJID = c("S1","S1","S1"),
    AESEQ   = c(1L, 3L, 2L),   # not sorted
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx()
  res <- op_target_is_not_sorted_by(df, ctx, name = "AESEQ", order_by = "USUBJID")
  expect_false(res[[1L]])  # 1: OK (first row)
  expect_false(res[[2L]])  # 3 > 1: OK
  expect_true(res[[3L]])   # 2 < 3: not sorted
})

# ---------- inconsistent_enumerated_columns ------------------------------------

test_that("inconsistent_enumerated_columns fires when TSVAL gap exists", {
  df <- data.frame(
    TSVAL1 = c("A", NA, "B"),
    TSVAL2 = c("B", "X", NA),
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx()
  res <- op_inconsistent_enumerated_columns(df, ctx, name = "TSVAL")
  expect_false(res[[1L]])  # A -> B: no gap
  expect_true(res[[2L]])   # NA -> X: gap (TSVAL1 null, TSVAL2 non-null)
  expect_false(res[[3L]])  # B -> NA: fine (non-null -> null is OK)
})

# =============================================================================
# op registry metadata (.op_meta)
# =============================================================================

test_that(".op_meta() returns a tibble with all registered ops", {
  meta <- .op_meta()
  expect_s3_class(meta, "tbl_df")
  expect_true(all(c("iso8601", "matches_regex", "length_le", "contains")
                  %in% meta$name))
})

test_that(".op_meta(name) returns per-op metadata list", {
  iso <- .op_meta("iso8601")
  expect_equal(iso$name, "iso8601")
  expect_equal(iso$kind, "string")
  expect_match(iso$summary, "ISO 8601")
  expect_equal(iso$column_arg, "name")
  expect_true(iso$returns_na_ok)
  expect_true(!is.null(iso$arg_schema$name))
  expect_true(iso$arg_schema$name$required)
})

test_that("arg_schema defaults are filled in", {
  con <- .op_meta("contains")
  expect_false(con$returns_na_ok)
  expect_equal(con$arg_schema$ignore_case$default, FALSE)
})

test_that("registered_in records the source file (when available)", {
  # When devtools::load_all runs the sources, srcref is available
  iso <- .op_meta("iso8601")
  expect_true(is.na(iso$registered_in) || grepl("ops-string", iso$registered_in))
})

test_that(".get_op errors on unknown operator", {
  expect_error(.get_op("does_not_exist"), class = "herald_error_runtime")
})

test_that("metadata for all registered ops has required scalar shape", {
  all_meta <- .op_meta()
  expect_true(all(nzchar(all_meta$name)))
  expect_true(all(nzchar(all_meta$summary)))
  expect_true(all(all_meta$cost_hint %in% c("O(1)", "O(n)", "O(n log n)", "O(n*m)")))
})
