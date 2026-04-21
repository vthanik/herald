# -----------------------------------------------------------------------------
# ops-cross.R — cross-dataset reference operators
# -----------------------------------------------------------------------------
# These operators need access to OTHER datasets besides the one currently
# being evaluated. They look up ctx$datasets, which validate() populates
# with a named map of all loaded data frames (dataset name upper-cased).

# --- helpers ----------------------------------------------------------------

.ref_ds <- function(ctx, ref_name) {
  if (is.null(ctx) || is.null(ctx$datasets)) return(NULL)
  up <- toupper(as.character(ref_name))
  ctx$datasets[[up]]
}

.as_char <- function(x) as.character(x)

# --- is_not_unique_relationship ----------------------------------------------
#
# For two columns (X, Y) within a dataset, a row is flagged if value X maps
# to MORE THAN one distinct value of Y across all rows with the same X.
# I.e., X should uniquely determine Y.
#
# Arg shape in rules:
#   { name: "--DECOD", operator: "is_not_unique_relationship",
#     value: { related_name: "--LLT" } }

op_is_not_unique_relationship <- function(data, ctx, name, value) {
  n <- nrow(data)
  if (is.null(data[[name]])) return(rep(NA, n))

  # The related column may be passed as a sub-list or a string
  related <- if (is.list(value)) value$related_name else value
  if (is.null(related) || is.na(related) || !nzchar(related)) {
    return(rep(NA, n))
  }
  if (is.null(data[[related]])) return(rep(NA, n))

  x <- .as_char(data[[name]])
  y <- .as_char(data[[related]])

  # Count distinct y per x (excluding NA)
  key_df <- data.frame(x = x, y = y, stringsAsFactors = FALSE)
  key_df <- key_df[!is.na(key_df$x) & !is.na(key_df$y), , drop = FALSE]
  counts <- tapply(key_df$y, key_df$x, function(v) length(unique(v)))

  # Mark each row whose x has count > 1
  bad_x <- names(counts)[counts > 1L]
  x %in% bad_x
}
.register_op(
  "is_not_unique_relationship", op_is_not_unique_relationship,
  meta = list(
    kind = "cross",
    summary = "Column X maps to more than one value of related column Y",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "any", required = TRUE)
    ),
    cost_hint = "O(n log n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_is_unique_relationship <- function(data, ctx, name, value) {
  m <- op_is_not_unique_relationship(data, ctx, name, value)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "is_unique_relationship", op_is_unique_relationship,
  meta = list(
    kind = "cross",
    summary = "Column X maps to exactly one value of related column Y (1:1)",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "any", required = TRUE)
    ),
    cost_hint = "O(n log n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- is_inconsistent_across_dataset ------------------------------------------
#
# For a given row, look up the same key (e.g. USUBJID) in another dataset
# and verify the target column's value matches there. Flag if it doesn't.
#
# Arg shape:
#   { name: "USUBJID", operator: "is_inconsistent_across_dataset",
#     value: { reference_dataset: "DM", by: "USUBJID", column: "USUBJID" } }
# or simpler:
#   value = "DM.USUBJID"   (dataset.column syntax)

