# -----------------------------------------------------------------------------
# ops-string.R — string-shape operators
# -----------------------------------------------------------------------------

# --- iso8601 (SDTM --DTC format) ---------------------------------------------

#' Validate SDTM ISO 8601 extended format with dash-substitution
#'
#' Per SDTMIG s.4.1.4, *DTC variables use ISO 8601 extended format:
#'
#'   `YYYY[-MM[-DD[Thh[:mm[:ss[.FFF]]][Z|+-hh:mm]]]]`
#'
#' with dash-substitution for missing middle components (e.g. `2026---01`
#' means year 2026, missing month, day 01). Trailing components can be
#' truncated. The leading date portion can be absent (time-only: `T14:30`).
#'
#' @noRd
.valid_iso8601_sdtm <- function(x) {
  x <- as.character(x)
  # Year: 4 digits or 1-4 dashes.
  # Month/day/hour/min/sec: 2 digits or 1-2 dashes.
  # Date-component separator is OPTIONAL so spec shorthand "--12-15"
  # (dashed year with no year-month separator) is accepted.
  # Time separators (:) are required in the strict form, but the minute/sec
  # slots themselves can be dashed ("T13:-:17" = unknown minute).
  date_re <- paste0(
    "(\\d{4}|-{1,4})",                 # year
    "(-?(\\d{2}|-{1,2})",              # optional sep + month
      "(-?(\\d{2}|-{1,2}))?",          # optional sep + day
    ")?"
  )
  time_re <- paste0(
    "(\\d{2}|-{1,2})",                 # hour
    "(:(\\d{2}|-{1,2})",               # :minute
      "(:(\\d{2}|-{1,2})",             # :second
        "(\\.\\d+)?",                  # .fraction
      ")?",
    ")?",
    "(Z|[+-]\\d{2}:?\\d{2})?"          # timezone
  )
  pat <- paste0("^(", date_re, ")?(T", time_re, ")?$")

  ok <- grepl(pat, x, perl = TRUE)
  # Reject empty, bare "T", and all-dashes-no-digits strings
  has_digit <- grepl("[0-9]", x)
  ok & nzchar(x) & x != "T" & has_digit
}

#' Operator: iso8601
#'
#' Check that a column's values are valid SDTM ISO 8601 format.
#' By default, NA and empty values are considered compliant (use
#' the `non_empty` operator separately if population is required).
#'
#' @noRd
op_iso8601 <- function(data, ctx, name, allow_missing = TRUE) {
  values <- data[[name]]
  if (is.null(values)) {
    return(rep(NA, nrow(data)))
  }
  values <- as.character(values)
  missing <- is.na(values) | !nzchar(values)
  pass <- logical(length(values))
  pass[missing] <- allow_missing
  pass[!missing] <- .valid_iso8601_sdtm(values[!missing])
  pass
}

.register_op(
  "iso8601", op_iso8601,
  meta = list(
    kind       = "string",
    summary    = "SDTM ISO 8601 extended format with dash-substitution for missing components",
    arg_schema = list(
      name          = list(type = "string",  required = TRUE),
      allow_missing = list(type = "logical", required = FALSE, default = TRUE)
    ),
    cost_hint     = "O(n)",
    column_arg    = "name",
    returns_na_ok = TRUE,
    examples = list(
      list(name = "AESTDTC"),
      list(name = "VSDTC", allow_missing = FALSE)
    )
  )
)

# --- matches_regex -----------------------------------------------------------

#' Operator: matches_regex
#'
#' Check that column values match a PCRE pattern. NA / empty are
#' considered compliant unless allow_missing = FALSE.
#'
#' @noRd
#' Anchor a user-supplied regex so the match is against the ENTIRE value,
#' not a substring. Mirrors Pinnacle 21's
#' `RegularExpressionValidationRule.java:71`, which uses `matcher.matches()`
#' (full-string match) rather than `find()` (substring). A pattern that is
#' already anchored (starts with `^`, ends with `$`) is left untouched so
#' explicit intent is preserved.
.anchor_regex <- function(pat) {
  pat <- as.character(pat)
  if (!nzchar(pat)) return(pat)
  if (!startsWith(pat, "^"))   pat <- paste0("^(?:", pat, ")")
  if (!endsWith(pat,   "$"))   pat <- paste0(pat, "$")
  pat
}

op_matches_regex <- function(data, ctx, name, value, allow_missing = TRUE) {
  values <- data[[name]]
  if (is.null(values)) return(rep(NA, nrow(data)))
  values <- as.character(values)
  missing <- is.na(values) | !nzchar(values)
  pass <- logical(length(values))
  pass[missing] <- allow_missing
  pass[!missing] <- grepl(.anchor_regex(value), values[!missing], perl = TRUE)
  pass
}

