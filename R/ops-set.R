# -----------------------------------------------------------------------------
# ops-set.R — set-membership operators
# -----------------------------------------------------------------------------
# ~120 CDISC rule uses, mostly controlled-terminology checks.

.as_set <- function(x) {
  if (is.null(x)) return(character(0))
  as.character(unlist(x))
}

op_is_contained_by <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  as.character(col) %in% .as_set(value)
}
.register_op(
  "is_contained_by", op_is_contained_by,
  meta = list(
    kind = "set",
    summary = "Column value is in set",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_is_not_contained_by <- function(data, ctx, name, value) {
  !op_is_contained_by(data, ctx, name, value)
}
.register_op(
  "is_not_contained_by", op_is_not_contained_by,
  meta = list(
    kind = "set",
    summary = "Column value is not in set",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_is_contained_by_ci <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  tolower(as.character(col)) %in% tolower(.as_set(value))
}
.register_op(
  "is_contained_by_case_insensitive", op_is_contained_by_ci,
  meta = list(
    kind = "set",
    summary = "Column value is in set (case-insensitive)",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

op_is_not_contained_by_ci <- function(data, ctx, name, value) {
  !op_is_contained_by_ci(data, ctx, name, value)
}
.register_op(
  "is_not_contained_by_case_insensitive", op_is_not_contained_by_ci,
  meta = list(
    kind = "set",
    summary = "Column value is not in set (case-insensitive)",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = "name",
    returns_na_ok = TRUE
  )
)

# --- uniqueness (within a single column or a composite key) ------------------

op_is_unique_set <- function(data, ctx, name) {
  # name may be a scalar column name or a vector of column names (composite key)
  names_vec <- .as_set(name)
  missing_cols <- setdiff(names_vec, names(data))
  if (length(missing_cols) > 0L) return(rep(NA, nrow(data)))
  key <- do.call(paste, c(data[, names_vec, drop = FALSE], list(sep = "\x1f")))
  counts <- table(key)
  rep_count <- as.integer(counts[key])
  rep_count == 1L
}
.register_op(
  "is_unique_set", op_is_unique_set,
  meta = list(
    kind = "set",
    summary = "Row's column (or composite key) value is unique within dataset",
    arg_schema = list(
      name = list(type = "list", required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = NA_character_,
    returns_na_ok = TRUE
  )
)

op_is_not_unique_set <- function(data, ctx, name) {
  !op_is_unique_set(data, ctx, name)
}
.register_op(
  "is_not_unique_set", op_is_not_unique_set,
  meta = list(
    kind = "set",
    summary = "Row's column value is duplicated within dataset",
    arg_schema = list(
      name = list(type = "list", required = TRUE)
    ),
    cost_hint = "O(n)",
    column_arg = NA_character_,
    returns_na_ok = TRUE
  )
)
