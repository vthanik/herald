# -----------------------------------------------------------------------------
# ops-compare.R — equality and ordinal comparison operators
# -----------------------------------------------------------------------------
# ~270 CDISC rule uses. Comparisons on column values against literals
# or against other columns. NA propagates to NA (advisory) unless the
# rule explicitly handles missing via non_empty.

.coerce_compare <- function(col, value) {
  # Align types: if value is literal and col is character, coerce both.
  # If col is numeric and value can be parsed, coerce value to numeric.
  if (is.numeric(col)) {
    v_num <- suppressWarnings(as.numeric(as.character(value)))
    if (!any(is.na(v_num))) return(list(col = col, value = v_num))
  }
  list(col = as.character(col), value = as.character(value))
}

# Scalar-comparison ops must receive a scalar `value`. When a cross-ref
# resolves to a multi-element vector (e.g. TV.VISITDY -> all TV VISITDY
# values), the rule's intent is almost always a join-by-key that these
# ops don't implement. Return NA mask -> advisory, rather than firing on
# every row via R's recycling semantics.
.scalar_compare_guard <- function(value, n) {
  if (length(value) > 1L) rep(NA, n) else NULL
}

op_equal_to <- function(data, ctx, name, value, value_is_literal = TRUE) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  if (isTRUE(value_is_literal)) {
    g <- .scalar_compare_guard(value, nrow(data))
    if (!is.null(g)) return(g)
    p <- .coerce_compare(col, value)
    p$col == p$value
  } else {
    other <- data[[as.character(value)]]
    if (is.null(other)) return(rep(NA, nrow(data)))
    col == other
  }
}
.register_op(
  "equal_to", op_equal_to,
  meta = list(
    kind = "compare",
    summary = "Column value equals a literal or another column",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      value = list(type = "any",     required = TRUE),
      value_is_literal = list(type = "logical", default = TRUE)
    ),
    cost_hint  = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_not_equal_to <- function(data, ctx, name, value, value_is_literal = TRUE) {
  m <- op_equal_to(data, ctx, name, value, value_is_literal)
  !m
}
.register_op(
  "not_equal_to", op_not_equal_to,
  meta = list(
    kind = "compare",
    summary = "Column value does not equal literal / column",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      value = list(type = "any",     required = TRUE),
      value_is_literal = list(type = "logical", default = TRUE)
    ),
    cost_hint  = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_equal_to_ci <- function(data, ctx, name, value, value_is_literal = TRUE) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  if (isTRUE(value_is_literal)) {
    g <- .scalar_compare_guard(value, nrow(data))
    if (!is.null(g)) return(g)
    tolower(as.character(col)) == tolower(as.character(value))
  } else {
    other <- data[[as.character(value)]]
    if (is.null(other)) return(rep(NA, nrow(data)))
    tolower(as.character(col)) == tolower(as.character(other))
  }
}
.register_op(
  "equal_to_case_insensitive", op_equal_to_ci,
  meta = list(
    kind = "compare",
    summary = "Case-insensitive equality",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      value = list(type = "any",     required = TRUE),
      value_is_literal = list(type = "logical", default = TRUE)
    ),
    cost_hint  = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_not_equal_to_ci <- function(data, ctx, name, value, value_is_literal = TRUE) {
  m <- op_equal_to_ci(data, ctx, name, value, value_is_literal)
  !m
}
.register_op(
  "not_equal_to_case_insensitive", op_not_equal_to_ci,
  meta = list(
    kind = "compare",
    summary = "Case-insensitive inequality",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      value = list(type = "any",     required = TRUE),
      value_is_literal = list(type = "logical", default = TRUE)
    ),
    cost_hint  = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

# --- ordinal comparisons -----------------------------------------------------

.numeric_compare <- function(col, value, op) {
  col_num <- suppressWarnings(as.numeric(as.character(col)))
  val_num <- suppressWarnings(as.numeric(as.character(value)))
  op(col_num, val_num)
}

op_greater_than <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  g <- .scalar_compare_guard(value, nrow(data)); if (!is.null(g)) return(g)
  .numeric_compare(col, value, `>`)
}
.register_op(
  "greater_than", op_greater_than,
  meta = list(
    kind = "compare",
    summary = "Column numeric value is strictly greater than threshold",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      value = list(type = "numeric", required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_greater_than_or_equal_to <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  g <- .scalar_compare_guard(value, nrow(data)); if (!is.null(g)) return(g)
  .numeric_compare(col, value, `>=`)
}
.register_op(
  "greater_than_or_equal_to", op_greater_than_or_equal_to,
  meta = list(
    kind = "compare",
    summary = "Column numeric value >= threshold",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      value = list(type = "numeric", required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_less_than <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  g <- .scalar_compare_guard(value, nrow(data)); if (!is.null(g)) return(g)
  .numeric_compare(col, value, `<`)
}
.register_op(
  "less_than", op_less_than,
  meta = list(
    kind = "compare",
    summary = "Column numeric value < threshold",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      value = list(type = "numeric", required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_less_than_or_equal_to <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  g <- .scalar_compare_guard(value, nrow(data)); if (!is.null(g)) return(g)
  .numeric_compare(col, value, `<=`)
}
.register_op(
  "less_than_or_equal_to", op_less_than_or_equal_to,
  meta = list(
    kind = "compare",
    summary = "Column numeric value <= threshold",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      value = list(type = "numeric", required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)
