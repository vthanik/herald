# -----------------------------------------------------------------------------
# test-fast-ops-meta.R — operator registry metadata
# -----------------------------------------------------------------------------

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