.register_op(
  "matches_regex", op_matches_regex,
  meta = list(
    kind       = "string",
    summary    = "PCRE regex match on column values",
    arg_schema = list(
      name          = list(type = "string",  required = TRUE),
      value         = list(type = "string",  required = TRUE),
      allow_missing = list(type = "logical", required = FALSE, default = TRUE)
    ),
    cost_hint     = "O(n)",
    column_arg    = "name",
    returns_na_ok = TRUE,
    examples = list(
      list(name = "USUBJID", value = "^[A-Z0-9-]+$")
    )
  )
)

# --- length_le ---------------------------------------------------------------

#' Operator: length_le
#'
#' Check that character length (in bytes) is <= value. NA/empty pass.
#'
#' @noRd
op_length_le <- function(data, ctx, name, value) {
  values <- data[[name]]
  if (is.null(values)) return(rep(NA, nrow(data)))
  values <- as.character(values)
  missing <- is.na(values)
  pass <- logical(length(values))
  pass[missing] <- TRUE
  pass[!missing] <- nchar(values[!missing], type = "bytes") <= as.integer(value)
  pass
}

.register_op(
  "length_le", op_length_le,
  meta = list(
    kind       = "string",
    summary    = "Character byte-length <= max (matches SAS column width semantics)",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      value = list(type = "integer", required = TRUE)
    ),
    cost_hint     = "O(n)",
    column_arg    = "name",
    returns_na_ok = TRUE,
    examples = list(
      list(name = "AETERM", value = 200L)
    )
  )
)

# --- contains ----------------------------------------------------------------

#' Operator: contains
#'
#' Substring containment. Case-sensitive by default.
#'
#' @noRd
op_contains <- function(data, ctx, name, value, ignore_case = FALSE) {
  values <- data[[name]]
  if (is.null(values)) return(rep(NA, nrow(data)))
  values <- as.character(values)
  missing <- is.na(values)
  pass <- logical(length(values))
  pass[missing] <- FALSE
  if (ignore_case) {
    pass[!missing] <- grepl(tolower(value), tolower(values[!missing]),
                            fixed = TRUE)
  } else {
    pass[!missing] <- grepl(value, values[!missing], fixed = TRUE)
  }
  pass
}

.register_op(
  "contains", op_contains,
  meta = list(
    kind       = "string",
    summary    = "Fixed substring containment on column values",
    arg_schema = list(
      name        = list(type = "string",  required = TRUE),
      value       = list(type = "string",  required = TRUE),
      ignore_case = list(type = "logical", required = FALSE, default = FALSE)
    ),
    cost_hint     = "O(n)",
    column_arg    = "name",
    returns_na_ok = FALSE,
    examples = list(
      list(name = "AETERM", value = "HEADACHE")
    )
  )
)

# --- not_matches_regex -------------------------------------------------------

