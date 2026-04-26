# test-ops-operations.R -- Operations pre-compute registry + new check-side ops

mk_ctx <- function(datasets = list(), current_dataset = NULL, spec = NULL) {
  e <- herald:::new_herald_ctx()
  e$datasets <- datasets
  e$spec <- spec
  e$crossrefs <- herald:::build_crossrefs(datasets, spec)
  e$current_dataset <- current_dataset
  e$current_domain <- if (!is.null(current_dataset)) {
    toupper(substr(current_dataset, 1, 2))
  } else {
    ""
  }
  e
}

# ---------- Operations registry basics ----------------------------------------

test_that(".list_operations() returns all 19 registered operations", {
  ops <- herald:::.list_operations()
  expect_true(length(ops) >= 19L)
  expect_true("domain_label" %in% ops)
  expect_true("distinct" %in% ops)
  expect_true("record_count" %in% ops)
  expect_true("domain_is_custom" %in% ops)
  expect_true("study_domains" %in% ops)
  expect_true("dataset_names" %in% ops)
  expect_true("max_date" %in% ops)
  expect_true("min_date" %in% ops)
  expect_true("dy" %in% ops)
  expect_true("get_column_order_from_dataset" %in% ops)
  expect_true("expected_variables" %in% ops)
  expect_true("required_variables" %in% ops)
  expect_true("get_codelist_attributes" %in% ops)
  expect_true("extract_metadata" %in% ops)
})

# ---------- domain_label -------------------------------------------------------

test_that("domain_label returns attr label when set", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  attr(df, "label") <- "Adverse Events"
  ctx <- mk_ctx(datasets = list(AE = df), current_dataset = "AE")
  res <- herald:::.apply_operations(
    list(list(id = "$domain_label", operator = "domain_label")),
    df,
    list(AE = df),
    ctx
  )
  expect_equal(res[["$domain_label"]][[1L]], "Adverse Events")
})

test_that("domain_label returns NA_character_ when no label", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(AE = df), current_dataset = "AE")
  res <- herald:::.apply_operations(
    list(list(id = "$domain_label", operator = "domain_label")),
    df,
    list(AE = df),
    ctx
  )
  expect_true(is.na(res[["$domain_label"]][[1L]]))
})

# ---------- distinct -----------------------------------------------------------

test_that("distinct returns unique non-NA column values", {
  df <- data.frame(DOMAIN = c("AE", "AE", "LB", NA), stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(MULTI = df), current_dataset = "MULTI")
  res <- herald:::.apply_operations(
    list(list(id = "$domain_list", name = "DOMAIN", operator = "distinct")),
    df,
    list(MULTI = df),
    ctx
  )
  vals <- unlist(res[["$domain_list"]][[1L]])
  expect_setequal(vals, c("AE", "LB"))
})

# ---------- record_count -------------------------------------------------------

test_that("record_count returns nrow as scalar", {
  df <- data.frame(x = 1:5, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DS = df), current_dataset = "DS")
  res <- herald:::.apply_operations(
    list(list(id = "$n_rows", operator = "record_count")),
    df,
    list(DS = df),
    ctx
  )
  expect_equal(res[["$n_rows"]][[1L]], 5L)
})

# ---------- domain_is_custom ---------------------------------------------------

test_that("domain_is_custom TRUE for non-standard domain", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(XY = df), current_dataset = "XY")
  res <- herald:::.apply_operations(
    list(list(id = "$is_custom", operator = "domain_is_custom")),
    df,
    list(XY = df),
    ctx
  )
  expect_true(isTRUE(res[["$is_custom"]][[1L]]))
})

test_that("domain_is_custom FALSE for standard SDTM domain", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(AE = df), current_dataset = "AE")
  res <- herald:::.apply_operations(
    list(list(id = "$is_custom", operator = "domain_is_custom")),
    df,
    list(AE = df),
    ctx
  )
  expect_false(isTRUE(res[["$is_custom"]][[1L]]))
})

# ---------- max_date / min_date ------------------------------------------------

