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
  # Apply the P21 rtrim-null convention to the lookup value so
  # "S1-001 " matches "S1-001" in the set. Whitespace-only or NA
  # values become NA in the mask (caller cannot verify containment
  # when the value itself is missing).
  raw <- as.character(col)
  v   <- sub("\\s+$", "", raw)
  is_missing <- is.na(raw) | !nzchar(v)
  out <- v %in% .as_set(value)
  out[is_missing] <- NA
  out
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
  m <- op_is_contained_by(data, ctx, name, value)
  ifelse(is.na(m), NA, !m)
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

# --- contains_all / not_contains_all ----------------------------------------
# For each row, check whether column's value (possibly tokenised on
# whitespace / commas / pipes) contains ALL of the values in `value`.
# Used e.g. to assert a flag column enumerates a required keyword set.

.tokenize <- function(x) {
  # Split on separators commonly used in SDTM: comma, pipe, semicolon, whitespace
  trimws(unlist(strsplit(as.character(x), "[,;|[:space:]]+", perl = TRUE)))
}

op_contains_all <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  need <- .as_set(value)
  if (length(need) == 0L) return(rep(TRUE, nrow(data)))
  vapply(col, function(v) {
    if (is.na(v) || !nzchar(as.character(v))) return(NA)
    have <- .tokenize(v)
    all(need %in% have)
  }, logical(1))
}
.register_op(
  "contains_all", op_contains_all,
  meta = list(
    kind = "set",
    summary = "Column value tokenises to a superset of `value` (all needed tokens present)",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_not_contains_all <- function(data, ctx, name, value) {
  m <- op_contains_all(data, ctx, name, value)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "not_contains_all", op_not_contains_all,
  meta = list(
    kind = "set",
    summary = "Column value is missing at least one required token",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- shares_no_elements_with ------------------------------------------------
# Row-level: column's tokenised set has no intersection with the `value` set.

op_shares_no_elements_with <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  banned <- .as_set(value)
  vapply(col, function(v) {
    if (is.na(v) || !nzchar(as.character(v))) return(NA)
    have <- .tokenize(v)
    !any(have %in% banned)
  }, logical(1))
}
.register_op(
  "shares_no_elements_with", op_shares_no_elements_with,
  meta = list(
    kind = "set",
    summary = "Column value shares no tokens with the banned set",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- is_ordered_subset_of / is_not_ordered_subset_of ------------------------
# For a column whose values are SEQUENTIALLY ordered (e.g. VISITNUM), assert
# that the row-ordered sequence is a subset of `value` IN ORDER (i.e. each
# observed value appears in `value` and preserves the ordering).

op_is_ordered_subset_of <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  ordered_universe <- .as_set(value)
  observed <- as.character(col)
  pos <- match(observed, ordered_universe)
  # A row is "in order" if its position is strictly greater than the max
  # position seen in the rows above it.
  n <- length(observed)
  out <- logical(n)
  running_max <- 0L
  for (i in seq_len(n)) {
    if (is.na(pos[i])) { out[i] <- NA; next }
    out[i] <- pos[i] > running_max
    if (!is.na(out[i]) && isTRUE(out[i])) running_max <- pos[i]
  }
  out
}
.register_op(
  "is_ordered_subset_of", op_is_ordered_subset_of,
  meta = list(
    kind = "set",
    summary = "Column value is in the ordered universe AND follows row-order (monotonic within dataset)",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_is_not_ordered_subset_of <- function(data, ctx, name, value) {
  m <- op_is_ordered_subset_of(data, ctx, name, value)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "is_not_ordered_subset_of", op_is_not_ordered_subset_of,
  meta = list(
    kind = "set",
    summary = "Column value breaks the ordered-subset invariant (out of order or unknown value)",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "list",   required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)
