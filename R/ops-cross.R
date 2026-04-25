# -----------------------------------------------------------------------------
# ops-cross.R — cross-dataset reference operators
# -----------------------------------------------------------------------------
# These operators need access to OTHER datasets besides the one currently
# being evaluated. They look up ctx$datasets, which validate() populates
# with a named map of all loaded data frames (dataset name upper-cased).

# --- helpers ----------------------------------------------------------------

.as_char <- function(x) as.character(x)

# P21 audit item G: replace NA with a sentinel that cannot appear as a real
# value so that NA group-key components don't collide with the literal string
# "NA" when keys are pasted with sep="\x1f".
.na_sent <- function(v) { v[is.na(v)] <- "\x01<NA>\x01"; v }

# CDISC ISO-8601 partial-date pattern -- mirrors P21's DATE_PATTERN
# (DataEntryFactory.java:31-46). Covers bare year through full datetime,
# with "-" as the CDISC partial-unknown placeholder.
.CDISC_DATE_RX <- paste0(
  "^(?:-|[0-9]{4})",
  "(?:-(?:-|0[0-9]|1[0-2])",
  "(?:-(?:-|[0-2][0-9]|3[0-1])",
  "(?:T(?:-|[0-1][0-9]|2[0-4])",
  "(?::(?:-|[0-5][0-9])",
  "(?::[0-5][0-9])?",
  ")?)?)?)?$"
)

#' Convert R temporal classes (POSIXct / Date / difftime) to CDISC
#' ISO-8601 strings so they parse through the fuzzy-date path. Called
#' before `as.character()` in `.cdisc_value_equal()` because R's default
#' `as.character(POSIXct)` produces a space separator ("2024-01-01
#' 10:00:00") that does NOT match the CDISC ISO regex; we need
#' "2024-01-01T10:00:00". Non-temporal inputs pass through unchanged.
#' @noRd
.to_iso_if_temporal <- function(x) {
  if (inherits(x, "POSIXt")) {
    out <- format(x, "%Y-%m-%dT%H:%M:%S", tz = "UTC")
    out[is.na(x)] <- NA_character_
    return(out)
  }
  if (inherits(x, "Date")) {
    out <- format(x, "%Y-%m-%d")
    out[is.na(x)] <- NA_character_
    return(out)
  }
  if (inherits(x, "difftime")) {
    # ISO time: seconds since midnight -> HH:MM:SS
    secs <- as.numeric(x, units = "secs")
    h <- floor(secs / 3600)
    m <- floor((secs %% 3600) / 60)
    s <- floor(secs %% 60)
    out <- sprintf("%02d:%02d:%02d", h, m, s)
    out[is.na(secs)] <- NA_character_
    return(out)
  }
  x
}

#' CDISC-semantic value equality.
#'
#' Mirrors Pinnacle 21's `DataEntryFactory.compareToAny()` semantics so
#' herald's cross-dataset compares behave the same way as the reference
#' implementation:
#'   * Both sides NULL -> equal        (NullDataEntry.compareToAny:355-356)
#'   * One side NULL   -> not equal    (same)
#'   * Both numeric    -> BigDecimal-style equality ("1" == "1.0")
#'   * Both datetime   -> prefix equality ("2024" == "2024-01-01")
#'   * Else            -> case-sensitive string compare on rtrimmed values.
#'
#' R temporal classes (POSIXct / Date / difftime) are canonicalised to
#' CDISC ISO-8601 first so an XPT-ingested DTM column compares cleanly
#' against a JSON-ingested ISO-string column.
#'
#' Accepts scalar or vector inputs; returns logical of length `max(len)`.
#' Inputs are coerced to character and space-rtrimmed. Empty string after
#' rtrim is treated as NULL.
#' @noRd
.cdisc_value_equal <- function(a, b) {
  rtrim <- function(v) {
    v <- as.character(v)
    r <- sub(" +$", "", v)
    r[is.na(v) | !nzchar(r)] <- NA_character_
    r
  }
  av <- rtrim(.to_iso_if_temporal(a))
  bv <- rtrim(.to_iso_if_temporal(b))

  out <- logical(max(length(av), length(bv)))
  out[] <- NA

  both_null <- is.na(av) & is.na(bv)
  one_null  <- xor(is.na(av), is.na(bv))
  out[both_null] <- TRUE
  out[one_null]  <- FALSE

  cmp <- which(!is.na(av) & !is.na(bv))
  if (length(cmp) == 0L) return(out)

  av_c <- av[cmp]; bv_c <- bv[cmp]

  a_num <- suppressWarnings(as.numeric(av_c))
  b_num <- suppressWarnings(as.numeric(bv_c))
  numeric_path <- !is.na(a_num) & !is.na(b_num)

  a_is_date <- grepl(.CDISC_DATE_RX, av_c, perl = TRUE)
  b_is_date <- grepl(.CDISC_DATE_RX, bv_c, perl = TRUE)
  # 4-digit integers are treated as dates per P21 heuristic (year).
  a_is_date <- a_is_date | (numeric_path & nchar(av_c) == 4L & !grepl("\\.", av_c))
  b_is_date <- b_is_date | (numeric_path & nchar(bv_c) == 4L & !grepl("\\.", bv_c))
  date_path <- a_is_date & b_is_date

  eq <- logical(length(cmp))
  # Date fuzzy equality takes precedence over numeric -- matches P21's
  # ordering (datetime check after numeric-both gate, but date heuristic
  # applies even when numeric parses the 4-digit year).
  eq[date_path] <- startsWith(av_c[date_path], bv_c[date_path]) |
                   startsWith(bv_c[date_path], av_c[date_path])
  num_only <- numeric_path & !date_path
  eq[num_only] <- a_num[num_only] == b_num[num_only]
  str_path <- !numeric_path & !date_path
  eq[str_path] <- av_c[str_path] == bv_c[str_path]

  out[cmp] <- eq
  out
}


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

  # The related column may be passed as a sub-list or a string. The
  # sub-list form may also include a `group_by` (character vector) that
  # nests the X/Y uniqueness check inside additional grouping columns
  # (e.g. PARAMCD-scoped rules: within each PARAMCD, X->Y is 1:1).
  # Mirrors P21's val:Unique `GroupBy="STUDYID,PARAMCD,..."` composite
  # group key (UniqueValueValidationRule.java + DataGrouping).
  if (is.list(value)) {
    related  <- value$related_name
    group_by <- as.character(unlist(value$group_by %||% character(0)))
  } else {
    related  <- value
    group_by <- character(0)
  }
  if (is.null(related) || is.na(related) || !nzchar(related)) {
    return(rep(NA, n))
  }
  if (is.null(data[[related]])) return(rep(NA, n))
  missing_grp <- setdiff(group_by, names(data))
  if (length(missing_grp) > 0L) return(rep(NA, n))

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

  # Count distinct y per (group_by..., x) tuple (excluding NA). Mirrors
  # the CDISC message clause "considering only those rows on which both
  # variables are populated" plus the optional "within a given value of
  # <G>" outer scope.
  if (length(group_by) == 0L) {
    outer_key <- rep("", n)
  } else {
    outer_key <- do.call(paste, c(lapply(group_by, function(g)
      .na_sent(.rtrim_na(data[[g]]))), list(sep = "\x1f")))
  }
  composite_x <- paste(outer_key, .na_sent(x), sep = "\x1f")
  key_df <- data.frame(x = composite_x, y = y, stringsAsFactors = FALSE)
  # Exclude rows with NA in x or y (or any group_by column implicitly
  # via NA propagation into outer_key).
  has_na_grp <- if (length(group_by) == 0L) rep(FALSE, n) else
    Reduce(`|`, lapply(group_by, function(g) is.na(.rtrim_na(data[[g]]))))
  key_df <- key_df[!is.na(x) & !is.na(y) & !has_na_grp, , drop = FALSE]
  counts <- tapply(key_df$y, key_df$x, function(v) length(unique(v)))

  # Mark each row whose composite group key has count > 1. Unlike P21
  # (which fires only the 2nd+ duplicate), herald fires EVERY row in a
  # violating group so reviewers see the full scope of the
  # inconsistency. Documented deviation in CONVENTIONS.md section 4.
  bad_x <- names(counts)[counts > 1L]
  composite_x %in% bad_x
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
# --- max_n_records_per_group_matching ----------------------------------------
# Fires on ALL rows in a group when more than max_n rows within that group
# have data[[name]] equal to value (after rtrim). Group is defined by the
# character vector group_keys.
#
# Returns:
#   TRUE  -- row's group violates the max_n constraint
#   FALSE -- row's group is within the limit
#   NA    -- name column or any group_keys column is absent

