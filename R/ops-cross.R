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

  # Right-trim character values before comparison to mirror Pinnacle 21's
  # rtrim-null convention (DataEntryFactory.java:313-328). "Heart Rate"
  # and "Heart Rate " collapse to the same value; "   " becomes NA so
  # whitespace-only cells are excluded by the "both variables populated"
  # clause in the CDISC message.
  .rtrim_na <- function(v) {
    if (!is.character(v)) return(.as_char(v))
    r <- sub("\\s+$", "", v)
    r[is.na(v) | !nzchar(r)] <- NA_character_
    r
  }
  x <- .rtrim_na(data[[name]])
  y <- .rtrim_na(data[[related]])

  # Count distinct y per x (excluding NA in either). Mirrors the
  # CDISC message clause "considering only those rows on which both
  # variables are populated".
  key_df <- data.frame(x = x, y = y, stringsAsFactors = FALSE)
  key_df <- key_df[!is.na(key_df$x) & !is.na(key_df$y), , drop = FALSE]
  counts <- tapply(key_df$y, key_df$x, function(v) length(unique(v)))

  # Mark each row whose x has count > 1. Unlike P21 (which fires only
  # the 2nd+ duplicate), herald fires EVERY row in a violating group
  # so reviewers see the full scope of the inconsistency. Documented
  # deviation in tools/rule-authoring/CONVENTIONS.md section 4.
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

# --- ref_col_empty / ref_col_populated (cross-dataset null checks) ----------
# For each row in the current dataset, look up a reference dataset by key
# and test whether the referenced column is populated or null in the matching
# row.
#
# Mirrors P21's val:Lookup primitive with a Where/Search clause on a null
# check (e.g. SD1030 for CG0226):
#   Variable="USUBJID == USUBJID" Where="RFSTDTC != ''" From="DM"
# which asserts that the matching DM row has RFSTDTC populated.
#
# Argument shape:
#   { name: "USUBJID", operator: "ref_col_empty",
#     value: "DM.RFSTDTC" }               # dotted short form
# or:
#   { name: "USUBJID", operator: "ref_col_empty",
#     value: { reference_dataset: "DM", reference_column: "RFSTDTC",
#             by: "USUBJID" } }
#
# Semantics:
# - `ref_col_empty`: TRUE when the reference row exists AND its column is
#   null/empty; also TRUE when there is no matching reference row (the
#   reference is "missing" for this key). Mirrors P21's Lookup-failure
#   = no-match => fires path.
# - `ref_col_populated`: logical complement; TRUE when the reference row
#   exists AND its column is populated.
#
# rtrim-null applies to the reference column before the null test
# (DataEntryFactory.java:313-328 parity).

.parse_ref_arg <- function(name, value) {
  if (is.list(value)) {
    list(ref_ds   = toupper(as.character(value$reference_dataset %||% "")),
         ref_col  = as.character(value$reference_column %||% value$column %||% ""),
         by       = as.character(value$by %||% value$key %||% name))
  } else if (is.character(value) && length(value) == 1L &&
             grepl("^[A-Za-z][A-Za-z0-9]*\\.[A-Za-z][A-Za-z0-9_]*$", value)) {
    parts <- strsplit(value, ".", fixed = TRUE)[[1L]]
    list(ref_ds = toupper(parts[[1L]]),
         ref_col = parts[[2L]],
         by      = as.character(name))
  } else {
    NULL
  }
}

