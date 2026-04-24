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
  # "exists(DS.VAR)" -- cross-dataset column presence.
  # If name contains exactly one ".", split into (ds, col) and check
  # whether col exists in the reference dataset.
  if (is.character(name) && length(name) == 1L && grepl("^[A-Z][A-Z0-9]{1,3}\\.[A-Z][A-Z0-9_]*$", name)) {
    parts <- strsplit(name, ".", fixed = TRUE)[[1L]]
    ref_ds <- .ref_ds(ctx, parts[[1L]])
    if (is.null(ref_ds)) return(.dataset_level_mask(FALSE, n))
    return(.dataset_level_mask(
      isTRUE(toupper(parts[[2L]]) %in% toupper(names(ref_ds))), n))
  }
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
  # "non_empty" means: not NA AND (for character) the right-trimmed value
  # is not "". Mirrors Pinnacle 21's rtrim-then-null-check convention
  # (DataEntryFactory.java:70-71): trailing whitespace collapses a string
  # to null ("   " is null, "   text" is populated, "text   " -> "text").
  # Leading whitespace is preserved. "0", "NA", "null" are literal strings
  # and count as populated.
  if (is.character(values)) {
    !is.na(values) & nzchar(sub("\\s+$", "", values))
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
    # Mirror P21's right-trim-then-null-check: "   " counts as empty,
    # "   text" is populated, "text   " is populated (the trimmed value
    # "text" is non-empty). "0", "NA", "null" are literal strings and
    # count as populated (not empty).
    is.na(values) | !nzchar(sub("\\s+$", "", values))
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

# --- label-content metadata check (ADaMIG section 3 label conventions) ------
# CDISC ADaMIG specifies that variables following certain naming conventions
# must carry a label containing a canonical phrase -- e.g. a variable ending
# in *DT must have "Date" somewhere in its label, *TM must have "Time", etc.
# (ADaMIG v1.1 Section 3.1.6, Item 2: "{Time}" bracket convention.)
#
# P21 models metadata-level checks via val:Regex Target="Metadata"
# Variable="LABEL". The concept is: project variable metadata as a derived
# dataset with columns {DOMAIN, VARIABLE, TYPE, LENGTH, LABEL, ...} (see
# Metadata.java:30-39), then regex the LABEL column. We take the concept
# and re-express it here by self-iterating suffix-matching columns and
# reading each column's `label` attribute -- no XML or Java copy.
#
# P21 parity (cross-checked against DataEntryFactory.java:69-79,313-328 and
# RegularExpressionValidationRule.java:55-77):
#   * Column names are compared UPPERCASE (Metadata.java:138,163,185 uppercase
#     every variable name on load and lookup).
#   * Labels are right-trimmed; a label that is all-spaces becomes null
#     (rtrim() at line 313-328 returns null when every char is a space).
#   * When the label is null / empty after rtrim, the rule SKIPS (returns
#     pass), mirroring `entry.hasValue()` at RegularExpressionValidationRule
#     line 62. Missing-label quality is a separate concern for a dedicated
#     rule (e.g. AD0016-style length check).
#   * The phrase match is case-sensitive: CDISC text quotes the phrase in
#     title case ("Date", "Start Date", ...) and P21's Pattern.compile(...)
#     has no (?i) flag.
op_label_by_suffix_missing <- function(data, ctx, suffix, value) {
  n <- nrow(data)
  cols <- names(data)
  if (length(cols) == 0L || !nzchar(as.character(suffix %||% ""))) {
    return(.dataset_level_mask(FALSE, n))
  }
  tail_rx <- paste0(toupper(as.character(suffix)), "$")
  match_cols <- cols[grepl(tail_rx, toupper(cols), perl = TRUE)]
  if (length(match_cols) == 0L) {
    return(.dataset_level_mask(FALSE, n))
  }
  phrase <- as.character(value %||% "")
  violated <- FALSE
  for (col in match_cols) {
    lbl <- attr(data[[col]], "label")
    lbl <- if (is.null(lbl)) "" else as.character(lbl)[[1L]]
    # P21 rtrim: trailing spaces (ASCII 0x20) only; an all-spaces label
    # becomes null and the rule skips rather than fires.
    lbl <- sub(" +$", "", lbl)
    if (is.na(lbl) || !nzchar(lbl)) next
    if (!grepl(phrase, lbl, fixed = TRUE)) {
      violated <- TRUE
      break
    }
  }
  .dataset_level_mask(violated, n)
}
.register_op(
  "label_by_suffix_missing", op_label_by_suffix_missing,
  meta = list(
    kind = "existence",
    summary = "Fires when any variable whose name ends in `suffix` has a label that does not contain `value`",
    arg_schema = list(
      suffix = list(type = "string", required = TRUE),
      value  = list(type = "string", required = TRUE)
    ),
    cost_hint = "O(1)",
    column_arg = NA_character_,
    returns_na_ok = FALSE,
    examples = list(list(suffix = "DT", value = "Date"))
  )
)

# --- any_var_name_exceeds_length -------------------------------------------
# Metadata-level: fires once per dataset when at least one column name
# exceeds `value` characters in length. Mirrors P21's val:Regex Target=
# Metadata Variable=VARIABLE Test="[A-Z][A-Z0-9_]{0,N-1}" (AD0013) --
# P21 projects the variable list as a virtual dataset and regex-fails
# any name longer than N chars. herald iterates names(data) directly.
#
# SDTM/ADaM convention: variable names must be <= 8 characters (SAS XPT v5
# limit). ADaMIG Section 3.1.6 / SDTMIG Section 2.2.2.

op_any_var_name_exceeds_length <- function(data, ctx, value) {
  n <- nrow(data)
  cols <- names(data)
  if (length(cols) == 0L) return(.dataset_level_mask(FALSE, n))
  lim <- suppressWarnings(as.integer(value))
  if (is.na(lim) || lim < 0L) return(.dataset_level_mask(FALSE, n))
  violated <- any(nchar(cols, type = "bytes") > lim, na.rm = TRUE)
  .dataset_level_mask(isTRUE(violated), n)
}
.register_op(
  "any_var_name_exceeds_length", op_any_var_name_exceeds_length,
  meta = list(
    kind = "existence",
    summary = "Fires when any variable name exceeds the byte-length cap",
    arg_schema = list(value = list(type = "integer", required = TRUE)),
    cost_hint = "O(1)",
    column_arg = NA_character_,
    returns_na_ok = FALSE
  )
)

# --- any_var_label_exceeds_length ------------------------------------------
# Metadata-level: fires once per dataset when at least one column's label
# attribute exceeds `value` characters. Mirrors P21's AD0016:
#   val:Regex Target=Metadata Variable=LABEL Test=".{0,40}"
# which projects labels and regex-fails any longer than 40 chars.
# Null / missing labels are skipped (matching P21's hasValue() skip at
# RegularExpressionValidationRule.java:62).

op_any_var_label_exceeds_length <- function(data, ctx, value) {
  n <- nrow(data)
  cols <- names(data)
  if (length(cols) == 0L) return(.dataset_level_mask(FALSE, n))
  lim <- suppressWarnings(as.integer(value))
  if (is.na(lim) || lim < 0L) return(.dataset_level_mask(FALSE, n))
  violated <- FALSE
  for (col in cols) {
    lbl <- attr(data[[col]], "label")
    if (is.null(lbl)) next
    lbl <- as.character(lbl)[[1L]]
    # rtrim P21-parity: all-spaces label becomes null and skips.
    lbl <- sub(" +$", "", lbl)
    if (is.na(lbl) || !nzchar(lbl)) next
    if (nchar(lbl, type = "bytes") > lim) {
      violated <- TRUE; break
    }
  }
  .dataset_level_mask(isTRUE(violated), n)
}
.register_op(
  "any_var_label_exceeds_length", op_any_var_label_exceeds_length,
  meta = list(
    kind = "existence",
    summary = "Fires when any variable label exceeds the byte-length cap",
    arg_schema = list(value = list(type = "integer", required = TRUE)),
    cost_hint = "O(1)",
    column_arg = NA_character_,
    returns_na_ok = FALSE
  )
)

# --- any_value_exceeds_length ----------------------------------------------
# Row-level: for each row, fires when at least one CHARACTER column has a
# value whose byte-length exceeds `value`. SAS XPT v5 limits character
# values to 200 bytes; values longer than that indicate a truncation risk
# or require SUPPQUAL splitting (SDTMIG s.4.1.5.3.2).
#
# P21 SD1096 uses val:Lookup to detect 200-char values and check SUPPQUAL;
# herald's simpler check fires on any row with a >200-char cell in any
# char column. Reviewer handles SUPPQUAL pairing as a separate step.

op_any_value_exceeds_length <- function(data, ctx, value) {
  n <- nrow(data)
  lim <- suppressWarnings(as.integer(value))
  if (is.na(lim) || lim < 0L || n == 0L) return(rep(FALSE, n))
  out <- rep(FALSE, n)
  for (col in names(data)) {
    v <- data[[col]]
    if (!is.character(v)) next
    # rtrim trailing spaces per P21 parity; count remaining bytes.
    vv <- sub("\\s+$", "", v)
    too_long <- !is.na(vv) & nchar(vv, type = "bytes") > lim
    out <- out | too_long
  }
  out
}
.register_op(
  "any_value_exceeds_length", op_any_value_exceeds_length,
  meta = list(
    kind = "existence",
    summary = "Per row: at least one character column has a value longer than the byte-length cap",
    arg_schema = list(value = list(type = "integer", required = TRUE)),
    cost_hint = "O(n*m)",
    column_arg = NA_character_,
    returns_na_ok = FALSE
  )
)

# --- var_by_suffix_not_numeric -----------------------------------------------
# Row-level: fires on every row when the named column (resolved via stem
# wildcard expansion) is not a numeric vector. Used for *DT/*TM/*DTM rules
# (ADaM-58/59/60/716) which require date-time displacement variables to be
# stored as numeric. `exclude_prefix` allows a specific stem to be skipped
# (ADaM-716: exclude ELTM whose stem is "EL").

op_var_by_suffix_not_numeric <- function(data, ctx, name,
                                         exclude_prefix = NULL) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  excl <- as.character(exclude_prefix %||% "")
  if (nzchar(excl) && startsWith(name, excl)) return(rep(FALSE, nrow(data)))
  rep(!is.numeric(col), nrow(data))
}
.register_op(
  "var_by_suffix_not_numeric", op_var_by_suffix_not_numeric,
  meta = list(
    kind = "existence",
    summary = "Column resolved by suffix wildcard is not a numeric variable",
    arg_schema = list(
      name           = list(type = "string", required = TRUE),
      exclude_prefix = list(type = "string", default = NULL)
    ),
    cost_hint     = "O(1)",
    column_arg    = "name",
    returns_na_ok = TRUE
  )
)

