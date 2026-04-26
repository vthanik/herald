# test-rules-operations.R -- .apply_operations and .stamp_op_result

# ---- helpers ------------------------------------------------------------------

mk_ctx <- function(datasets = list(), current_dataset = NULL) {
  e <- herald:::new_herald_ctx()
  e$datasets <- datasets
  e$current_dataset <- current_dataset
  e
}

# ---- .apply_operations() early-return paths -----------------------------------

test_that(".apply_operations() returns data unchanged when rule_ops is NULL", {
  df <- data.frame(x = 1:3, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  result <- herald:::.apply_operations(NULL, df, list(), ctx)
  expect_identical(result, df)
})

test_that(".apply_operations() returns data unchanged when rule_ops is empty", {
  df <- data.frame(x = 1:3, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  result <- herald:::.apply_operations(list(), df, list(), ctx)
  expect_identical(result, df)
})

test_that(".apply_operations() returns data unchanged when data is not a data.frame", {
  ctx <- mk_ctx()
  result <- herald:::.apply_operations(
    list(list(id = "$x", operator = "record_count")),
    "not_a_dataframe",
    list(),
    ctx
  )
  expect_equal(result, "not_a_dataframe")
})

test_that(".apply_operations() returns data unchanged when nrow(data) == 0", {
  df <- data.frame(x = character(0), stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  result <- herald:::.apply_operations(
    list(list(id = "$n", operator = "record_count")),
    df,
    list(),
    ctx
  )
  expect_identical(result, df)
  expect_false("$n" %in% names(result))
})

# ---- op entry validation: skip when id or operator is missing ----------------

test_that(".apply_operations() skips entry with missing id", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  # No id field -- should skip silently
  result <- herald:::.apply_operations(
    list(list(operator = "record_count")),
    df,
    list(),
    ctx
  )
  # No new column should appear
  expect_equal(names(result), names(df))
})

test_that(".apply_operations() skips entry with missing operator", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  result <- herald:::.apply_operations(
    list(list(id = "$n")),
    df,
    list(),
    ctx
  )
  expect_equal(names(result), names(df))
})

# ---- unknown operator logging -------------------------------------------------

test_that(".apply_operations() logs unknown_operation error for bad operator", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  result <- herald:::.apply_operations(
    list(list(id = "$bad", operator = "nonexistent_op_xyz")),
    df,
    list(),
    ctx
  )
  expect_false("$bad" %in% names(result))
  kinds <- vapply(ctx$op_errors, function(e) e$kind, character(1L))
  expect_true("unknown_operation" %in% kinds)
  ops <- vapply(ctx$op_errors, function(e) e$operator, character(1L))
  expect_true("nonexistent_op_xyz" %in% ops)
})

test_that(".apply_operations() does not crash when ctx is NULL and op unknown", {
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  # ctx = NULL -- should not error, just skip
  expect_no_error(
    herald:::.apply_operations(
      list(list(id = "$bad", operator = "nonexistent_op_xyz")),
      df,
      list(),
      NULL
    )
  )
})

# ---- successful operation: scalar result -------------------------------------

test_that(".apply_operations() stamps scalar result as recycled column", {
  df <- data.frame(x = 1:4, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DS = df), current_dataset = "DS")
  result <- herald:::.apply_operations(
    list(list(id = "$n_rows", operator = "record_count")),
    df,
    list(DS = df),
    ctx
  )
  expect_true("$n_rows" %in% names(result))
  expect_equal(unique(result[["$n_rows"]]), 4L)
  expect_equal(length(result[["$n_rows"]]), 4L)
})

# ---- successful operation: vector result (dy) --------------------------------

