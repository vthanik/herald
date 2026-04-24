# ops-prefix-suffix-contained-by.R -- prefix/suffix set-membership ops
#
# prefix_is_not_contained_by: first N chars of the named variable are NOT
#   present in the allowed-values set. Fires when the prefix is absent from
#   the set (prefix does not match any allowed domain/standard code).
#   params: name (column), prefix (integer char count), value (set).
#
# suffix_is_not_contained_by: last N chars NOT in set. Same contract.
#
# is_not_contained_by already exists; these are prefix/suffix extensions.
# Unlocks: CORE-000376 (CG0349), CORE-000540 (CG0333).

op_prefix_is_not_contained_by <- function(data, ctx, name, prefix = 2L,
                                           value = character(0), ...) {
  col <- name
  if (!col %in% names(data)) return(rep(NA, nrow(data)))
  n_chars <- as.integer(prefix[[1L]])
  allowed <- as.character(unlist(value, use.names = FALSE))
  pfx <- substr(toupper(as.character(data[[col]])), 1L, n_chars)
  !toupper(pfx) %in% toupper(allowed)
}

.register_op(
  "prefix_is_not_contained_by",
  op_prefix_is_not_contained_by,
  meta = list(
    kind       = "set",
    summary    = "First N characters of the column value are not in the allowed set.",
    arg_schema = list(
      name   = list(type = "string",  required = TRUE),
      prefix = list(type = "integer", default  = 2L),
      value  = list(type = "array",   required = TRUE)
    ),
    cost_hint     = "O(n)",
    column_arg    = "name",
    returns_na_ok = FALSE
  )
)

op_suffix_is_not_contained_by <- function(data, ctx, name, suffix = 2L,
                                           value = character(0), ...) {
  col <- name
  if (!col %in% names(data)) return(rep(NA, nrow(data)))
  n_chars <- as.integer(suffix[[1L]])
  allowed <- as.character(unlist(value, use.names = FALSE))
  vals <- toupper(as.character(data[[col]]))
  sfx  <- substr(vals, nchar(vals) - n_chars + 1L, nchar(vals))
  !sfx %in% toupper(allowed)
}

.register_op(
  "suffix_is_not_contained_by",
  op_suffix_is_not_contained_by,
  meta = list(
    kind       = "set",
    summary    = "Last N characters of the column value are not in the allowed set.",
    arg_schema = list(
      name   = list(type = "string",  required = TRUE),
      suffix = list(type = "integer", default  = 2L),
      value  = list(type = "array",   required = TRUE)
    ),
    cost_hint     = "O(n)",
    column_arg    = "name",
    returns_na_ok = FALSE
  )
)