# --- no_var_with_suffix (plan Q24) -------------------------------------------
# ADSL must carry at least one flag variable (suffix `FL`). Usable beyond
# ADSL: any rule that asserts "a variable ending in <SUFFIX> must be
# present" can target this op. Metadata-level.

op_no_var_with_suffix <- function(data, ctx, suffix) {
  n <- nrow(data)
  s <- toupper(as.character(suffix %||% ""))
  if (!nzchar(s)) return(.dataset_level_mask(FALSE, n))
  any_present <- any(endsWith(toupper(names(data)), s))
  .dataset_level_mask(!any_present, n)
}
.register_op(
  "no_var_with_suffix", op_no_var_with_suffix,
  meta = list(
    kind = "existence",
    summary = "No column in the dataset has a name ending with the given suffix",
    arg_schema = list(suffix = list(type = "string", required = TRUE)),
    cost_hint = "O(n)",
    column_arg = NA_character_,
    returns_na_ok = FALSE
  )
)

# --- dataset_name_prefix_not (Q25) -------------------------------------------
# Metadata-level: fires once per dataset when the dataset name does NOT start
# with the given prefix AND the dataset class is non-missing (when_class_is_missing
# = FALSE), or when the name DOES start with the prefix AND the class IS missing
# (when_class_is_missing = TRUE).
#
# Used for ADaM-496 (name must start with "AD" when class non-missing) and
# ADaM-497 (name must NOT start with "AD" when class missing):
#   ADaM-496: prefix="AD", when_class_is_missing=FALSE
#   ADaM-497: prefix="AD", when_class_is_missing=TRUE
#
# Class is resolved via .ds_class() / infer_class(); NA or "" counts as missing.

