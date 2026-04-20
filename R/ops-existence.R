# -----------------------------------------------------------------------------
# ops-existence.R — variable / value presence operators
# -----------------------------------------------------------------------------
# These are the most-used operators in the CDISC corpus (~610 occurrences).
# Two distinct kinds:
#   * Dataset-level  : exists / not_exists -- asserts a COLUMN is in the data
#   * Record-level   : non_empty / empty / is_missing / is_present -- per-row

# --- exists (column present in dataset) --------------------------------------

# When `name` refers to a top-level dataset (rather than a column in the
# currently-evaluated dataset), we collapse the mask to `c(result, FALSE...)`
# so the rule fires at most once per (rule x evaluated dataset), not once per
# row. Without this guard, rules like `not_exists(EX)` scoped to ALL domains
# emit millions of findings on pilot-sized submissions.
#
# Detection is conservative: `name` must look like a CDISC domain code (2-4
# uppercase), NOT be a column in `data`, and ctx$datasets must be populated
# so we don't hide legitimate column checks when no submission context exists.
.is_dataset_ref <- function(name, data, ctx) {
  if (!is.character(name) || length(name) != 1L) return(FALSE)
  if (!grepl("^[A-Z][A-Z0-9]{1,3}$", name)) return(FALSE)
  if (name %in% names(data)) return(FALSE)
  # Require a submission-level context. Without ctx$datasets we can't tell
  # a dataset ref from a column whose name happens to match the pattern.
  !is.null(ctx) && !is.null(ctx$datasets) && length(ctx$datasets) > 0L
}

.ds_present <- function(name, ctx) {
  if (is.null(ctx) || is.null(ctx$datasets)) return(FALSE)
  toupper(name) %in% toupper(names(ctx$datasets))
}

.dataset_level_mask <- function(violated, n) {
  if (n == 0L) return(logical(0))
  c(isTRUE(violated), rep(FALSE, n - 1L))
}

op_exists <- function(data, ctx, name) {
  n <- nrow(data)
  if (.is_dataset_ref(name, data, ctx)) {
    # "exists(<DS>)" in a check_tree fires when the dataset IS present.
    return(.dataset_level_mask(.ds_present(name, ctx), n))
  }
  rep(isTRUE(name %in% names(data)), n)
}
.register_op(
  "exists", op_exists,
  meta = list(
    kind       = "existence",
    summary    = "Column is present in dataset (dataset-wide assertion)",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint  = "O(1)",
    column_arg = "name",
    returns_na_ok = FALSE,
    examples = list(list(name = "AESTDTC"))
  )
)

op_not_exists <- function(data, ctx, name) {
  n <- nrow(data)
  if (.is_dataset_ref(name, data, ctx)) {
    # "not_exists(<DS>)" fires when the dataset is missing.
    return(.dataset_level_mask(!.ds_present(name, ctx), n))
  }
  rep(!(name %in% names(data)), n)
}
.register_op(
  "not_exists", op_not_exists,
  meta = list(
    kind = "existence",
    summary = "Column is absent from dataset",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint = "O(1)",
    column_arg = "name",
    returns_na_ok = FALSE,
    examples = list(list(name = "DEPRECATED_VAR"))
  )
)

# --- non_empty / empty (record-level) ---------------------------------------

op_non_empty <- function(data, ctx, name) {
  values <- data[[name]]
  if (is.null(values)) return(rep(NA, nrow(data)))
  # "non_empty" means: not NA AND (for character) not ""
  if (is.character(values)) {
    !is.na(values) & nzchar(values)
  } else {
    !is.na(values)
  }
}
.register_op(
  "non_empty", op_non_empty,
  meta = list(
    kind = "existence",
    summary = "Column value is not NA and not empty string",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE,
    examples = list(list(name = "USUBJID"))
  )
)

op_empty <- function(data, ctx, name) {
  values <- data[[name]]
  if (is.null(values)) return(rep(NA, nrow(data)))
  if (is.character(values)) {
    is.na(values) | !nzchar(values)
  } else {
    is.na(values)
  }
}
.register_op(
  "empty", op_empty,
  meta = list(
    kind = "existence",
    summary = "Column value is NA or empty string",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE,
    examples = list(list(name = "VSORRES"))
  )
)

# --- synonyms --------------------------------------------------------------

# Some CDISC rules use `is_missing` / `is_present` interchangeably with
# `empty` / `non_empty`. Register as synonyms.

op_is_missing <- function(data, ctx, name) op_empty(data, ctx, name)
.register_op(
  "is_missing", op_is_missing,
  meta = list(
    kind = "existence",
    summary = "Synonym of empty: value is NA or empty string",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_is_present <- function(data, ctx, name) op_non_empty(data, ctx, name)
.register_op(
  "is_present", op_is_present,
  meta = list(
    kind = "existence",
    summary = "Synonym of non_empty: value is not NA and not empty",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)
