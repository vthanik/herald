# test-herald-operations.R -- Operations pre-compute registry:
#   .register_operation, .get_operation, .list_operations

# ---- .list_operations() -------------------------------------------------------

test_that(".list_operations() returns sorted character vector", {
  ops <- herald:::.list_operations()
  expect_type(ops, "character")
  expect_true(length(ops) > 0L)
  expect_equal(ops, sort(ops))
  expect_true("distinct" %in% ops)
  expect_true("record_count" %in% ops)
  expect_true("domain_label" %in% ops)
})

# ---- .get_operation() ---------------------------------------------------------

test_that(".get_operation() returns function for known operation", {
  fn <- herald:::.get_operation("distinct")
  expect_type(fn, "closure")
})

test_that(".get_operation() returns NULL for unknown operation", {
  result <- herald:::.get_operation("totally_unknown_op_xyz")
  expect_null(result)
})

# ---- .register_operation() ----------------------------------------------------

test_that(".register_operation() registers and retrieves a new operation", {
  test_fn <- function(data, ctx, params) nrow(data)
  herald:::.register_operation(
    "__test_operation_reg__",
    test_fn,
    meta = list(kind = "cross", summary = "test op", returns = "scalar",
                cost_hint = "O(1)")
  )
  fn <- herald:::.get_operation("__test_operation_reg__")
  expect_type(fn, "closure")
  expect_true("__test_operation_reg__" %in% herald:::.list_operations())
})

test_that(".register_operation() warns on re-registration", {
  test_fn <- function(data, ctx, params) nrow(data)
  herald:::.register_operation(
    "__test_operation_rereg__",
    test_fn,
    meta = list(kind = "cross", summary = "first", cost_hint = "O(1)")
  )
  expect_warning(
    herald:::.register_operation(
      "__test_operation_rereg__",
      test_fn,
      meta = list(kind = "cross", summary = "second", cost_hint = "O(1)")
    ),
    regexp = "__test_operation_rereg__"
  )
})

test_that(".register_operation() errors when name is not scalar character", {
  fn <- function(data, ctx, params) NULL
  expect_error(
    herald:::.register_operation(c("a", "b"), fn),
    class = "herald_error_runtime"
  )
})

test_that(".register_operation() errors when name is empty string", {
  fn <- function(data, ctx, params) NULL
  expect_error(
    herald:::.register_operation("", fn),
    class = "herald_error_runtime"
  )
})

test_that(".register_operation() errors when fn is not a function", {
  expect_error(
    herald:::.register_operation("__test_not_fn_ops__", 42L),
    class = "herald_error_runtime"
  )
})

# ---- snapshot test for error messages -----------------------------------------

test_that(".register_operation() error snapshot for non-character name", {
  fn <- function(data, ctx, params) NULL
  expect_snapshot(
    herald:::.register_operation(123L, fn),
    error = TRUE
  )
})