op_max_n_records_per_group_matching <- function(data, ctx, name, value,
                                                group_keys, max_n = 1L) {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  if (is.null(data[[name]])) return(rep(NA, n))
  gk <- as.character(unlist(group_keys))
  for (k in gk) {
    if (is.null(data[[k]])) return(rep(NA, n))
  }
  max_n <- as.integer(max_n)
  # rtrim + case-sensitive match
  raw <- as.character(data[[name]])
  raw <- sub("\\s+$", "", raw)
  matched <- !is.na(raw) & raw == as.character(value)
  # Build composite group key (paste-sep is safe; unique separator)
  if (length(gk) == 1L) {
    gkey <- as.character(data[[gk]])
  } else {
    gkey <- do.call(paste, c(lapply(gk, function(k) as.character(data[[k]])),
                             list(sep = "\u0001")))
  }
  # Count matching rows per group
  cnt <- tapply(matched, gkey, sum, na.rm = TRUE)
  # Map back to rows; rows in violating groups fire
  row_cnt <- cnt[gkey]
  as.logical(row_cnt > max_n)
}
.register_op(
  "max_n_records_per_group_matching", op_max_n_records_per_group_matching,
  meta = list(
    kind = "cross",
    summary = "fires when more than max_n rows per group match a value",
    arg_schema = list(
      name       = list(type = "string",  required = TRUE),
      value      = list(type = "string",  required = TRUE),
      group_keys = list(type = "array",   required = TRUE),
      max_n      = list(type = "integer", required = FALSE, default = 1L)
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

  # key / reference_key may be a character vector (composite join) or a
  # bracketed string like "[STUDYID, VISITNUM]" produced by apply-pattern.R
  # slot substitution. Parse the bracketed form into a proper vector so the
  # composite-key path works regardless of how the YAML was written.
  .parse_key <- function(k) {
    k <- as.character(unlist(k %||% character(0)))
    if (length(k) == 1L && grepl("^\\[", k)) {
      inner <- sub("^\\[\\s*", "", sub("\\s*\\]$", "", k))
      k <- trimws(strsplit(inner, ",", fixed = TRUE)[[1L]])
    }
    k
  }
  join_key     <- .parse_key(key     %||% name)
  ref_join_key <- .parse_key(reference_key %||% join_key)

  # Validate all key columns exist in both datasets.
  if (any(!join_key     %in% names(data))   ||
      any(!ref_join_key %in% names(ref_ds)) ||
      is.null(ref_ds[[reference_column]])) {
    return(rep(NA, n))
  }

  .paste_cols <- function(df, cols) {
    if (length(cols) == 1L) return(.as_char(df[[cols]]))
    do.call(paste, c(lapply(cols, function(c) .na_sent(.as_char(df[[c]]))),
                     list(sep = "\x1f")))
  }

  lut <- stats::setNames(.as_char(ref_ds[[reference_column]]),
                         .paste_cols(ref_ds, ref_join_key))
  lut <- lut[!duplicated(names(lut))]

  mine  <- .as_char(data[[name]])
  their <- unname(lut[.paste_cols(data, join_key)])
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
      key               = list(type = "any",    required = FALSE),
      reference_key     = list(type = "any",    required = FALSE)
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

# --- value_not_var_in_ref_dataset ------------------------------------------
# For each row, treat the cell value in `name` column as a variable name
# and verify that it IS a column in `reference_dataset`. Optionally
# require the variable name to match a suffix regex (e.g. "(DT|DTC|DTM)"
# for date variables). Fires TRUE when:
#   * value is not a column in reference_dataset, OR
#   * value IS a column but doesn't match the required suffix.
# Null / empty cell -> NA (advisory).
#
# Mirrors a P21 val:Lookup with Variable="%VALUE%" projected against the
# reference dataset's column list. P21's SDTM-IG 3.3 does NOT encode
# CG0375 (TDANCVAR must be a date variable in ADSL) as an explicit rule
# -- only the ItemDef metadata exists. herald authors this pattern
# directly from the CDISC narrative.

# --- any_index_missing_ref_var --------------------------------------------
# For each DISTINCT value of an integer-index column (e.g. APERIOD), check
# that a corresponding variable exists in a reference dataset, where the
# expected variable name is derived by substituting the index value into a
# name template like `TRTxxP`, `APxxSDT`, `TRxxSDT`, `TRxxEDT`.
#
# ADaMIG Section 3.2.3: APERIOD value must match one of the xx values in
# ADSL TRTxxP variable names (and analogous start/end date variables for
# analysis period timing in ADaMIG Section 3.2.7).
#
# Metadata-level: fires once per (rule x dataset) when ANY unique index
# value has a missing reference variable. P21 SDTM-IG 3.3 does NOT encode
# CDISC 102/103/104 explicitly; herald authors them from ADaMIG narrative.

op_any_index_missing_ref_var <- function(data, ctx, name,
                                         reference_dataset,
                                         name_template,
                                         placeholder = "xx") {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  if (is.null(data[[name]])) return(rep(NA, n))
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))

  vals <- suppressWarnings(as.integer(data[[name]]))
  uniq <- unique(vals[!is.na(vals)])
  if (length(uniq) == 0L) return(.dataset_level_mask(FALSE, n))

  # Format per ADaMIG convention: xx/zz = 2-digit zero-padded,
  # y/w = single digit unpadded.
  ph  <- tolower(as.character(placeholder %||% "xx"))
  fmt <- switch(ph,
                "xx" = "%02d", "zz" = "%02d",
                "y"  = "%d",   "w"  = "%d",
                "%02d")
  formatted <- sprintf(fmt, uniq)

  ph_tok <- placeholder
  expected_names <- vapply(formatted, function(v)
    gsub(ph_tok, v, name_template, fixed = TRUE),
    character(1L))

  ref_cols_upper <- toupper(names(ref_ds))
  missing_any <- any(!toupper(expected_names) %in% ref_cols_upper)
  .dataset_level_mask(isTRUE(missing_any), n)
}
.register_op(
  "any_index_missing_ref_var", op_any_index_missing_ref_var,
  meta = list(
    kind = "cross",
    summary = "For each unique value of the index column, the reference dataset is missing the templated variable",
    arg_schema = list(
      name              = list(type = "string", required = TRUE),
      reference_dataset = list(type = "string", required = TRUE),
      name_template     = list(type = "string", required = TRUE),
      placeholder       = list(type = "string", default  = "xx")
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_value_not_var_in_ref_dataset <- function(data, ctx, name,
                                             reference_dataset,
                                             name_suffix = NULL) {
  n <- nrow(data)
  if (is.null(data[[name]])) return(rep(NA, n))
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))
  ref_cols_upper <- toupper(names(ref_ds))
  values <- toupper(as.character(data[[name]]))
  values <- sub("\\s+$", "", values)

  is_empty <- is.na(values) | !nzchar(values)
  in_ref   <- values %in% ref_cols_upper
  fires    <- !in_ref

  if (!is.null(name_suffix) && nzchar(as.character(name_suffix))) {
    suffix_rx <- paste0(toupper(as.character(name_suffix)), "$")
    matches_suffix <- grepl(suffix_rx, values, perl = TRUE)
    fires <- fires | (in_ref & !matches_suffix)
  }
  fires[is_empty] <- NA
  fires
}
.register_op(
  "value_not_var_in_ref_dataset", op_value_not_var_in_ref_dataset,
  meta = list(
    kind = "cross",
    summary = "Value in `name` column is not a variable in `reference_dataset` (optionally with required suffix)",
    arg_schema = list(
      name              = list(type = "string", required = TRUE),
      reference_dataset = list(type = "string", required = TRUE),
      name_suffix       = list(type = "string", required = FALSE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

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

# --- subject_has_matching_row ----------------------------------------------
# For each row in the current dataset, returns TRUE when the reference
# dataset contains AT LEAST ONE row with the same key AND whose
# `reference_column` equals `expected_value`. Mirrors P21's val:Lookup
# `Variable="USUBJID == USUBJID" Where="<col> == 'VAL'"` -- existence of a
# satisfying row is the pass condition.
#
# Used as a guard leaf in compound trees (e.g. CG0132: "DM.DTHFL='Y' when
# SS.SSSTRESC='DEAD'" becomes
#   all: [subject_has_matching_row(SS.SSSTRESC='DEAD'), not_equal_to(DTHFL,'Y')]
# where the first leaf activates only for subjects with a DEAD SS record).
#
# rtrim-null applied to the reference column before comparison.

# --- arithmetic calc ops (CHG, PCHG, BCHG, PBCHG) --------------------------
# ADaM-IG defines CHG = AVAL - BASE (change from baseline), PCHG = ((AVAL -
# BASE) / BASE) * 100 (percent change), with symmetric BCHG / PBCHG forms
# reversing the operand direction. P21 expresses these with DSL functions
# :DIFF(a, b) and :PCTDIFF(a, b) evaluated under the fuzzy-eq operator
# @feq (Comparison.java:178-181 + Expression.java:45-62 alias map). Default
# epsilon 0.001 (DEFAULT_EPSILON in Comparison.java:38) or configurable
# via Engine.FuzzyTolerance.
#
# herald op_is_not_diff / op_is_not_pct_diff compute the expected value and
# fire TRUE when the stored value differs from the computed value by more
# than the epsilon (default 0.001 matching P21's default).

.nearly_equal <- function(a, b, epsilon = 0.001) {
  # Mirrors P21's `nearlyEqual` helper (Comparison.java). Both sides
  # must be finite numeric; NA on either side -> NA.
  out <- rep(NA, length(a))
  ok <- !is.na(a) & !is.na(b) & is.finite(a) & is.finite(b)
  out[ok] <- abs(a[ok] - b[ok]) <= epsilon
  out
}

op_is_not_diff <- function(data, ctx, name, minuend, subtrahend,
                           epsilon = 0.001) {
  n <- nrow(data)
  if (is.null(data[[name]]) || is.null(data[[minuend]]) ||
      is.null(data[[subtrahend]])) {
    return(rep(NA, n))
  }
  target <- suppressWarnings(as.numeric(data[[name]]))
  a      <- suppressWarnings(as.numeric(data[[minuend]]))
  b      <- suppressWarnings(as.numeric(data[[subtrahend]]))
  computed <- a - b
  eq <- .nearly_equal(target, computed, epsilon)
  out <- !eq
  # Rows where inputs are missing -> NA propagated from .nearly_equal.
  out
}
.register_op(
  "is_not_diff", op_is_not_diff,
  meta = list(
    kind = "cross",
    summary = "Stored `name` value does not equal (minuend - subtrahend) within epsilon",
    arg_schema = list(
      name       = list(type = "string",  required = TRUE),
      minuend    = list(type = "string",  required = TRUE),
      subtrahend = list(type = "string",  required = TRUE),
      epsilon    = list(type = "numeric", default  = 0.001)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_is_not_pct_diff <- function(data, ctx, name, minuend, subtrahend,
                               denominator = NULL, epsilon = 0.001) {
  n <- nrow(data)
  if (is.null(data[[name]]) || is.null(data[[minuend]]) ||
      is.null(data[[subtrahend]])) {
    return(rep(NA, n))
  }
  denom_col <- denominator %||% subtrahend
  if (is.null(data[[denom_col]])) return(rep(NA, n))
  target <- suppressWarnings(as.numeric(data[[name]]))
  a      <- suppressWarnings(as.numeric(data[[minuend]]))
  b      <- suppressWarnings(as.numeric(data[[subtrahend]]))
  d      <- suppressWarnings(as.numeric(data[[denom_col]]))
  # Guard against div-by-zero (P21 SD1... with When guard; herald
  # returns NA on those rows -> advisory).
  safe_d <- ifelse(!is.na(d) & d != 0, d, NA_real_)
  computed <- ((a - b) / safe_d) * 100
  eq <- .nearly_equal(target, computed, epsilon)
  out <- !eq
  out
}
.register_op(
  "is_not_pct_diff", op_is_not_pct_diff,
  meta = list(
    kind = "cross",
    summary = "Stored `name` value does not equal ((minuend - subtrahend) / denominator * 100) within epsilon",
    arg_schema = list(
      name        = list(type = "string",  required = TRUE),
      minuend     = list(type = "string",  required = TRUE),
      subtrahend  = list(type = "string",  required = TRUE),
      denominator = list(type = "string",  required = FALSE),
      epsilon     = list(type = "numeric", default  = 0.001)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_subject_has_matching_row <- function(data, ctx, name,
                                        reference_dataset,
                                        reference_column,
                                        expected_value,
                                        key = NULL, reference_key = NULL) {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))
  join_key     <- key %||% name
  ref_join_key <- reference_key %||% join_key
  if (is.null(data[[join_key]]) ||
      is.null(ref_ds[[ref_join_key]]) ||
      is.null(ref_ds[[reference_column]])) {
    return(rep(NA, n))
  }
  rtrim_null <- function(v) {
    v <- as.character(v)
    r <- sub("\\s+$", "", v)
    r[is.na(v) | !nzchar(r)] <- NA_character_
    r
  }
  ref_keys <- rtrim_null(ref_ds[[ref_join_key]])
  ref_vals <- rtrim_null(ref_ds[[reference_column]])
  target   <- as.character(expected_value)
  # Keys where ANY row has reference_column == expected_value
  matching <- ref_keys[!is.na(ref_keys) & !is.na(ref_vals) & ref_vals == target]
  matching_keys <- unique(matching)
  row_keys <- as.character(data[[join_key]])
  row_keys %in% matching_keys
}
.register_op(
  "subject_has_matching_row", op_subject_has_matching_row,
  meta = list(
    kind = "cross",
    summary = "Reference dataset has at least one row with matching key AND reference_column equal to expected_value",
    arg_schema = list(
      name               = list(type = "string", required = TRUE),
      reference_dataset  = list(type = "string", required = TRUE),
      reference_column   = list(type = "string", required = TRUE),
      expected_value     = list(type = "any",    required = TRUE),
      key                = list(type = "string", required = FALSE),
      reference_key      = list(type = "string", required = FALSE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)
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

# --- next-row adjacency op (Q29 / CG0207) ------------------------------------
# Within each group_by partition (e.g. USUBJID), rows are sorted by order_by
# (e.g. TAETORD). For each row i, the op checks that data[[name]][i] equals
# data[[prev_name]][i+1]. Fires TRUE on row i when the next row's `prev_name`
# differs from this row's `name`. The last row in each group always returns
# FALSE (no next row). NA rows propagate NA.
#
# CDISC rationale: in SE, there are no gaps between elements; therefore
# SEENDTC of element i == SESTDTC of element i+1 (CG0207).
#
# Arg shape in rules YAML:
#   operator: next_row_not_equal
#   name: SEENDTC
#   value:
#     prev_name: SESTDTC
#     order_by: TAETORD
#     group_by:
#       - USUBJID

op_next_row_not_equal <- function(data, ctx, name, value) {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  if (is.null(data[[name]])) return(rep(NA, n))

  # Unpack value sub-list
  if (!is.list(value)) {
    herald_error(
      c("Bad {.arg value} for `next_row_not_equal`.",
        "x" = "Must be a list with `prev_name`, `order_by`, and `group_by`."),
      class = "herald_error_input", call = rlang::caller_env()
    )
  }
  prev_name <- value$prev_name
  order_by  <- value$order_by %||% character(0)
  group_by  <- as.character(unlist(value$group_by %||% character(0)))

  if (is.null(prev_name) || !nzchar(as.character(prev_name))) {
    return(rep(NA, n))
  }
  if (is.null(data[[prev_name]])) return(rep(NA, n))

  # Build group key for partitioning
  if (length(group_by) == 0L) {
    grp_key <- rep("__all__", n)
  } else {
    missing_grp <- setdiff(group_by, names(data))
    if (length(missing_grp) > 0L) return(rep(NA, n))
    grp_key <- do.call(paste, c(lapply(group_by, function(g)
      .na_sent(as.character(data[[g]]))), list(sep = "\x1f")))
  }

  # Sort order within group
  if (length(order_by) == 0L || is.null(data[[order_by]])) {
    ord_vals <- seq_len(n)
  } else {
    ord_vals <- data[[order_by]]
  }

  out <- logical(n)

  # Process each partition independently
  groups <- unique(grp_key)
  for (g in groups) {
    idx <- which(grp_key == g)
    # Sort rows within group by order_by
    idx_sorted <- idx[order(ord_vals[idx])]
    m <- length(idx_sorted)
    if (m < 2L) {
      # Only one element -- no next row to compare; never fires
      out[idx_sorted] <- FALSE
      next
    }
    cur_vals  <- as.character(data[[name]][idx_sorted])
    next_vals <- as.character(data[[prev_name]][idx_sorted])
    # For row i (1..m-1): fires when cur_vals[i] != next_vals[i+1]
    # For row m (last): FALSE (no next element)
    fires <- logical(m)
    for (k in seq_len(m - 1L)) {
      a <- cur_vals[[k]]
      b <- next_vals[[k + 1L]]
      if (is.na(a) || is.na(b)) {
        fires[[k]] <- NA
      } else {
        fires[[k]] <- !.cdisc_value_equal(a, b)
      }
    }
    fires[[m]] <- FALSE
    out[idx_sorted] <- fires
  }
  out
}
.register_op(
  "next_row_not_equal", op_next_row_not_equal,
  meta = list(
    kind    = "cross",
    summary = "Current row `name` does not equal next row `prev_name` (within group ordered by order_by)",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "object", required = TRUE)
    ),
    cost_hint    = "O(n log n)",
    column_arg   = "name",
    returns_na_ok = TRUE
  )
)

# --- attr-reading ops (plan Q12/Q15/Q16) -------------------------------------
# These ops read column / dataset attributes that `apply_spec()`, the XPT
# reader, or the Dataset-JSON reader populate at ingest. Validation stays
# pure: no spec lookup happens at runtime. When an attribute is missing on
# either side, the op returns NA so the engine emits an advisory rather
# than a false fire.

# Friendly attribute names -> actual R attr keys used across readers.
.ATTR_KEY <- function(attribute) {
  map <- c(label  = "label",
           format = "format.sas",
           length = "sas.length",
           type   = "xpt_type")
  key <- as.character(attribute %||% "")
  unname(map[key]) %||% key
}

op_attr_mismatch <- function(data, ctx, name, attribute,
                             reference_dataset) {
  n <- nrow(data)
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))
  if (is.null(data[[name]]) || is.null(ref_ds[[name]])) {
    return(.dataset_level_mask(FALSE, n))
  }
  key <- .ATTR_KEY(attribute)
  a <- attr(data[[name]], key)
  b <- attr(ref_ds[[name]], key)
  if (is.null(a) || is.null(b)) return(rep(NA, n))
  .dataset_level_mask(!identical(a, b), n)
}
.register_op(
  "attr_mismatch", op_attr_mismatch,
  meta = list(
    kind = "cross",
    summary = "Column attribute differs between current and reference dataset",
    arg_schema = list(
      name              = list(type = "string", required = TRUE),
      attribute         = list(type = "string", required = TRUE),
      reference_dataset = list(type = "string", required = TRUE)
    ),
    cost_hint = "O(1)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_shared_attr_mismatch <- function(data, ctx, attribute,
                                    reference_dataset, exclude = NULL) {
  n <- nrow(data)
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))

  shared <- intersect(names(data), names(ref_ds))
  if (!is.null(exclude)) {
    shared <- setdiff(shared, as.character(exclude))
  }
  if (length(shared) == 0L) return(.dataset_level_mask(FALSE, n))

  key <- .ATTR_KEY(attribute)
  for (c in shared) {
    a <- attr(data[[c]], key)
    b <- attr(ref_ds[[c]], key)
    if (is.null(a) || is.null(b)) next
    if (!identical(a, b)) return(.dataset_level_mask(TRUE, n))
  }
  .dataset_level_mask(FALSE, n)
}
.register_op(
  "shared_attr_mismatch", op_shared_attr_mismatch,
  meta = list(
    kind = "cross",
    summary = "Any column shared with the reference dataset has a differing attribute",
    arg_schema = list(
      attribute         = list(type = "string", required = TRUE),
      reference_dataset = list(type = "string", required = TRUE),
      exclude           = list(type = "array",  required = FALSE)
    ),
    cost_hint = "O(n*m)", column_arg = NA_character_, returns_na_ok = TRUE
  )
)

op_dataset_label_not <- function(data, ctx, expected) {
  n <- nrow(data)
  lbl <- attr(data, "label")
  if (is.null(lbl)) return(rep(NA, n))
  .dataset_level_mask(
    toupper(trimws(as.character(lbl))) != toupper(trimws(as.character(expected))),
    n
  )
}
.register_op(
  "dataset_label_not", op_dataset_label_not,
  meta = list(
    kind = "existence",
    summary = "Dataset label (attr 'label') does not equal the expected string",
    arg_schema = list(
      expected = list(type = "string", required = TRUE)
    ),
    cost_hint = "O(1)", column_arg = NA_character_, returns_na_ok = TRUE
  )
)

# --- treatment-var absence across datasets (plan Q18) ------------------------

op_treatment_var_absent_across_datasets <- function(data, ctx,
                                                    current_vars,
                                                    reference_vars,
                                                    reference_dataset = "ADSL") {
  n <- nrow(data)
  curr <- toupper(as.character(unlist(current_vars)))
  curr_present <- any(curr %in% toupper(names(data)))
  if (curr_present) return(.dataset_level_mask(FALSE, n))

  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))

  ref_cols_up <- toupper(names(ref_ds))
  ref_templates <- as.character(unlist(reference_vars))
  ref_present <- FALSE
  phs <- names(.INDEX_PATTERNS)
  for (tmpl in ref_templates) {
    in_phs <- phs[vapply(phs, function(p)
      grepl(p, tmpl, fixed = TRUE), logical(1L))]
    if (length(in_phs) == 0L) {
      if (toupper(tmpl) %in% ref_cols_up) { ref_present <- TRUE; break }
      next
    }
    tuples <- .multi_values_in_cols(tmpl, names(ref_ds), in_phs)
    if (length(tuples) > 0L) { ref_present <- TRUE; break }
  }
  .dataset_level_mask(!ref_present, n)
}
.register_op(
  "treatment_var_absent_across_datasets", op_treatment_var_absent_across_datasets,
  meta = list(
    kind = "cross",
    summary = "None of the current-dataset treatment vars present AND none of the ADSL treatment vars present",
    arg_schema = list(
      current_vars      = list(type = "array",  required = TRUE),
      reference_vars    = list(type = "array",  required = TRUE),
      reference_dataset = list(type = "string", required = FALSE)
    ),
    cost_hint = "O(n*m)", column_arg = NA_character_, returns_na_ok = TRUE
  )
)

# --- per-subject indexed value check (plan Q19 / Q22 / Q23) ------------------
# TRTP/TRTA/APHASE/ASPER: the row value must match at least one of the
# templated columns in ADSL for the same subject (e.g. TRTP must match
# one of TRT01P / TRT02P / ... / TRTnnP in ADSL for this USUBJID).

op_value_not_in_subject_indexed_set <- function(data, ctx, name,
                                                reference_dataset,
                                                reference_template,
                                                key = "USUBJID",
                                                reference_key = NULL) {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  if (is.null(data[[name]])) return(rep(NA, n))
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))

  ref_key <- reference_key %||% key
  if (is.null(data[[key]]) || is.null(ref_ds[[ref_key]])) return(rep(NA, n))

  matching_cols <- .resolve_template_cols(reference_template, names(ref_ds))
  if (length(matching_cols) == 0L) return(rep(NA, n))

  rtrim <- function(v) {
    v <- as.character(v)
    r <- sub("\\s+$", "", v)
    r[is.na(v) | !nzchar(r)] <- NA_character_
    r
  }
  ref_keys_all <- rtrim(ref_ds[[ref_key]])
  subj_map <- new.env(hash = TRUE, parent = emptyenv())
  for (col in matching_cols) {
    vals <- rtrim(ref_ds[[col]])
    for (i in seq_along(ref_keys_all)) {
      s <- ref_keys_all[[i]]
      v <- vals[[i]]
      if (is.na(s) || is.na(v)) next
      prev <- subj_map[[s]]
      subj_map[[s]] <- unique(c(prev, v))
    }
  }

  row_keys <- rtrim(data[[key]])
  row_vals <- rtrim(data[[name]])
  out <- logical(n)
  for (i in seq_len(n)) {
    s <- row_keys[[i]]
    v <- row_vals[[i]]
    if (is.na(s) || is.na(v)) { out[[i]] <- NA; next }
    allowed <- subj_map[[s]]
    if (is.null(allowed)) { out[[i]] <- NA; next }
    out[[i]] <- !(v %in% allowed)
  }
  out
}
.register_op(
  "value_not_in_subject_indexed_set", op_value_not_in_subject_indexed_set,
  meta = list(
    kind = "cross",
    summary = "Row value is not in the set of subject-keyed values drawn from templated reference columns",
    arg_schema = list(
      name               = list(type = "string", required = TRUE),
      reference_dataset  = list(type = "string", required = TRUE),
      reference_template = list(type = "string", required = TRUE),
      key                = list(type = "string", required = FALSE),
      reference_key      = list(type = "string", required = FALSE)
    ),
    cost_hint = "O(n*m)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- per-row ref compare with subject-scoped + row-indexed template ---------
# ADaM-600 / ADaM-603 (ASPRSDTM / ASPREDTM): the reference column name is
# composed from placeholder values on the CURRENT row. E.g. for APERIOD=1,
# ASPER=2 the row's ASPRSDTM is compared against ADSL.P01S2SDM joined by
# USUBJID. Placeholder formatting follows ADaMIG conventions: xx/zz ->
# %02d, y/w -> %d.

op_not_equal_subject_templated_ref <- function(data, ctx, name,
                                               reference_dataset,
                                               reference_template,
                                               index_cols,
                                               key = "USUBJID",
                                               reference_key = NULL) {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  if (is.null(data[[name]])) return(rep(NA, n))
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))
  ref_key <- reference_key %||% key
  if (is.null(data[[key]]) || is.null(ref_ds[[ref_key]])) return(rep(NA, n))

  # index_cols may arrive from YAML as a named list (list(xx = "APERIOD",
  # w = "ASPER")) or a character vector whose names are placeholders.
  idx <- if (is.list(index_cols)) index_cols else as.list(index_cols)
  phs <- names(idx)
  if (is.null(phs) || !all(nzchar(phs))) return(rep(NA, n))
  missing_cols <- !vapply(idx, function(c) c %in% names(data), logical(1L))
  if (any(missing_cols)) return(rep(NA, n))

  key_rtrim <- function(v) {
    v <- as.character(v)
    r <- sub(" +$", "", v)
    r[is.na(v) | !nzchar(r)] <- NA_character_
    r
  }
  row_keys <- key_rtrim(data[[key]])
  # Row values are passed raw to .cdisc_value_equal which does its own
  # rtrim + datetime / numeric fuzzy equality.
  row_vals <- data[[name]]

  # Pre-compute per-row resolved template column name
  resolved <- rep(NA_character_, n)
  for (i in seq_len(n)) {
    tmpl <- reference_template
    ok <- TRUE
    for (ph in phs) {
      raw <- suppressWarnings(as.integer(data[[idx[[ph]]]][[i]]))
      if (is.na(raw)) { ok <- FALSE; break }
      fmt <- switch(tolower(ph),
                    "xx" = "%02d", "zz" = "%02d",
                    "y"  = "%d",   "w"  = "%d",
                    "%02d")
      tmpl <- gsub(ph, sprintf(fmt, raw), tmpl, fixed = TRUE)
    }
    if (ok) resolved[[i]] <- tmpl
  }

  # Build subject + column -> ref value map once (sparse across columns actually
  # referenced on rows).
  ref_keys_all <- key_rtrim(ref_ds[[ref_key]])
  unique_cols  <- unique(stats::na.omit(resolved))
  lookups <- new.env(hash = TRUE, parent = emptyenv())
  for (col in unique_cols) {
    if (!(col %in% names(ref_ds))) next
    vals <- as.character(ref_ds[[col]])
    ok   <- !is.na(ref_keys_all)
    lut  <- stats::setNames(vals[ok], ref_keys_all[ok])
    lut  <- lut[!duplicated(names(lut))]
    lookups[[col]] <- lut
  }

  out <- rep(NA, n)
  for (i in seq_len(n)) {
    col <- resolved[[i]]
    if (is.na(col)) next                 # index_cols had NA on this row
    lut <- lookups[[col]]
    if (is.null(lut)) next               # ref dataset lacks that column
    s <- row_keys[[i]]
    if (is.na(s)) next
    if (!(s %in% names(lut))) next       # subject not in ref -> advisory
    their <- unname(lut[s])
    eq <- .cdisc_value_equal(row_vals[[i]], their)
    if (is.na(eq)) next
    out[[i]] <- !eq
  }
  out
}
.register_op(
  "not_equal_subject_templated_ref", op_not_equal_subject_templated_ref,
  meta = list(
    kind = "cross",
    summary = "Row value differs from the reference-dataset value in a template-resolved column, joined by subject key",
    arg_schema = list(
      name               = list(type = "string", required = TRUE),
      reference_dataset  = list(type = "string", required = TRUE),
      reference_template = list(type = "string", required = TRUE),
      index_cols         = list(type = "object", required = TRUE),
      key                = list(type = "string", required = FALSE),
      reference_key      = list(type = "string", required = FALSE)
    ),
    cost_hint = "O(n*m)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- supp_row_count_exceeds (multi-row SUPP QNAM count) --------------------
# For each row in the current dataset, join to a supplemental dataset
# (SUPPDM / SUPPAE / ...) by a key column (default USUBJID), filter SUPP
# rows whose QNAM column matches a regex, count per key, fire when the
# per-key count exceeds `threshold`.
#
# Used by CDISC DM.RACE='MULTIPLE' rules (CG0140, CG0527) where the
# precondition is "multiple SUPPDM records with RACE-prefixed QNAM for
# the subject". P21 does not encode these -- herald authors them as
# predicate rules against the SUPP dataset row count.
#
# Arg shape in rules:
#   { name: "USUBJID", operator: "supp_row_count_exceeds",
#     ref_dataset: "SUPPDM", qnam_pattern: "^RACE", threshold: 1 }
#
# Missing SUPP dataset -> NA (advisory). No matching SUPP rows for a
# given key -> count 0 -> FALSE (no fire).

op_supp_row_count_exceeds <- function(data, ctx, ref_dataset, qnam_pattern,
                                      threshold = 1L, key = NULL,
                                      name = NULL) {
  n <- nrow(data)
  if (n == 0L) return(logical(0))

  # `name` is the conventional check_tree slot for the primary-variable
  # column; for this op it doubles as the join key when `key` is not
  # specified explicitly. Default is USUBJID when neither is supplied.
  join_key <- key %||% name %||% "USUBJID"

  ref_ds <- .ref_ds(ctx, ref_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))

  if (is.null(data[[join_key]]) ||
      is.null(ref_ds[[join_key]]) ||
      is.null(ref_ds[["QNAM"]])) {
    return(rep(NA, n))
  }

  thr <- suppressWarnings(as.integer(threshold))
  if (length(thr) != 1L || is.na(thr)) thr <- 1L

  qnam_rx <- as.character(qnam_pattern)
  hits    <- grepl(qnam_rx, as.character(ref_ds[["QNAM"]]), perl = TRUE)
  keys_hit <- as.character(ref_ds[[join_key]])[hits]
  keys_hit <- keys_hit[!is.na(keys_hit)]

  if (length(keys_hit) == 0L) {
    return(rep(FALSE, n))
  }
  # tabulate by key; strip the `table` class to keep the op's return a
  # plain logical vector (expect_equal compares dim/class).
  counts <- as.integer(table(keys_hit))
  names(counts) <- names(table(keys_hit))

  row_keys <- as.character(data[[join_key]])
  row_counts <- unname(counts[row_keys])
  row_counts[is.na(row_counts)] <- 0L
  out <- row_counts > thr
  as.logical(out)
}
.register_op(
  "supp_row_count_exceeds", op_supp_row_count_exceeds,
  meta = list(
    kind = "cross",
    summary = "Supplemental dataset has more than `threshold` rows whose QNAM matches `qnam_pattern` for the row's key",
    arg_schema = list(
      ref_dataset  = list(type = "string",  required = TRUE),
      qnam_pattern = list(type = "string",  required = TRUE),
      threshold    = list(type = "integer", default  = 1L),
      name         = list(type = "string",  required = FALSE),
      key          = list(type = "string",  required = FALSE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- shared values per key (plan Q12 / ADaM-591) -----------------------------
# For each column shared between the current dataset and the reference
# dataset, join by subject key and fire any row whose value differs from
# the subject's reference value. Per-row semantics: a row fires if ANY
# shared column mismatches; NA when no comparison was possible for any
# shared column (subject missing from reference, etc.).

op_shared_values_mismatch_by_key <- function(data, ctx,
                                             reference_dataset,
                                             key = "USUBJID",
                                             reference_key = NULL,
                                             exclude = NULL) {
  n <- nrow(data)
  if (n == 0L) return(logical(0))
  ref_ds <- .ref_ds(ctx, reference_dataset)
  if (is.null(ref_ds)) return(rep(NA, n))

  ref_key <- reference_key %||% key
  if (is.null(data[[key]]) || is.null(ref_ds[[ref_key]])) return(rep(NA, n))

  shared <- intersect(names(data), names(ref_ds))
  shared <- setdiff(shared, c(key, ref_key))
  if (!is.null(exclude)) shared <- setdiff(shared, as.character(exclude))
  if (length(shared) == 0L) return(rep(FALSE, n))

  # Keys are always rtrimmed + upper-cased (CDISC USUBJID identifiers are
  # case-sensitive but trailing spaces are non-semantic per P21's rtrim).
  key_rtrim <- function(v) {
    v <- as.character(v)
    r <- sub(" +$", "", v)
    r[is.na(v) | !nzchar(r)] <- NA_character_
    r
  }
  ref_keys <- key_rtrim(ref_ds[[ref_key]])
  row_keys <- key_rtrim(data[[key]])

  # A row's subject must be present in the reference for any compare to
  # matter. When the subject is absent, P21's Lookup short-circuits
  # (LookupValidationRule: no-match -> rule-disable, not fire). Herald
  # turns that into a row-NA -> advisory.
  known_keys  <- unique(ref_keys[!is.na(ref_keys)])
  subj_in_ref <- row_keys %in% known_keys

  fire     <- logical(n)
  compared <- logical(n)

  for (col in shared) {
    ok <- !is.na(ref_keys)
    lut <- stats::setNames(as.character(ref_ds[[col]])[ok], ref_keys[ok])
    lut <- lut[!duplicated(names(lut))]
    their <- unname(lut[row_keys])
    eq    <- .cdisc_value_equal(data[[col]], their)
    # A comparison counts only for rows whose subject is in the ref AND
    # .cdisc_value_equal produced a non-NA verdict.
    ok_cmp <- subj_in_ref & !is.na(eq)
    fire     <- fire     | (ok_cmp & !eq)
    compared <- compared | ok_cmp
  }

  out <- fire
  out[!compared] <- NA
  out
}
.register_op(
  "shared_values_mismatch_by_key", op_shared_values_mismatch_by_key,
  meta = list(
    kind = "cross",
    summary = "Any shared column value differs from the reference dataset value joined by subject key",
    arg_schema = list(
      reference_dataset = list(type = "string", required = TRUE),
      key               = list(type = "string", required = FALSE),
      reference_key     = list(type = "string", required = FALSE),
      exclude           = list(type = "array",  required = FALSE)
    ),
    cost_hint = "O(n*m)", column_arg = NA_character_, returns_na_ok = TRUE
  )
)

# --- op_study_metadata_is ---------------------------------------------------
# Submission-level guard for "IF study collected domain X THEN dataset Y is
# required" rules (CG0191 MB, CG0318 PC).
#
# ctx$study_metadata is a named list supplied via validate(study_metadata=...).
# The op checks whether study_metadata[[key]] contains value (character
# membership, case-insensitive). When study_metadata is NULL the op returns
# NA for every row -- advisory ("supply study_metadata to evaluate this rule").
#
# CDISC semantics: the collected_domains key is a character vector of domain
# codes (e.g. c("MB","PC","LB")). The op fires (TRUE) when the study collected
# that domain, so the paired not_exists check can then fire the finding.

op_study_metadata_is <- function(data, ctx, key, value) {
  n <- nrow(data)
  md <- if (!is.null(ctx)) ctx$study_metadata else NULL
  if (is.null(md)) {
    # No study metadata supplied -- return NA (advisory) for every row so the
    # parent all: combinator bubbles NA upward and the finding is advisory.
    return(rep(NA, n))
  }
  entry <- md[[as.character(key)]]
  if (is.null(entry)) return(rep(FALSE, n))
  matched <- toupper(as.character(value)) %in% toupper(as.character(entry))
  rep(isTRUE(matched), n)
}
.register_op(
  "study_metadata_is", op_study_metadata_is,
  meta = list(
    kind     = "cross",
    summary  = "TRUE when study_metadata[[key]] contains value; NA when study_metadata not supplied",
    arg_schema = list(
      key   = list(type = "string",  required = TRUE),
      value = list(type = "string",  required = TRUE)
    ),
    cost_hint     = "O(1)",
    column_arg    = NULL,
    returns_na_ok = TRUE
  )
)

# --- op_ref_column_domains_exist --------------------------------------------
# Per-row (of reference dataset): fires when the domain code in
# reference_column is NOT present as a loaded dataset.
#
# Use-cases:
#   CG0373: every SUPP-- dataset's RDOMAIN value must be a present domain.
#   CG0374: every RELREC row's RDOMAIN value must be a present domain.
#
# The op is evaluated against the reference dataset (RELREC, or any SUPP--
# dataset) directly. Each row carries a domain code in `reference_column`;
# the op fires (TRUE) when that domain is not among names(ctx$datasets).
# If the column is absent, returns NA for all rows (advisory).

op_ref_column_domains_exist <- function(data, ctx, reference_column) {
  n <- nrow(data)
  col <- as.character(reference_column)
  vals <- data[[col]]
  if (is.null(vals)) return(rep(NA, n))
  ds_names <- if (!is.null(ctx) && !is.null(ctx$datasets)) {
    toupper(names(ctx$datasets))
  } else character(0)
  # Fire when the domain code is not among submission datasets.
  # NA values in vals produce NA (advisory) per-row.
  vapply(vals, function(v) {
    if (is.na(v) || !nzchar(trimws(as.character(v)))) return(NA)
    !toupper(trimws(as.character(v))) %in% ds_names
  }, logical(1L))
}
.register_op(
  "ref_column_domains_exist", op_ref_column_domains_exist,
  meta = list(
    kind     = "cross",
    summary  = "Fires per row when the domain code in reference_column is not a loaded dataset",
    arg_schema = list(
      reference_column = list(type = "string", required = TRUE)
    ),
    cost_hint     = "O(n)",
    column_arg    = "reference_column",
    returns_na_ok = TRUE
  )
)

# --- is_not_constant_per_group -----------------------------------------------
# Fires rows whose outer group (defined by group_by columns) has >1 distinct
# non-NA value of `name`. Semantics: within each combination of group_by
# values, the `name` column must be constant (single distinct non-NA value).
# If the group has only NA values in `name` it is not flagged. If the `name`
# column is absent returns NA for all rows (advisory).
#
# Shape covered: "Within a given value of PARAMCD, there is more than one
# value of <X>" -- e.g. CRITy, BASETYPE.
#
# Arg shape in rules:
#   { name: "CRITy", operator: "is_not_constant_per_group",
#     group_by: [PARAMCD] }

op_is_not_constant_per_group <- function(data, ctx, name, group_by) {
  n <- nrow(data)
  if (n == 0L) return(logical(0L))
  if (is.null(data[[name]])) return(rep(NA, n))

  grp_cols <- as.character(unlist(group_by %||% character(0L)))
  missing_grp <- setdiff(grp_cols, names(data))
  if (length(missing_grp) > 0L) return(rep(NA, n))

  # rtrim-null mirrors Pinnacle 21 convention.
  .rtrim_null <- function(v) {
    if (!is.character(v)) return(as.character(v))
    r <- sub("\\s+$", "", v)
    r[is.na(v) | !nzchar(r)] <- NA_character_
    r
  }

  x <- .rtrim_null(data[[name]])

  if (length(grp_cols) == 0L) {
    group_key <- rep("", n)
  } else {
    group_key <- do.call(paste, c(
      lapply(grp_cols, function(g) .na_sent(.rtrim_null(data[[g]]))),
      list(sep = "\x1f")
    ))
  }

  # For each group_key, count distinct non-NA values of x.
  df <- data.frame(g = group_key, x = x, stringsAsFactors = FALSE)
  df_ok <- df[!is.na(df$x), , drop = FALSE]
  if (nrow(df_ok) == 0L) return(rep(FALSE, n))

  counts <- tapply(df_ok$x, df_ok$g, function(v) length(unique(v)))
  bad_keys <- names(counts)[counts > 1L]
  group_key %in% bad_keys
}
.register_op(
  "is_not_constant_per_group", op_is_not_constant_per_group,
  meta = list(
    kind = "cross",
    summary = "Within each group_by bucket, `name` has more than one distinct non-NA value",
    arg_schema = list(
      name     = list(type = "string", required = TRUE),
      group_by = list(type = "array",  required = TRUE)
    ),
    cost_hint = "O(n log n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- no_baseline_record ------------------------------------------------------
# Fires rows in groups (defined by group_by) where:
#   (a) the `name` column is populated on at least one row, AND
#   (b) NO row in that group has `flag_var == flag_value`.
#
# Shape covered: "Within a given value of PARAMCD for a subject, BASE is
# populated and there is not at least one record where ABLFL='Y'".
#
# If `name` or `flag_var` column is absent, returns NA for all rows.
#
# Arg shape in rules:
#   { name: "BASE", operator: "no_baseline_record",
#     flag_var: "ABLFL", flag_value: "Y",
#     group_by: [PARAMCD, USUBJID] }

op_no_baseline_record <- function(data, ctx, name, flag_var, flag_value,
                                  group_by) {
  n <- nrow(data)
  if (n == 0L) return(logical(0L))
  if (is.null(data[[name]]) || is.null(data[[flag_var]])) {
    return(rep(NA, n))
  }

  grp_cols <- as.character(unlist(group_by %||% character(0L)))
  missing_grp <- setdiff(grp_cols, names(data))
  if (length(missing_grp) > 0L) return(rep(NA, n))

  .rtrim_null <- function(v) {
    if (!is.character(v)) return(as.character(v))
    r <- sub("\\s+$", "", v)
    r[is.na(v) | !nzchar(r)] <- NA_character_
    r
  }

  nm_vals  <- .rtrim_null(data[[name]])
  flg_vals <- .rtrim_null(data[[flag_var]])
  fv       <- as.character(flag_value)

  if (length(grp_cols) == 0L) {
    group_key <- rep("", n)
  } else {
    group_key <- do.call(paste, c(
      lapply(grp_cols, function(g) .na_sent(.rtrim_null(data[[g]]))),
      list(sep = "\x1f")
    ))
  }

  # Determine which group keys:
  #   (a) have at least one populated `name` row
  #   (b) have at least one row where flag_var == flag_value
  keys_with_name <- unique(group_key[!is.na(nm_vals)])
  keys_with_flag <- unique(group_key[!is.na(flg_vals) & flg_vals == fv])

  # Fire rows in groups that have `name` populated somewhere but lack the
  # baseline flag record.
  bad_keys <- setdiff(keys_with_name, keys_with_flag)
  group_key %in% bad_keys
}
.register_op(
  "no_baseline_record", op_no_baseline_record,
  meta = list(
    kind = "cross",
    summary = "Group has `name` populated on at least one row but no row with flag_var equal to flag_value",
    arg_schema = list(
      name       = list(type = "string", required = TRUE),
      flag_var   = list(type = "string", required = TRUE),
      flag_value = list(type = "string", required = TRUE),
      group_by   = list(type = "array",  required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- base_not_equal_abl_row ---------------------------------------------------
# Fires when b_var is populated AND b_var != a_var on the group's anchor row
# (the row where abl_col == abl_value). This is the ADaM baseline-consistency
# check: BASE must equal AVAL on the record flagged by ABLFL='Y' within each
# PARAMCD+USUBJID group.
#
# basetype_gate values:
#   "absent"    -- entire dataset skipped when BASETYPE column is present
#   "populated" -- only rows where BASETYPE is non-null are evaluated
#   "any"       -- no gate (default)
#
# Returns NA (advisory) for rows whose group has no anchor row.
#
# Arg shape in rules:
#   { operator: "base_not_equal_abl_row",
#     b_var: "BASE", a_var: "AVAL",
#     group_by: [USUBJID, PARAMCD],
#     basetype_gate: "absent" }

op_base_not_equal_abl_row <- function(data, ctx, b_var, a_var,
                                       group_by,
                                       abl_col = "ABLFL",
                                       abl_value = "Y",
                                       basetype_gate = "any") {
  n <- nrow(data)
  if (n == 0L) return(logical(0L))

  gate <- as.character(basetype_gate %||% "any")

  # Dataset-level gate: skip when BASETYPE column is present
  if (gate == "absent" && "BASETYPE" %in% names(data))
    return(rep(FALSE, n))

  if (is.null(data[[b_var]]) || is.null(data[[a_var]]) || is.null(data[[abl_col]]))
    return(rep(NA, n))

  grp_cols <- as.character(unlist(group_by %||% character(0L)))
  if (length(setdiff(grp_cols, names(data))) > 0L) return(rep(NA, n))

  .rtrim_null <- function(v) {
    if (!is.character(v)) return(as.character(v))
    r <- sub("\\s+$", "", v)
    r[is.na(v) | !nzchar(r)] <- NA_character_
    r
  }

  b_vals   <- .rtrim_null(data[[b_var]])
  a_vals   <- .rtrim_null(data[[a_var]])
  abl_vals <- .rtrim_null(data[[abl_col]])

  group_key <- if (length(grp_cols) == 0L) {
    rep("", n)
  } else {
    do.call(paste, c(lapply(grp_cols, function(g) .na_sent(.rtrim_null(data[[g]]))),
                     list(sep = "\x1f")))
  }

  # Build anchor map: first anchor row per group -> a_var value
  is_anchor  <- !is.na(abl_vals) & abl_vals == as.character(abl_value)
  anch_gk    <- group_key[is_anchor]
  anch_av    <- a_vals[is_anchor]
  uniq_anch  <- !duplicated(anch_gk)
  anchor_map <- setNames(anch_av[uniq_anch], anch_gk[uniq_anch])

  # Active rows: b_var populated + optional row-level basetype gate
  active <- !is.na(b_vals)
  if (gate == "populated" && "BASETYPE" %in% names(data))
    active <- active & !is.na(.rtrim_null(data$BASETYPE))

  out <- rep(FALSE, n)
  ai  <- which(active)
  if (length(ai) == 0L) return(out)

  gk_ai     <- group_key[ai]
  no_anchor <- !gk_ai %in% names(anchor_map)
  out[ai[no_anchor]] <- NA

  has_idx <- ai[!no_anchor]
  if (length(has_idx) == 0L) return(out)

  b_cmp <- b_vals[has_idx]
  a_cmp <- unname(anchor_map[group_key[has_idx]])
  eq    <- .cdisc_value_equal(b_cmp, a_cmp)
  out[has_idx] <- !eq   # !TRUE=FALSE (pass), !FALSE=TRUE (fire), !NA=NA (advisory)

  out
}
.register_op(
  "base_not_equal_abl_row", op_base_not_equal_abl_row,
  meta = list(
    kind    = "cross",
    summary = "b_var is populated and not equal to a_var on the anchor row (abl_col==abl_value) within each group",
    arg_schema = list(
      b_var         = list(type = "string", required = TRUE),
      a_var         = list(type = "string", required = TRUE),
      group_by      = list(type = "array",  required = TRUE),
      abl_col       = list(type = "string", default = "ABLFL"),
      abl_value     = list(type = "string", default = "Y"),
      basetype_gate = list(type = "string", default = "any")
    ),
    cost_hint = "O(n)", column_arg = "b_var", returns_na_ok = TRUE
  )
)

#' Resolve a templated column name (e.g. "TRTxxP" or "PxxSw") against a
#' dataset's column list. Returns the concrete column names that match.
#' @noRd
.resolve_template_cols <- function(template, cols) {
  phs <- names(.INDEX_PATTERNS)
  in_phs <- phs[vapply(phs, function(p)
    grepl(p, template, fixed = TRUE), logical(1L))]
  if (length(in_phs) == 0L) {
    return(if (template %in% cols) template else character(0))
  }
  tuples <- .multi_values_in_cols(template, cols, in_phs)
  out <- character()
  for (tup in tuples) {
    resolved <- template
    for (ph in names(tup)) {
      if (is.na(tup[[ph]])) next
      resolved <- gsub(ph, tup[[ph]], resolved, fixed = TRUE)
    }
    if (resolved %in% cols) out <- c(out, resolved)
  }
  unique(out)
}

# ---- has_same_values (was ops-has-same-values.R) -------------------------------
# Returns TRUE for every row when ALL records in the dataset have the same
# value for the named column. This fires when a classification variable like
# --CAT or MHCAT groups ALL records into one bucket (which indicates overuse).
# Unlocks: CG0077 (MHCAT must not group all records into a single category).

op_has_same_values <- function(data, ctx, name, ...) {
  col <- name
  if (!col %in% names(data)) return(rep(NA, nrow(data)))
  vals <- as.character(data[[col]])
  vals <- vals[!is.na(vals) & nzchar(vals)]
  if (length(vals) == 0L) return(rep(NA, nrow(data)))
  rep(length(unique(vals)) == 1L, nrow(data))
}

.register_op(
  "has_same_values",
  op_has_same_values,
  meta = list(
    kind       = "existence",
    summary    = "TRUE when all non-NA rows share the same value (over-grouping check).",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint     = "O(n)",
    column_arg    = "name",
    returns_na_ok = TRUE
  )
)

# ---- not_present_on_multiple_rows_within (was ops-not-present-on-multiple-rows.R)
# Returns TRUE for RELID values that appear on FEWER THAN 2 rows within the
# USUBJID group. The RELREC rule requires that each RELID appear on at least 2
# rows (to form the relationship pair). Fires when a RELID has only 1 row.
# Unlocks: CG0484 / CORE-000484.

op_not_present_on_multiple_rows_within <- function(data, ctx, name,
                                                    within = "USUBJID", ...) {
  col     <- name
  grp_col <- as.character(unlist(within, use.names = FALSE))[[1L]]
  n       <- nrow(data)
  if (!col %in% names(data)) return(rep(NA, n))
  vals <- as.character(data[[col]])
  grp  <- if (grp_col %in% names(data)) as.character(data[[grp_col]]) else rep("", n)
  key  <- paste(grp, vals, sep = "\x1F")
  counts <- table(key)
  out <- vapply(key, function(k) {
    if (is.na(vals[match(k, key)])) return(NA)
    counts[[k]] < 2L
  }, logical(1L), USE.NAMES = FALSE)
  out
}

.register_op(
  "not_present_on_multiple_rows_within",
  op_not_present_on_multiple_rows_within,
  meta = list(
    kind       = "existence",
    summary    = "TRUE when the value appears on fewer than 2 rows within each group.",
    arg_schema = list(
      name   = list(type = "string", required = TRUE),
      within = list(type = "string", default  = "USUBJID")
    ),
    cost_hint     = "O(n)",
    column_arg    = "name",
    returns_na_ok = TRUE
  )
)

# ---- inconsistent_enumerated_columns (was ops-inconsistent-enumerated-columns.R)
# For enumerated columns like TSVAL, TSVAL1..TSVALn: returns TRUE on rows
# where TSVALn+1 is non-null while TSVALn is null (gap in sequence).
# Detected by scanning column names matching the pattern + base name.
# Unlocks: CG0582 (CORE-000582) -- TSVAL enumerated column gaps.
#
# params: name (base column name, e.g. "TSVAL").

op_inconsistent_enumerated_columns <- function(data, ctx, name, ...) {
  base <- name
  n    <- nrow(data)
  # Find enumerated columns: <base>1, <base>2, ... (case-insensitive)
  pattern  <- paste0("^", toupper(base), "[0-9]+$")
  cols_idx <- grep(pattern, toupper(names(data)))
  if (length(cols_idx) == 0L) return(rep(FALSE, n))

  # Sort by numeric suffix
  nums <- as.integer(gsub(paste0("^", toupper(base)), "", toupper(names(data)[cols_idx])))
  ord  <- order(nums)
  cols_sorted <- names(data)[cols_idx[ord]]

  out <- rep(FALSE, n)
  for (i in seq_along(cols_sorted)[-1L]) {
    prev_col <- cols_sorted[[i - 1L]]
    curr_col <- cols_sorted[[i]]
    prev_val <- as.character(data[[prev_col]])
    curr_val <- as.character(data[[curr_col]])
    gap <- is.na(prev_val) & !is.na(curr_val) & nzchar(curr_val)
    out <- out | gap
  }
  out
}

.register_op(
  "inconsistent_enumerated_columns",
  op_inconsistent_enumerated_columns,
  meta = list(
    kind       = "existence",
    summary    = "TRUE when an enumerated column gap exists (n+1 non-null while n null).",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint     = "O(n*m)",
    column_arg    = "name",
    returns_na_ok = FALSE
  )
)

# ---- target_is_not_sorted_by (was ops-target-is-not-sorted-by.R) ---------------
# Returns TRUE for rows where the column is NOT in ascending order within
# the grouping key(s). Used to check that --SEQ is non-decreasing within
# USUBJID (or similar grouping).
# Unlocks: CG0662, CG0620 (--SEQ must be in chronological/numeric order).
#
# params: name (column to check), order_by (grouping column(s), typically USUBJID).

op_target_is_not_sorted_by <- function(data, ctx, name,
                                        order_by = "USUBJID", ...) {
  col     <- name
  grp_col <- as.character(unlist(order_by, use.names = FALSE))[[1L]]
  n       <- nrow(data)
  if (!col %in% names(data)) return(rep(NA, n))
  # Group by grp_col; within each group check ascending order of col.
  vals <- suppressWarnings(as.numeric(as.character(data[[col]])))
  grp  <- if (grp_col %in% names(data)) as.character(data[[grp_col]]) else rep("", n)
  out  <- rep(FALSE, n)
  for (g in unique(grp[!is.na(grp)])) {
    idx <- which(grp == g)
    v   <- vals[idx]
    not_sorted <- c(FALSE, diff(v) < 0L)
    prev_na    <- c(FALSE, is.na(v[-length(v)]))
    not_sorted[is.na(v) | prev_na] <- NA
    out[idx] <- not_sorted
  }
  out
}

.register_op(
  "target_is_not_sorted_by",
  op_target_is_not_sorted_by,
  meta = list(
    kind       = "compare",
    summary    = "TRUE on rows where the column breaks ascending order within each group.",
    arg_schema = list(
      name     = list(type = "string", required = TRUE),
      order_by = list(type = "string", default  = "USUBJID")
    ),
    cost_hint     = "O(n log n)",
    column_arg    = "name",
    returns_na_ok = TRUE
  )
)