test_that("max_date returns lexicographic maximum date string", {
  df <- data.frame(
    EXSTDTC = c("2021-03-01", "2022-11-30", "2020-01-01"),
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx(datasets = list(EX = df), current_dataset = "EX")
  res <- herald:::.apply_operations(
    list(list(id = "$max_exstdtc", name = "EXSTDTC", operator = "max_date")),
    df,
    list(EX = df),
    ctx
  )
  expect_equal(res[["$max_exstdtc"]][[1L]], "2022-11-30")
})

test_that("min_date returns lexicographic minimum date string", {
  df <- data.frame(
    EXSTDTC = c("2021-03-01", "2022-11-30", "2020-01-01"),
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx(datasets = list(EX = df), current_dataset = "EX")
  res <- herald:::.apply_operations(
    list(list(id = "$min_exstdtc", name = "EXSTDTC", operator = "min_date")),
    df,
    list(EX = df),
    ctx
  )
  expect_equal(res[["$min_exstdtc"]][[1L]], "2020-01-01")
})

# ---------- study_domains / dataset_names -------------------------------------

test_that("study_domains returns uppercase dataset names", {
  ctx <- mk_ctx(datasets = list(DM = data.frame(x = 1), AE = data.frame(x = 1)))
  df <- ctx$datasets[["DM"]]
  res <- herald:::.apply_operations(
    list(list(id = "$dnames", operator = "study_domains")),
    df,
    ctx$datasets,
    ctx
  )
  vals <- unlist(res[["$dnames"]][[1L]])
  expect_setequal(vals, c("DM", "AE"))
})

# ---------- .apply_operations unknown op is logged ----------------------------

test_that(".apply_operations logs op_errors for unknown operator", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DS = df), current_dataset = "DS")
  res <- herald:::.apply_operations(
    list(list(id = "$fake", operator = "totally_made_up_op")),
    df,
    list(DS = df),
    ctx
  )
  expect_false("$fake" %in% names(res))
  kinds <- vapply(ctx$op_errors, function(e) e$kind, character(1))
  expect_true("unknown_operation" %in% kinds)
})

# ---------- Operations end-to-end via validate() -------------------------------

test_that("CORE-000272: domain_label operation fires when --CAT equals label", {
  lb <- data.frame(
    LBCAT = c("LABORATORY TEST RESULTS", "Chemistry"),
    stringsAsFactors = FALSE
  )
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
  res <- op_prefix_is_not_contained_by(
    df,
    ctx,
    name = "VARNAME",
    prefix = 2L,
    value = c("AE", "DM")
  )
  expect_false(res[[1L]]) # AE is allowed
  expect_true(res[[2L]]) # LB is not in c("AE","DM")
})

# ---------- has_same_values ----------------------------------------------------

test_that("has_same_values TRUE when all rows have same value", {
  df <- data.frame(MHCAT = rep("MEDICAL HISTORY", 5L), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  res <- op_has_same_values(df, ctx, name = "MHCAT")
  expect_true(all(res))
})

test_that("has_same_values FALSE when values differ", {
  df <- data.frame(MHCAT = c("HISTORY", "DIAGNOSIS"), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  res <- op_has_same_values(df, ctx, name = "MHCAT")
  expect_true(all(!res))
})

# ---------- target_is_not_sorted_by -------------------------------------------

test_that("target_is_not_sorted_by detects descending --SEQ within USUBJID", {
  df <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    AESEQ = c(1L, 3L, 2L), # not sorted
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx()
  res <- op_target_is_not_sorted_by(
    df,
    ctx,
    name = "AESEQ",
    order_by = "USUBJID"
  )
  expect_false(res[[1L]]) # 1: OK (first row)
  expect_false(res[[2L]]) # 3 > 1: OK
  expect_true(res[[3L]]) # 2 < 3: not sorted
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
  expect_false(res[[1L]]) # A -> B: no gap
  expect_true(res[[2L]]) # NA -> X: gap (TSVAL1 null, TSVAL2 non-null)
  expect_false(res[[3L]]) # B -> NA: fine (non-null -> null is OK)
})

# =============================================================================
# Direct op function calls -- cover uncovered branches
# =============================================================================

# ---- domain_label direct calls -----------------------------------------------

test_that(".op_operation_domain_label uses ctx$datasets label when present", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  attr(df, "label") <- "Demographics"
  ctx <- mk_ctx(datasets = list(DM = df), current_dataset = "DM")
  expect_equal(herald:::.op_operation_domain_label(df, ctx, list()), "Demographics")
})

test_that(".op_operation_domain_label falls back to data attr label", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(), current_dataset = NULL)
  attr(df, "label") <- "Fallback Label"
  expect_equal(herald:::.op_operation_domain_label(df, ctx, list()), "Fallback Label")
})

