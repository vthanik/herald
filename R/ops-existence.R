# -----------------------------------------------------------------------------
# ops-existence.R — variable / value presence operators
# -----------------------------------------------------------------------------
# These are the most-used operators in the CDISC corpus (~610 occurrences).
# Two distinct kinds:
#   * Dataset-level  : exists / not_exists -- asserts a COLUMN is in the data
#   * Record-level   : non_empty / empty / is_missing / is_present -- per-row

# --- exists (column present in dataset) --------------------------------------

op_exists <- function(data, ctx, name) {
  n <- nrow(data)
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
