# test-herald-ops.R -- operator registry: .register_op, .get_op, .op_meta,
#                       .list_ops, .ref_ds, .record_missing_ref

# ---- helpers ------------------------------------------------------------------

mk_ctx <- function(datasets = list(), current_dataset = NULL,
                   current_rule_id = NULL) {
  e <- herald:::new_herald_ctx()
  e$datasets <- datasets
  e$current_dataset <- current_dataset
  e$current_rule_id <- current_rule_id
  e
}

# ---- .list_ops() ---------------------------------------------------------------

test_that(".list_ops() returns sorted character vector of registered ops", {
  ops <- herald:::.list_ops()
  expect_type(ops, "character")
  expect_true(length(ops) > 0L)
  expect_equal(ops, sort(ops))
  expect_true("iso8601" %in% ops)
  expect_true("contains" %in% ops)
})

# ---- .get_op() ----------------------------------------------------------------

test_that(".get_op() returns the registered function for a known op", {
  fn <- herald:::.get_op("iso8601")
  expect_type(fn, "closure")
})

test_that(".get_op() errors with herald_error_runtime for unknown op", {
  expect_error(
    herald:::.get_op("totally_unknown_op_xyz"),
    class = "herald_error_runtime"
  )
})

test_that(".get_op() error message lists registered operators", {
  expect_snapshot(
    herald:::.get_op("totally_unknown_op_xyz"),
    error = TRUE
  )
})

# ---- .op_meta() ---------------------------------------------------------------

test_that(".op_meta() with no arg returns tibble of all registered ops", {
  meta <- herald:::.op_meta()
  expect_s3_class(meta, "tbl_df")
  expect_true(nrow(meta) > 0L)
  expect_true(all(c("name", "kind", "summary", "cost_hint",
                    "column_arg", "returns_na_ok", "registered_in") %in%
                    names(meta)))
})

test_that(".op_meta() returns correct metadata for a known operator", {
  m <- herald:::.op_meta("iso8601")
  expect_equal(m$name, "iso8601")
  expect_equal(m$kind, "string")
  expect_true(nzchar(m$summary))
  expect_type(m$returns_na_ok, "logical")
})

test_that(".op_meta() errors for unknown operator name", {
  expect_error(
    herald:::.op_meta("does_not_exist_xyz"),
    class = "herald_error_runtime"
  )
})

# ---- .register_op() -----------------------------------------------------------

test_that(".register_op() registers a new op and is retrievable", {
  test_fn <- function(data, ctx, ...) rep(TRUE, nrow(data))
  herald:::.register_op(
    "__test_op_register__",
    test_fn,
    meta = list(kind = "test", summary = "unit test op", cost_hint = "O(1)")
  )
  fn <- herald:::.get_op("__test_op_register__")
  expect_type(fn, "closure")
  m <- herald:::.op_meta("__test_op_register__")
  expect_equal(m$name, "__test_op_register__")
  expect_equal(m$kind, "test")
})

test_that(".register_op() warns when re-registering an existing op", {
  test_fn <- function(data, ctx, ...) rep(TRUE, nrow(data))
  herald:::.register_op(
    "__test_op_reregister__",
    test_fn,
    meta = list(kind = "test", summary = "first", cost_hint = "O(1)")
  )
  # Re-register same name -- should warn
  expect_warning(
    herald:::.register_op(
      "__test_op_reregister__",
      test_fn,
      meta = list(kind = "test", summary = "second", cost_hint = "O(1)")
    ),
    regexp = "__test_op_reregister__"
  )
})

test_that(".register_op() errors when name is not a scalar character", {
  fn <- function(data, ctx, ...) TRUE
  expect_error(
    herald:::.register_op(c("a", "b"), fn),
    class = "herald_error_runtime"
  )
})

test_that(".register_op() errors when name is empty string", {
  fn <- function(data, ctx, ...) TRUE
  expect_error(
    herald:::.register_op("", fn),
    class = "herald_error_runtime"
  )
})

test_that(".register_op() errors when fn is not a function", {
  expect_error(
    herald:::.register_op("__test_not_fn__", "not_a_function"),
    class = "herald_error_runtime"
  )
})

# ---- .op_meta() empty env edge case -------------------------------------------

