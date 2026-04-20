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

.register_op("iso8601", op_iso8601)

# --- matches_regex -----------------------------------------------------------

#' Operator: matches_regex
#'
#' Check that column values match a PCRE pattern. NA / empty are
#' considered compliant unless allow_missing = FALSE.
#'
#' @noRd
op_matches_regex <- function(data, ctx, name, value, allow_missing = TRUE) {
  values <- data[[name]]
  if (is.null(values)) return(rep(NA, nrow(data)))
  values <- as.character(values)
  missing <- is.na(values) | !nzchar(values)
  pass <- logical(length(values))
  pass[missing] <- allow_missing
  pass[!missing] <- grepl(value, values[!missing], perl = TRUE)
  pass
}

.register_op("matches_regex", op_matches_regex)

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

.register_op("length_le", op_length_le)

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

.register_op("contains", op_contains)