op_is_inconsistent_across_dataset <- function(data, ctx, name, value) {
  n <- nrow(data)
  if (is.null(data[[name]])) return(rep(NA, n))

  # Parse value
  if (is.list(value)) {
    ref_ds_name <- value$reference_dataset
    by_key      <- value$by %||% name
    ref_col     <- value$column %||% name
  } else if (is.character(value) && grepl("\\.", value)) {
    parts <- strsplit(value, ".", fixed = TRUE)[[1]]
    ref_ds_name <- parts[1]
    ref_col     <- parts[2]
    by_key      <- name
  } else {
    return(rep(NA, n))
  }

  ref_ds <- .ref_ds(ctx, ref_ds_name)
  if (is.null(ref_ds)) return(rep(NA, n))
  if (is.null(ref_ds[[by_key]]) || is.null(ref_ds[[ref_col]])) {
    return(rep(NA, n))
  }

  lhs <- .as_char(data[[name]])
  # Build a lookup: key -> reference value
  ref_lookup <- stats::setNames(
    .as_char(ref_ds[[ref_col]]),
    .as_char(ref_ds[[by_key]])
  )
  # For rows where the key from current dataset can be found, compare
  row_keys <- .as_char(data[[by_key]] %||% lhs)
  rhs <- unname(ref_lookup[row_keys])
  inconsistent <- !is.na(rhs) & (lhs != rhs)
  inconsistent
}
.register_op(
  "is_inconsistent_across_dataset", op_is_inconsistent_across_dataset,
  meta = list(
    kind = "cross",
    summary = "Value differs from same subject/key's value in a reference dataset",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "any", required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- has_next_corresponding_record (cross-dataset existence) ----------------
# Flag if a parent record (e.g. EVENT) has no matching child record in
# another dataset (e.g. its SUPP or a followup domain).
#
# Arg shape:
#   { name: "USUBJID", operator: "has_next_corresponding_record",
#     value: { reference_dataset: "SUPPAE", by: "USUBJID" } }

op_does_not_have_next_corresponding_record <- function(data, ctx, name, value) {
  n <- nrow(data)
  ref_ds_name <- if (is.list(value)) value$reference_dataset else NA_character_
  by_key      <- if (is.list(value)) (value$by %||% name) else name
  ref_ds <- .ref_ds(ctx, ref_ds_name)
  if (is.null(ref_ds) || is.null(ref_ds[[by_key]])) return(rep(NA, n))

  keys_in_ref <- unique(.as_char(ref_ds[[by_key]]))
  !( .as_char(data[[by_key]] %||% rep(NA_character_, n)) %in% keys_in_ref )
}
.register_op(
  "does_not_have_next_corresponding_record",
  op_does_not_have_next_corresponding_record,
  meta = list(
    kind = "cross",
    summary = "Key has no matching record in a reference dataset",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "any", required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_has_next_corresponding_record <- function(data, ctx, name, value) {
  m <- op_does_not_have_next_corresponding_record(data, ctx, name, value)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "has_next_corresponding_record", op_has_next_corresponding_record,
  meta = list(
    kind = "cross",
    summary = "Key has matching record in a reference dataset",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "any", required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- differs_by_key / matches_by_key (explicit join ops) --------------------
# Thin wrappers over is_inconsistent_across_dataset that take the reference
# dataset, reference column, and join key as explicit named args rather than
# embedding them inside a structured `value`. Rule authors should prefer
# these for new join-by-key rules; they read cleanly in YAML:
#
#   name: VISITDY
#   operator: differs_by_key
#   reference_dataset: TV
#   reference_column: VISITDY
#   key: VISITNUM
#
# CDISC CORE semantic: differs_by_key fires TRUE when the row's value under
# `name` differs from the reference's value for the same key; matches_by_key
# fires TRUE when they are equal. NA is returned when the row's key has no
# match in the reference or when required columns / dataset are absent.

op_differs_by_key <- function(data, ctx, name,
                              reference_dataset,
                              reference_column,
                              key            = NULL,
                              reference_key  = NULL) {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  if (is.null(data[[name]])) return(rep(NA, n))
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))

  join_key     <- key           %||% name
  ref_join_key <- reference_key %||% join_key
  if (is.null(data[[join_key]]) ||
      is.null(ref_ds[[ref_join_key]]) ||
      is.null(ref_ds[[reference_column]])) {
    return(rep(NA, n))
  }

  lut <- stats::setNames(.as_char(ref_ds[[reference_column]]),
                         .as_char(ref_ds[[ref_join_key]]))
  lut <- lut[!duplicated(names(lut))]

  mine  <- .as_char(data[[name]])
  their <- unname(lut[.as_char(data[[join_key]])])
  out <- mine != their
  out[is.na(mine) | is.na(their)] <- NA
  out
}
.register_op(
  "differs_by_key", op_differs_by_key,
  meta = list(
    kind = "cross",
    summary = "Value differs from joined reference-dataset value (join by key)",
    arg_schema = list(
      name              = list(type = "string", required = TRUE),
      reference_dataset = list(type = "string", required = TRUE),
      reference_column  = list(type = "string", required = TRUE),
      key               = list(type = "string", required = FALSE),
      reference_key     = list(type = "string", required = FALSE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_matches_by_key <- function(data, ctx, name,
                              reference_dataset,
                              reference_column,
                              key           = NULL,
                              reference_key = NULL) {
  m <- op_differs_by_key(data, ctx, name,
                         reference_dataset = reference_dataset,
                         reference_column  = reference_column,
                         key               = key,
                         reference_key     = reference_key)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "matches_by_key", op_matches_by_key,
  meta = list(
    kind = "cross",
    summary = "Value matches joined reference-dataset value (join by key)",
    arg_schema = list(
      name              = list(type = "string", required = TRUE),
      reference_dataset = list(type = "string", required = TRUE),
      reference_column  = list(type = "string", required = TRUE),
      key               = list(type = "string", required = FALSE),
      reference_key     = list(type = "string", required = FALSE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)