op_ref_col_empty <- function(data, ctx, name, value) {
  n <- nrow(data)
  args <- .parse_ref_arg(name, value)
  if (is.null(args) || !nzchar(args$ref_ds) || !nzchar(args$ref_col)) {
    return(rep(NA, n))
  }
  ref <- .ref_ds(ctx, args$ref_ds)
  if (is.null(ref) || is.null(ref[[args$by]]) || is.null(ref[[args$ref_col]])) {
    return(rep(NA, n))
  }

  rtrim_null <- function(v) {
    if (!is.character(v)) return(as.character(v))
    r <- sub("\\s+$", "", v)
    r[is.na(v) | !nzchar(r)] <- NA_character_
    r
  }
  ref_keys  <- as.character(ref[[args$by]])
  ref_vals  <- rtrim_null(ref[[args$ref_col]])
  # For each ref key, is the column POPULATED on at least one row?
  # P21's Lookup with Where=<col> != '' passes when ANY row matches.
  by_key    <- split(ref_vals, ref_keys)
  populated_keys <- names(by_key)[vapply(by_key, function(v) any(!is.na(v)),
                                          logical(1L))]
  row_keys <- as.character(data[[args$by]] %||% rep(NA_character_, n))
  # TRUE where the reference is EMPTY (key absent, or present but all-null).
  !(row_keys %in% populated_keys)
}
.register_op(
  "ref_col_empty", op_ref_col_empty,
  meta = list(
    kind = "cross",
    summary = "Reference dataset's column is null/empty (or no matching ref row) for this row's key",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "any",    required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_ref_col_populated <- function(data, ctx, name, value) {
  m <- op_ref_col_empty(data, ctx, name, value)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "ref_col_populated", op_ref_col_populated,
  meta = list(
    kind = "cross",
    summary = "Reference dataset has a matching ref row and its column is populated",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "any",    required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)
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

# --- ordinal by-key comparators --------------------------------------------
# Extend the by-key join family with ordinal comparisons. Semantics: each
# fires TRUE when the row's `name` value is STRICTLY <operator> the joined
# reference value. ISO 8601 dates sort lexicographically so string compare
# is sufficient for CDISC date columns (RFSTDTC, RFICDTC, DTHDTC, etc.).
# For numeric columns both sides are coerced via as.numeric.
#
# Mirrors P21's DSL: `SUB:RFICDTC @lteq %Domain%STDTC` checks that the
# subject's RFICDTC is <= the row's STDTC. `SUB:` is P21 syntax for
# subject-level variables sourced from DM; herald expresses the same
# concept via reference_dataset="DM" + reference_key="USUBJID".
#
# See `Comparison.java:160-207` for P21's ordinal logic and
# `DataEntryFactory.java:160-180` for the type-aware compareToAny path.

.cmp_by_key <- function(data, ctx, name, reference_dataset, reference_column,
                        key, reference_key, fn) {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  if (is.null(data[[name]])) return(rep(NA, n))
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))

  join_key     <- key           %||% "USUBJID"
  ref_join_key <- reference_key %||% join_key
  if (is.null(data[[join_key]]) ||
      is.null(ref_ds[[ref_join_key]]) ||
      is.null(ref_ds[[reference_column]])) {
    return(rep(NA, n))
  }

  # rtrim-null (P21 DataEntryFactory.java:313-328) on both sides so
  # "2024-01-15 " and "2024-01-15" compare equal; all-whitespace -> NA.
  rtrim_null <- function(v) {
    v <- as.character(v)
    r <- sub("\\s+$", "", v)
    r[is.na(v) | !nzchar(r)] <- NA_character_
    r
  }
  mine  <- rtrim_null(data[[name]])
  ref_keys <- rtrim_null(ref_ds[[ref_join_key]])
  ref_vals <- rtrim_null(ref_ds[[reference_column]])
  # When a subject has multiple matching ref rows (e.g. multi-domain),
  # use the first non-NA value -- subject-level columns like RFSTDTC in DM
  # are single-valued per subject; only one row per USUBJID in DM.
  ok <- !is.na(ref_keys)
  lut <- stats::setNames(ref_vals[ok], ref_keys[ok])
  lut <- lut[!duplicated(names(lut))]

  row_keys <- rtrim_null(data[[join_key]])
  their <- unname(lut[row_keys])

  # Attempt numeric compare when both sides parse as numeric; else
  # lexicographic string compare (ISO dates sort correctly this way).
  mine_num  <- suppressWarnings(as.numeric(mine))
  their_num <- suppressWarnings(as.numeric(their))
  numeric_path <- !any(is.na(mine_num) & !is.na(mine)) &&
                  !any(is.na(their_num) & !is.na(their))
  out <- if (numeric_path) fn(mine_num, their_num) else fn(mine, their)
  out[is.na(mine) | is.na(their)] <- NA
  out
}

op_less_than_by_key <- function(data, ctx, name,
                                reference_dataset, reference_column,
                                key = NULL, reference_key = NULL) {
  .cmp_by_key(data, ctx, name, reference_dataset, reference_column,
              key, reference_key, fn = function(a, b) a < b)
}
.register_op(
  "less_than_by_key", op_less_than_by_key,
  meta = list(
    kind = "cross",
    summary = "Row value is strictly less than the joined reference value",
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

op_less_than_or_equal_by_key <- function(data, ctx, name,
                                         reference_dataset, reference_column,
                                         key = NULL, reference_key = NULL) {
  .cmp_by_key(data, ctx, name, reference_dataset, reference_column,
              key, reference_key, fn = function(a, b) a <= b)
}
.register_op(
  "less_than_or_equal_by_key", op_less_than_or_equal_by_key,
  meta = list(
    kind = "cross",
    summary = "Row value is less than or equal to the joined reference value",
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

op_greater_than_by_key <- function(data, ctx, name,
                                   reference_dataset, reference_column,
                                   key = NULL, reference_key = NULL) {
  .cmp_by_key(data, ctx, name, reference_dataset, reference_column,
              key, reference_key, fn = function(a, b) a > b)
}
.register_op(
  "greater_than_by_key", op_greater_than_by_key,
  meta = list(
    kind = "cross",
    summary = "Row value is strictly greater than the joined reference value",
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

op_greater_than_or_equal_by_key <- function(data, ctx, name,
                                            reference_dataset, reference_column,
                                            key = NULL, reference_key = NULL) {
  .cmp_by_key(data, ctx, name, reference_dataset, reference_column,
              key, reference_key, fn = function(a, b) a >= b)
}
.register_op(
  "greater_than_or_equal_by_key", op_greater_than_or_equal_by_key,
  meta = list(
    kind = "cross",
    summary = "Row value is greater than or equal to the joined reference value",
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

# --- study-day algorithm op --------------------------------------------
# SDTM --STDY / --ENDY rule: for each record, the stored study-day should
# equal the computed day offset from DM.RFSTDTC (or RFICDTC) to the row's
# --STDTC (or --ENDTC). CDISC formula (SDTMIG section 4.4):
#
#   if target_date >= anchor_date:  study_day = target - anchor + 1
#   if target_date <  anchor_date:  study_day = target - anchor       (no +1)
#
# Mirrors P21's `:DY(SUB:RFSTDTC, %Domain%STDTC)` function, e.g.
# SD1089 (CG0221), SD1091 (CG0220). We only operate on ISO-8601 dates
# where the date portion is at least YYYY-MM-DD.
#
# Fires TRUE on rows where the stored study-day differs from the computed
# value. Skips (NA) when either date is missing / incomplete.

op_study_day_mismatch <- function(data, ctx, name,
                                  reference_dataset,
                                  reference_column,
                                  target_date_column,
                                  key = NULL, reference_key = NULL) {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  if (is.null(data[[name]]) || is.null(data[[target_date_column]])) {
    return(rep(NA, n))
  }
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))

  join_key     <- key %||% "USUBJID"
  ref_join_key <- reference_key %||% join_key
  if (is.null(data[[join_key]]) ||
      is.null(ref_ds[[ref_join_key]]) ||
      is.null(ref_ds[[reference_column]])) {
    return(rep(NA, n))
  }

  # Build subject -> anchor_date lookup. Only accept complete YYYY-MM-DD
  # dates (possibly with time suffix).
  iso_date_prefix <- function(x) {
    x <- as.character(x)
    m <- regmatches(x, regexpr("^[0-9]{4}-[0-9]{2}-[0-9]{2}", x))
    # regexpr returns empty for non-matches; pad to full length
    out <- rep(NA_character_, length(x))
    hit <- regmatches(x, regexpr("^[0-9]{4}-[0-9]{2}-[0-9]{2}", x))
    idx <- which(nchar(x) >= 10L & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", x))
    out[idx] <- substr(x[idx], 1L, 10L)
    out
  }
  ref_keys <- as.character(ref_ds[[ref_join_key]])
  anchor_iso <- iso_date_prefix(ref_ds[[reference_column]])
  ok <- !is.na(ref_keys) & !is.na(anchor_iso)
  lut <- stats::setNames(anchor_iso[ok], ref_keys[ok])
  lut <- lut[!duplicated(names(lut))]

  row_keys <- as.character(data[[join_key]])
  anchor_for_row <- unname(lut[row_keys])
  target_iso <- iso_date_prefix(data[[target_date_column]])
  stored_day <- suppressWarnings(as.integer(data[[name]]))

  # Convert to Date, compute day offset
  anchor_date <- suppressWarnings(as.Date(anchor_for_row))
  target_date <- suppressWarnings(as.Date(target_iso))
  diff <- as.integer(target_date - anchor_date)
  # CDISC rule: +1 when target >= anchor (no day zero); else raw diff.
  computed <- ifelse(is.na(diff), NA_integer_,
                     ifelse(diff >= 0L, diff + 1L, diff))

  mismatch <- !is.na(stored_day) & !is.na(computed) & stored_day != computed
  # Rows with missing data -> NA (advisory).
  mismatch[is.na(stored_day) | is.na(computed)] <- NA
  mismatch
}
.register_op(
  "study_day_mismatch", op_study_day_mismatch,
  meta = list(
    kind = "cross",
    summary = "SDTM --STDY/--ENDY stored value differs from CDISC-computed day offset from subject's anchor date",
    arg_schema = list(
      name               = list(type = "string", required = TRUE),
      reference_dataset  = list(type = "string", required = TRUE),
      reference_column   = list(type = "string", required = TRUE),
      target_date_column = list(type = "string", required = TRUE),
      key                = list(type = "string", required = FALSE),
      reference_key      = list(type = "string", required = FALSE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- exists_in_ref / missing_in_ref (multi-domain cross-ref) ------------
# For each row in the current dataset, check whether a related dataset has
# AT LEAST ONE row matching the key (e.g. multiple DS records per subject).
# Mirrors P21's multi-row Lookup semantic (DS:DSSTDTC iteration in SD2047
# etc.). Where `op_ref_col_empty` tests the ref column's nullity,
# `op_exists_in_ref` just tests row-existence.

op_missing_in_ref <- function(data, ctx, name,
                              reference_dataset,
                              key = NULL, reference_key = NULL) {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))
  join_key     <- key %||% name
  ref_join_key <- reference_key %||% join_key
  if (is.null(data[[join_key]]) || is.null(ref_ds[[ref_join_key]])) {
    return(rep(NA, n))
  }
  ref_keys <- unique(as.character(ref_ds[[ref_join_key]]))
  !(as.character(data[[join_key]]) %in% ref_keys)
}
.register_op(
  "missing_in_ref", op_missing_in_ref,
  meta = list(
    kind = "cross",
    summary = "Row's key has no matching record in the reference dataset",
    arg_schema = list(
      name              = list(type = "string", required = TRUE),
      reference_dataset = list(type = "string", required = TRUE),
      key               = list(type = "string", required = FALSE),
      reference_key     = list(type = "string", required = FALSE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)