op_dataset_name_prefix_not <- function(data, ctx,
                                       prefix,
                                       when_class_is_missing = FALSE) {
  n    <- nrow(data)
  pfx  <- as.character(prefix %||% "")
  mode_missing <- isTRUE(as.logical(when_class_is_missing))

  # Derive current dataset name and its class from ctx.
  ds_name <- as.character(ctx$current_dataset %||% "")

  # For "class is missing" detection, consult only the caller-supplied spec
  # (Define-XML) -- not the name-based heuristic. A dataset named "ADxxx"
  # always gets a non-missing heuristic class, which would prevent ADaM-497
  # from ever firing. CDISC conformance rules reference the class as declared
  # in the submission's Define-XML, not as inferred from the name.
  cls <- NA_character_
  if (nzchar(ds_name)) {
    spec_cls <- tryCatch({
      sp <- ctx$spec
      if (!is.null(sp) && !is.null(sp$ds_spec)) {
        ds_col  <- sp$ds_spec[["dataset"]] %||% sp$ds_spec[["Dataset"]]
        cls_col <- sp$ds_spec[["class"]]   %||% sp$ds_spec[["Class"]]
        if (!is.null(ds_col) && !is.null(cls_col)) {
          hit <- which(toupper(as.character(ds_col)) == toupper(ds_name))
          if (length(hit) > 0L) as.character(cls_col[hit[[1L]]]) else NA_character_
        } else NA_character_
      } else NA_character_
    }, error = function(e) NA_character_)
    cls <- spec_cls
  }
  class_missing <- is.null(cls) || is.na(cls) || !nzchar(trimws(cls))

  if (mode_missing) {
    # ADaM-497 shape: fires when name DOES start with prefix AND class IS missing.
    violated <- startsWith(toupper(ds_name), toupper(pfx)) && class_missing
  } else {
    # ADaM-496 shape: fires when name does NOT start with prefix AND class non-missing.
    violated <- !startsWith(toupper(ds_name), toupper(pfx)) && !class_missing
  }
  .dataset_level_mask(isTRUE(violated), n)
}
.register_op(
  "dataset_name_prefix_not", op_dataset_name_prefix_not,
  meta = list(
    kind    = "existence",
    summary = "Dataset name prefix vs class check (ADaM-496 / ADaM-497 pattern)",
    arg_schema = list(
      prefix              = list(type = "string",  required = TRUE),
      when_class_is_missing = list(type = "boolean", default  = FALSE)
    ),
    cost_hint     = "O(1)",
    column_arg    = NA_character_,
    returns_na_ok = FALSE
  )
)