test_that(".apply_operations() stamps per-row vector result (dy)", {
  dm <- data.frame(
    USUBJID = "S1",
    RFSTDTC = "2020-01-01",
    stringsAsFactors = FALSE
  )
  ae <- data.frame(
    USUBJID = c("S1", "S1"),
    AESTDTC = c("2020-01-01", "2020-01-03"),
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx(datasets = list(DM = dm, AE = ae), current_dataset = "AE")
  result <- herald:::.apply_operations(
    list(list(id = "$dy", name = "AESTDTC", operator = "dy")),
    ae,
    list(DM = dm, AE = ae),
    ctx
  )
  expect_true("$dy" %in% names(result))
  expect_equal(result[["$dy"]], c(1L, 3L))
})

# ---- successful operation: array result (list-column) ------------------------

test_that(".apply_operations() stamps array result as list-column", {
  df <- data.frame(
    DOMAIN = c("AE", "LB", "AE"),
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx(datasets = list(DS = df), current_dataset = "DS")
  result <- herald:::.apply_operations(
    list(list(id = "$domains", name = "DOMAIN", operator = "distinct")),
    df,
    list(DS = df),
    ctx
  )
  expect_true("$domains" %in% names(result))
  # Array result: each row holds the same list value
  col <- result[["$domains"]]
  expect_type(col, "list")
  expect_setequal(unlist(col[[1L]]), c("AE", "LB"))
})

# ---- operation caches result in ctx$op_results --------------------------------

test_that(".apply_operations() caches result in ctx$op_results", {
  df <- data.frame(x = 1:3, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DS = df), current_dataset = "DS")
  herald:::.apply_operations(
    list(list(id = "$n", operator = "record_count")),
    df,
    list(DS = df),
    ctx
  )
  expect_false(is.null(ctx$op_results))
  expect_true("$n" %in% names(ctx$op_results))
  expect_equal(ctx$op_results[["$n"]], 3L)
})

# ---- domain override: op_entry$domain routes to different dataset -------------

test_that(".apply_operations() routes to domain dataset when domain is set", {
  # EX has 7 rows, AE has 2 rows; ask record_count against EX from AE data
  ex <- data.frame(x = seq_len(7L), stringsAsFactors = FALSE)
  ae <- data.frame(y = 1:2, stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(EX = ex, AE = ae), current_dataset = "AE")
  result <- herald:::.apply_operations(
    list(list(id = "$ex_count", operator = "record_count", domain = "EX")),
    ae,
    list(EX = ex, AE = ae),
    ctx
  )
  expect_true("$ex_count" %in% names(result))
  # Should be 7 (EX rows), stamped on ae rows (length 2)
  expect_equal(unique(result[["$ex_count"]]), 7L)
})

# ---- operation error is caught and logged ------------------------------------

test_that(".apply_operations() catches operation errors and logs them", {
  # Register a deliberately failing operation
  herald:::.register_operation(
    "__fail_op__",
    function(data, ctx, params) stop("forced failure"),
    meta = list(kind = "cross", summary = "always fails", cost_hint = "O(1)")
  )

  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  ctx <- mk_ctx()
  result <- herald:::.apply_operations(
    list(list(id = "$fail", operator = "__fail_op__")),
    df,
    list(),
    ctx
  )
  expect_false("$fail" %in% names(result))
  kinds <- vapply(ctx$op_errors, function(e) e$kind, character(1L))
  expect_true("operation_error" %in% kinds)
  msgs <- vapply(ctx$op_errors, function(e) e$message %||% "", character(1L))
  expect_true(any(grepl("forced failure", msgs)))
})

test_that(".apply_operations() handles operation error with NULL ctx gracefully", {
  herald:::.register_operation(
    "__fail_op_null_ctx__",
    function(data, ctx, params) stop("another forced failure"),
    meta = list(kind = "cross", summary = "always fails", cost_hint = "O(1)")
  )
  df <- data.frame(x = 1L, stringsAsFactors = FALSE)
  expect_no_error(
    herald:::.apply_operations(
      list(list(id = "$fail", operator = "__fail_op_null_ctx__")),
      df,
      list(),
      NULL
    )
  )
})

# ---- multiple operations in one call -----------------------------------------

test_that(".apply_operations() processes multiple operations sequentially", {
  df <- data.frame(
    DOMAIN = c("AE", "AE", "LB"),
    EXSTDTC = c("2020-01-01", "2021-06-15", "2019-12-31"),
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx(datasets = list(DS = df), current_dataset = "DS")
  result <- herald:::.apply_operations(
    list(
      list(id = "$n", operator = "record_count"),
      list(id = "$max_dt", name = "EXSTDTC", operator = "max_date")
    ),
    df,
    list(DS = df),
    ctx
  )
  expect_true("$n" %in% names(result))
  expect_true("$max_dt" %in% names(result))
  expect_equal(unique(result[["$n"]]), 3L)
  expect_equal(unique(result[["$max_dt"]]), "2021-06-15")
})

# ---- ctx with NULL op_results: exercises initialization branch ---------------

test_that(".apply_operations() initializes ctx$op_results when NULL", {
  df <- data.frame(x = 1:2, stringsAsFactors = FALSE)
  # Build a raw environment without the pre-initialized op_results
  ctx <- new.env(parent = emptyenv())
  ctx$op_errors <- list()
  ctx$op_cache <- new.env(parent = emptyenv())
  # op_results intentionally left NULL
  ctx$op_results <- NULL
  ctx$datasets <- list(DS = df)
  ctx$current_dataset <- "DS"
  result <- herald:::.apply_operations(
    list(list(id = "$n", operator = "record_count")),
    df,
    list(DS = df),
    ctx
  )
  expect_false(is.null(ctx$op_results))
  expect_true("$n" %in% names(ctx$op_results))
})

# ---- .stamp_op_result() -------------------------------------------------------

test_that(".stamp_op_result() recycles scalar to all rows", {
  df <- data.frame(x = 1:3, stringsAsFactors = FALSE)
  result <- herald:::.stamp_op_result(df, "$val", 42L, 3L)
  expect_equal(result[["$val"]], c(42L, 42L, 42L))
})

test_that(".stamp_op_result() assigns vector of length n row-wise", {
  df <- data.frame(x = 1:3, stringsAsFactors = FALSE)
  result <- herald:::.stamp_op_result(df, "$v", c(10L, 20L, 30L), 3L)
  expect_equal(result[["$v"]], c(10L, 20L, 30L))
})

test_that(".stamp_op_result() creates list-column for array result", {
  df <- data.frame(x = 1:3, stringsAsFactors = FALSE)
  arr <- c("AE", "LB", "DM", "VS") # length 4 != 3 (n)
  result <- herald:::.stamp_op_result(df, "$arr", arr, 3L)
  col <- result[["$arr"]]
  expect_type(col, "list")
  expect_length(col, 3L)
  expect_equal(col[[1L]], arr)
  expect_equal(col[[2L]], arr)
})