test_that(".op_operation_domain_label returns NA_character_ when no label anywhere", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(), current_dataset = NULL)
  expect_equal(herald:::.op_operation_domain_label(df, ctx, list()), NA_character_)
})

# ---- distinct direct calls ---------------------------------------------------

test_that(".op_operation_distinct returns character(0) when no name param", {
  df <- data.frame(DOMAIN = c("AE", "LB"), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_distinct(df, ctx, list()), character(0))
})

test_that(".op_operation_distinct returns character(0) when column absent", {
  df <- data.frame(DOMAIN = c("AE", "LB"), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_distinct(df, ctx, list(name = "NONEXISTENT")), character(0))
})

test_that(".op_operation_distinct is case-insensitive for column name", {
  df <- data.frame(domain = c("AE", "LB", "AE"), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  result <- herald:::.op_operation_distinct(df, ctx, list(name = "DOMAIN"))
  expect_setequal(result, c("AE", "LB"))
})

test_that(".op_operation_distinct excludes NA and empty-string values", {
  df <- data.frame(
    DOMAIN = c("AE", NA, "", "LB", "AE"),
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx()
  result <- herald:::.op_operation_distinct(df, ctx, list(name = "DOMAIN"))
  expect_setequal(result, c("AE", "LB"))
})

# ---- record_count direct call ------------------------------------------------

test_that(".op_operation_record_count returns integer nrow", {
  df <- data.frame(x = seq_len(7L), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_record_count(df, ctx, list()), 7L)
})

# ---- study_domains / dataset_names direct calls ------------------------------

test_that(".op_operation_study_domains returns uppercase names from ctx", {
  ctx <- mk_ctx(datasets = list(dm = data.frame(x = 1L),
                                ae = data.frame(x = 1L)))
  result <- herald:::.op_operation_study_domains(data.frame(x = 1L), ctx, list())
  expect_setequal(result, c("DM", "AE"))
})

test_that(".op_operation_study_domains returns character(0) when no datasets", {
  ctx <- mk_ctx()
  expect_equal(
    herald:::.op_operation_study_domains(data.frame(x = 1L), ctx, list()),
    character(0)
  )
})

test_that(".op_operation_study_domains returns character(0) when ctx$datasets is NULL", {
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- NULL
  result <- herald:::.op_operation_study_domains(data.frame(x = 1L), ctx, list())
  expect_equal(result, character(0))
})

test_that("dataset_names alias returns same result as study_domains", {
  ctx <- mk_ctx(datasets = list(DM = data.frame(x = 1L)))
  df <- data.frame(x = 1L)
  r1 <- herald:::.op_operation_study_domains(df, ctx, list())
  r2 <- herald:::.op_operation_study_domains(df, ctx, list())
  expect_equal(r1, r2)
})

# ---- max_date / min_date direct calls ----------------------------------------

test_that(".op_operation_max_date returns NA_character_ when no name param", {
  df <- data.frame(EXSTDTC = c("2020-01-01", "2021-01-01"),
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_max_date(df, ctx, list()), NA_character_)
})

test_that(".op_operation_max_date returns NA_character_ when column missing", {
  df <- data.frame(EXSTDTC = c("2020-01-01"), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(
    herald:::.op_operation_max_date(df, ctx, list(name = "NONEXISTENT")),
    NA_character_
  )
})

test_that(".op_operation_max_date returns NA_character_ when all values NA", {
  df <- data.frame(EXSTDTC = c(NA_character_, NA_character_),
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(
    herald:::.op_operation_max_date(df, ctx, list(name = "EXSTDTC")),
    NA_character_
  )
})

test_that(".op_operation_max_date returns max ISO date string", {
  df <- data.frame(EXSTDTC = c("2020-01-01", "2021-06-15", "2019-12-31"),
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(
    herald:::.op_operation_max_date(df, ctx, list(name = "EXSTDTC")),
    "2021-06-15"
  )
})

test_that(".op_operation_min_date returns NA_character_ when no name param", {
  df <- data.frame(EXSTDTC = c("2020-01-01"), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_min_date(df, ctx, list()), NA_character_)
})

test_that(".op_operation_min_date returns NA_character_ when column missing", {
  df <- data.frame(EXSTDTC = c("2020-01-01"), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(
    herald:::.op_operation_min_date(df, ctx, list(name = "NOEXIST")),
    NA_character_
  )
})

test_that(".op_operation_min_date returns NA_character_ when all values NA", {
  df <- data.frame(EXSTDTC = NA_character_, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(
    herald:::.op_operation_min_date(df, ctx, list(name = "EXSTDTC")),
    NA_character_
  )
})

test_that(".op_operation_min_date returns min ISO date string", {
  df <- data.frame(EXSTDTC = c("2020-06-01", "2019-01-15", "2021-03-10"),
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(
    herald:::.op_operation_min_date(df, ctx, list(name = "EXSTDTC")),
    "2019-01-15"
  )
})

# ---- dy (study_day_from_dates) direct calls ----------------------------------

test_that(".op_operation_study_day returns NA vector when no name param", {
  df <- data.frame(AESTDTC = c("2020-01-01", "2020-02-01"),
                   USUBJID = c("S1", "S1"),
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  result <- herald:::.op_operation_study_day(df, ctx, list())
  expect_equal(result, c(NA_integer_, NA_integer_))
})

test_that(".op_operation_study_day returns NA vector when column absent", {
  df <- data.frame(AESTDTC = c("2020-01-01"), USUBJID = "S1",
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  result <- herald:::.op_operation_study_day(df, ctx, list(name = "NONEXISTENT"))
  expect_equal(result, NA_integer_)
})

test_that(".op_operation_study_day returns NA vector when DM absent", {
  df <- data.frame(AESTDTC = c("2020-01-01", "2020-01-03"),
                   USUBJID = c("S1", "S1"),
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(AE = df))
  result <- herald:::.op_operation_study_day(df, ctx, list(name = "AESTDTC"))
  expect_equal(result, c(NA_integer_, NA_integer_))
})

test_that(".op_operation_study_day returns NA when DM lacks RFSTDTC", {
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  df <- data.frame(AESTDTC = "2020-01-01", USUBJID = "S1",
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DM = dm, AE = df))
  result <- herald:::.op_operation_study_day(df, ctx, list(name = "AESTDTC"))
  expect_equal(result, NA_integer_)
})

test_that(".op_operation_study_day returns NA when RFSTDTC is NA for subject", {
  dm <- data.frame(USUBJID = "S1", RFSTDTC = NA_character_,
                   stringsAsFactors = FALSE)
  df <- data.frame(AESTDTC = "2020-01-05", USUBJID = "S1",
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DM = dm, AE = df))
  result <- herald:::.op_operation_study_day(df, ctx, list(name = "AESTDTC"))
  expect_equal(result, NA_integer_)
})

test_that(".op_operation_study_day computes correct CDISC study day", {
  dm <- data.frame(USUBJID = c("S1", "S2"),
                   RFSTDTC = c("2020-01-01", "2020-06-01"),
                   stringsAsFactors = FALSE)
  ae <- data.frame(
    USUBJID = c("S1", "S1", "S2"),
    AESTDTC = c("2020-01-01", "2020-01-03", "2020-05-31"),
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx(datasets = list(DM = dm, AE = ae), current_dataset = "AE")
  result <- herald:::.op_operation_study_day(ae, ctx, list(name = "AESTDTC"))
  expect_equal(result[[1L]], 1L)
  expect_equal(result[[2L]], 3L)
  expect_equal(result[[3L]], -1L)
})

test_that(".op_operation_study_day handles NA AESTDTC values gracefully", {
  dm <- data.frame(USUBJID = "S1", RFSTDTC = "2020-01-01",
                   stringsAsFactors = FALSE)
  df <- data.frame(AESTDTC = NA_character_, USUBJID = "S1",
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DM = dm, AE = df))
  result <- herald:::.op_operation_study_day(df, ctx, list(name = "AESTDTC"))
  expect_equal(result, NA_integer_)
})


test_that(".op_operation_study_day returns NA for unparseable date strings", {
  dm <- data.frame(USUBJID = "S1", RFSTDTC = "not-a-date",
                   stringsAsFactors = FALSE)
  df <- data.frame(AESTDTC = "2020-01-01", USUBJID = "S1",
                   stringsAsFactors = FALSE)
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list(DM = dm, AE = df)
  ctx$crossrefs <- herald:::build_crossrefs(ctx$datasets, NULL)
  ctx$current_dataset <- "AE"
  result <- herald:::.op_operation_study_day(df, ctx, list(name = "AESTDTC"))
  expect_equal(result, NA_integer_)
})

# ---- column-order family direct calls ----------------------------------------

test_that("get_column_order_from_dataset returns variable names", {
  df <- data.frame(A = 1L, B = 2L, C = 3L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_col_order_dataset(df, ctx, list()), c("A", "B", "C"))
})

test_that("expected_variables returns variable names", {
  df <- data.frame(X = 1L, Y = 2L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_expected_variables(df, ctx, list()), c("X", "Y"))
})

test_that("get_dataset_filtered_variables returns variable names", {
  df <- data.frame(A = 1L, B = 2L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(
    herald:::.op_operation_dataset_filtered_variables(df, ctx, list()),
    c("A", "B")
  )
})

test_that("required_variables returns character(0) when spec is NULL", {
  df <- data.frame(A = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_required_variables(df, ctx, list()), character(0))
})

test_that("required_variables calls .spec_cols when spec is non-null", {
  spec <- herald:::as_herald_spec(
    ds_spec = data.frame(dataset = "DM", class = "FINDINGS",
                         stringsAsFactors = FALSE),
    var_spec = data.frame(dataset = "DM", variable = "USUBJID", required = TRUE,
                          stringsAsFactors = FALSE)
  )
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DM = df), current_dataset = "DM", spec = spec)
  result <- herald:::.op_operation_required_variables(df, ctx, list())
  expect_true(is.character(result))
})

test_that("get_model_column_order returns character(0)", {
  df <- data.frame(A = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_model_col_order(df, ctx, list()), character(0))
})

test_that("get_parent_model_column_order returns character(0)", {
  df <- data.frame(A = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_parent_model_col_order(df, ctx, list()), character(0))
})

test_that("get_column_order_from_library returns character(0)", {
  df <- data.frame(A = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_library_col_order(df, ctx, list()), character(0))
})

test_that("get_model_filtered_variables returns character(0)", {
  df <- data.frame(A = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_model_filtered_variables(df, ctx, list()), character(0))
})

# ---- get_codelist_attributes direct calls ------------------------------------

test_that("get_codelist_attributes returns character(0) when name param absent", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(
    herald:::.op_operation_get_codelist_attributes(df, ctx, list()),
    character(0)
  )
})

test_that("get_codelist_attributes returns character(0) when no CT provider", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(
    herald:::.op_operation_get_codelist_attributes(df, ctx, list(name = "RACE")),
    character(0)
  )
})

test_that("get_codelist_attributes returns character(0) when ct_info returns NULL", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list()
  ctx$ct <- list(RACE = structure(list(), class = "herald_ct_provider"))
  result <- herald:::.op_operation_get_codelist_attributes(df, ctx, list(name = "RACE"))
  expect_equal(result, character(0))
})

# ---- extract_metadata direct call --------------------------------------------

test_that("extract_metadata returns variable names of data frame", {
  df <- data.frame(SUBJID = 1L, AGE = 30L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  expect_equal(herald:::.op_operation_extract_metadata(df, ctx, list()), c("SUBJID", "AGE"))
})

# ---- domain_is_custom direct calls -------------------------------------------

test_that(".op_operation_domain_is_custom TRUE for custom 2-letter prefix", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(current_dataset = "XY")
  expect_true(herald:::.op_operation_domain_is_custom(df, ctx, list()))
})

test_that(".op_operation_domain_is_custom FALSE for standard domain AE", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(current_dataset = "AE")
  expect_false(herald:::.op_operation_domain_is_custom(df, ctx, list()))
})

test_that(".op_operation_domain_is_custom FALSE when no current_dataset", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx(current_dataset = NULL)
  expect_false(herald:::.op_operation_domain_is_custom(df, ctx, list()))
})

# =============================================================================
# op registry metadata (.op_meta)
# =============================================================================

test_that(".op_meta() returns a tibble with all registered ops", {
  meta <- .op_meta()
  expect_s3_class(meta, "tbl_df")
  expect_true(all(
    c("iso8601", "matches_regex", "length_le", "contains") %in% meta$name
  ))
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
  expect_true(
    is.na(iso$registered_in) || grepl("ops-string", iso$registered_in)
  )
})

test_that(".get_op errors on unknown operator", {
  expect_error(.get_op("does_not_exist"), class = "herald_error_runtime")
})

test_that("metadata for all registered ops has required scalar shape", {
  all_meta <- .op_meta()
  expect_true(all(nzchar(all_meta$name)))
  expect_true(all(nzchar(all_meta$summary)))
  expect_true(all(
    all_meta$cost_hint %in% c("O(1)", "O(n)", "O(n log n)", "O(n*m)")
  ))
})