# --- dataset_name_length_not_in_range (Q25) ----------------------------------
# Metadata-level: fires once per dataset when the dataset name's length does
# NOT fall within [min_len, max_len]. Omit min_len to skip lower-bound check;
# omit max_len to skip upper-bound check. Used for split-dataset and SUPPQUAL
# name-length constraints (CG0017, CG0018, CG0205).
#
# CG0017: min_len=3, max_len=4  (length > 2 and <= 4)
# CG0018: max_len=8             (length <= 8)
# CG0205: max_len=8             (SUPPQUAL dataset names <= 8)
#
# Name length is measured in Unicode characters (nchar type="chars"), matching
# the SDTM dataset-naming convention (all ASCII names in practice).

op_dataset_name_length_not_in_range <- function(data, ctx,
                                                 min_len = NULL,
                                                 max_len = NULL) {
  n       <- nrow(data)
  ds_name <- as.character(ctx$current_dataset %||% "")
  if (!nzchar(ds_name)) return(.dataset_level_mask(FALSE, n))

  len     <- nchar(ds_name, type = "chars")
  lo      <- if (!is.null(min_len)) suppressWarnings(as.integer(min_len)) else NA_integer_
  hi      <- if (!is.null(max_len)) suppressWarnings(as.integer(max_len)) else NA_integer_

  violated <- FALSE
  if (!is.na(lo) && len < lo) violated <- TRUE
  if (!is.na(hi) && len > hi) violated <- TRUE
  .dataset_level_mask(isTRUE(violated), n)
}
.register_op(
  "dataset_name_length_not_in_range", op_dataset_name_length_not_in_range,
  meta = list(
    kind    = "existence",
    summary = "Dataset name length is outside the required [min_len, max_len] range",
    arg_schema = list(
      min_len = list(type = "integer", default = NULL),
      max_len = list(type = "integer", default = NULL)
    ),
    cost_hint     = "O(1)",
    column_arg    = NA_character_,
    returns_na_ok = FALSE
  )
)

# --- any_var_name_not_matching_regex (Q25) ------------------------------------
# Metadata-level: fires once per dataset when at least one variable name does
# NOT match the given regex. Used for variable-naming structural rules
# (ADaM-14: name must start with letter; ADaM-15: name must contain only
# [A-Z0-9_]).
#
# regex is a POSIX/Perl-compatible regular expression that a VALID variable
# name should match (positive case). The op fires when any name fails to match.
#
# P21 parity: P21 models ADaM-14/15 via val:Regex Target=Metadata Variable=
# VARIABLE where the test regex is a positive pattern; the op inverts the logic
# (fires on non-match), matching CDISC's "error if the name does not conform".
#
# Column name comparison is uppercase (CDISC convention: variable names are
# always stored uppercase in XPT). The regex is applied UPPERCASE; callers
# should write the pattern for uppercase names.

op_any_var_name_not_matching_regex <- function(data, ctx, value) {
  n    <- nrow(data)
  cols <- names(data)
  if (length(cols) == 0L) return(.dataset_level_mask(FALSE, n))
  rx <- as.character(value %||% "")
  if (!nzchar(rx)) return(.dataset_level_mask(FALSE, n))
  violated <- any(
    !grepl(rx, toupper(cols), perl = TRUE),
    na.rm = TRUE
  )
  .dataset_level_mask(isTRUE(violated), n)
}
.register_op(
  "any_var_name_not_matching_regex", op_any_var_name_not_matching_regex,
  meta = list(
    kind    = "existence",
    summary = "Fires when any variable name does not match the required regex",
    arg_schema = list(value = list(type = "string", required = TRUE)),
    cost_hint     = "O(1)",
    column_arg    = NA_character_,
    returns_na_ok = FALSE
  )
)