op_not_matches_regex <- function(data, ctx, name, value, allow_missing = TRUE) {
  m <- op_matches_regex(data, ctx, name, value, allow_missing)
  # Preserve NA; invert otherwise
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "not_matches_regex", op_not_matches_regex,
  meta = list(
    kind = "string",
    summary = "Column value does not match regex pattern",
    arg_schema = list(
      name  = list(type = "string", required = TRUE),
      value = list(type = "string", required = TRUE),
      allow_missing = list(type = "logical", default = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- does_not_contain --------------------------------------------------------

op_does_not_contain <- function(data, ctx, name, value, ignore_case = FALSE) {
  m <- op_contains(data, ctx, name, value, ignore_case)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "does_not_contain", op_does_not_contain,
  meta = list(
    kind = "string",
    summary = "Column value does NOT contain substring",
    arg_schema = list(
      name        = list(type = "string", required = TRUE),
      value       = list(type = "string", required = TRUE),
      ignore_case = list(type = "logical", default = FALSE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = FALSE
  )
)

# --- length comparators ------------------------------------------------------

op_longer_than <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  values <- as.character(col)
  missing <- is.na(values)
  out <- logical(length(values))
  out[missing] <- NA
  out[!missing] <- nchar(values[!missing], type = "bytes") > as.integer(value)
  out
}
.register_op(
  "longer_than", op_longer_than,
  meta = list(
    kind = "string",
    summary = "Column character length (bytes) is greater than value",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      value = list(type = "integer", required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_shorter_than <- function(data, ctx, name, value) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  values <- as.character(col)
  missing <- is.na(values)
  out <- logical(length(values))
  out[missing] <- NA
  out[!missing] <- nchar(values[!missing], type = "bytes") < as.integer(value)
  out
}
.register_op(
  "shorter_than", op_shorter_than,
  meta = list(
    kind = "string",
    summary = "Column character length (bytes) is less than value",
    arg_schema = list(
      name  = list(type = "string",  required = TRUE),
      value = list(type = "integer", required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- starts_with / ends_with ------------------------------------------------

op_starts_with <- function(data, ctx, name, value, ignore_case = FALSE) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  values <- as.character(col)
  missing <- is.na(values)
  out <- logical(length(values))
  out[missing] <- NA
  if (ignore_case) {
    out[!missing] <- startsWith(tolower(values[!missing]), tolower(value))
  } else {
    out[!missing] <- startsWith(values[!missing], value)
  }
  out
}
.register_op(
  "starts_with", op_starts_with,
  meta = list(
    kind = "string",
    summary = "Column value starts with prefix",
    arg_schema = list(
      name        = list(type = "string", required = TRUE),
      value       = list(type = "string", required = TRUE),
      ignore_case = list(type = "logical", default = FALSE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_ends_with <- function(data, ctx, name, value, ignore_case = FALSE) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  values <- as.character(col)
  missing <- is.na(values)
  out <- logical(length(values))
  out[missing] <- NA
  if (ignore_case) {
    out[!missing] <- endsWith(tolower(values[!missing]), tolower(value))
  } else {
    out[!missing] <- endsWith(values[!missing], value)
  }
  out
}
.register_op(
  "ends_with", op_ends_with,
  meta = list(
    kind = "string",
    summary = "Column value ends with suffix",
    arg_schema = list(
      name        = list(type = "string", required = TRUE),
      value       = list(type = "string", required = TRUE),
      ignore_case = list(type = "logical", default = FALSE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- prefix operators (first N chars of column value) -----------------------
# CDISC convention: prefix length = 2 chars (the domain 2-char prefix).
# Allow override via `prefix_length` arg if rule specifies.

.prefix <- function(s, len = 2L) substr(as.character(s), 1L, len)

op_prefix_equal_to <- function(data, ctx, name, value, prefix_length = 2L) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  values <- as.character(col)
  missing <- is.na(values)
  out <- logical(length(values))
  out[missing]  <- NA
  out[!missing] <- .prefix(values[!missing], prefix_length) == as.character(value)
  out
}
.register_op(
  "prefix_equal_to", op_prefix_equal_to,
  meta = list(
    kind = "string",
    summary = "First `prefix_length` chars of value equal a literal",
    arg_schema = list(
      name          = list(type = "string",  required = TRUE),
      value         = list(type = "string",  required = TRUE),
      prefix_length = list(type = "integer", default = 2L)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_prefix_not_equal_to <- function(data, ctx, name, value, prefix_length = 2L) {
  m <- op_prefix_equal_to(data, ctx, name, value, prefix_length)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "prefix_not_equal_to", op_prefix_not_equal_to,
  meta = list(
    kind = "string",
    summary = "First N chars of value do not equal a literal",
    arg_schema = list(
      name          = list(type = "string",  required = TRUE),
      value         = list(type = "string",  required = TRUE),
      prefix_length = list(type = "integer", default = 2L)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_prefix_matches_regex <- function(data, ctx, name, value, prefix_length = 2L) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  values <- as.character(col)
  missing <- is.na(values)
  out <- logical(length(values))
  out[missing]  <- NA
  out[!missing] <- grepl(.anchor_regex(value),
                         .prefix(values[!missing], prefix_length),
                         perl = TRUE)
  out
}
.register_op(
  "prefix_matches_regex", op_prefix_matches_regex,
  meta = list(
    kind = "string",
    summary = "First N chars of value match PCRE pattern",
    arg_schema = list(
      name          = list(type = "string",  required = TRUE),
      value         = list(type = "string",  required = TRUE),
      prefix_length = list(type = "integer", default = 2L)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_not_prefix_matches_regex <- function(data, ctx, name, value, prefix_length = 2L) {
  m <- op_prefix_matches_regex(data, ctx, name, value, prefix_length)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "not_prefix_matches_regex", op_not_prefix_matches_regex,
  meta = list(
    kind = "string",
    summary = "First N chars of value do not match PCRE pattern",
    arg_schema = list(
      name          = list(type = "string",  required = TRUE),
      value         = list(type = "string",  required = TRUE),
      prefix_length = list(type = "integer", default = 2L)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)