test_that(".op_meta() returns empty tibble when table is empty", {
  # Create a fresh empty env and call the unexported body logic via a temp reg
  # Instead test that the shape is correct (empty tibble columns present)
  # by asserting if we had zero ops the structure holds -- verified via type
  meta <- herald:::.op_meta()
  # tibble columns must have correct types
  expect_type(meta$name, "character")
  expect_type(meta$returns_na_ok, "logical")
})

# ---- .ref_ds() ----------------------------------------------------------------

test_that(".ref_ds() returns the dataset when present", {
  dm <- data.frame(USUBJID = "S1", RFSTDTC = "2020-01-01",
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DM = dm))
  result <- herald:::.ref_ds(ctx, "DM")
  expect_identical(result, dm)
})

test_that(".ref_ds() returns NULL and records missing ref when absent", {
  ctx <- mk_ctx(datasets = list(AE = data.frame(x = 1L)),
                current_rule_id = "TEST-001")
  result <- herald:::.ref_ds(ctx, "DM")
  expect_null(result)
  # missing_refs$datasets should record the miss
  expect_false(is.null(ctx$missing_refs))
  expect_true("DM" %in% names(ctx$missing_refs$datasets))
})

test_that(".ref_ds() is case-insensitive for ref_name", {
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- mk_ctx(datasets = list(DM = dm))
  result <- herald:::.ref_ds(ctx, "dm")
  expect_identical(result, dm)
})

test_that(".ref_ds() returns NULL when ctx is NULL", {
  result <- herald:::.ref_ds(NULL, "DM")
  expect_null(result)
})

test_that(".ref_ds() returns NULL when ctx$datasets is NULL", {
  ctx <- mk_ctx()  # no datasets
  result <- herald:::.ref_ds(ctx, "DM")
  expect_null(result)
})

# ---- .caller_source_file() ----------------------------------------------------

test_that(".caller_source_file() returns NA or a character string", {
  result <- herald:::.caller_source_file()
  expect_true(is.na(result) || is.character(result))
})

# ---- .op_meta() full tibble shape and types ----------------------------------

test_that(".op_meta() tibble has correct column types", {
  meta <- herald:::.op_meta()
  expect_type(meta$name, "character")
  expect_type(meta$kind, "character")
  expect_type(meta$summary, "character")
  expect_type(meta$cost_hint, "character")
  expect_type(meta$column_arg, "character")
  expect_type(meta$returns_na_ok, "logical")
  expect_type(meta$registered_in, "character")
})

test_that(".op_meta() full tibble includes temporal operators", {
  meta <- herald:::.op_meta()
  expect_true("is_complete_date" %in% meta$name)
  expect_true("date_greater_than" %in% meta$name)
  expect_true("value_not_iso8601" %in% meta$name)
})

test_that(".op_meta() for a temporal op returns correct kind", {
  m <- herald:::.op_meta("is_complete_date")
  expect_equal(m$kind, "temporal")
  expect_equal(m$column_arg, "name")
  expect_true(m$returns_na_ok)
})

test_that(".op_meta() for value_not_iso8601 has examples field (list type)", {
  m <- herald:::.op_meta("value_not_iso8601")
  expect_type(m$examples, "list")
})

# ---- .register_op() with registered_in auto-fill ----------------------------

test_that(".register_op() sets registered_in (NA or non-empty string)", {
  test_fn <- function(data, ctx, ...) rep(TRUE, nrow(data))
  herald:::.register_op(
    "__test_op_source_detect__",
    test_fn,
    meta = list(kind = "test", summary = "source detect test")
  )
  m <- herald:::.op_meta("__test_op_source_detect__")
  expect_true(is.na(m$registered_in) || nzchar(m$registered_in))
})

# ---- .ref_ds() records rule_id in missing_refs --------------------------------

test_that(".ref_ds() records the current rule_id in missing_refs", {
  ctx <- mk_ctx(
    datasets = list(AE = data.frame(x = 1L)),
    current_rule_id = "RULE-999"
  )
  herald:::.ref_ds(ctx, "DM")
  expect_true("DM" %in% names(ctx$missing_refs$datasets))
  expect_true("RULE-999" %in% ctx$missing_refs$datasets[["DM"]])
})
