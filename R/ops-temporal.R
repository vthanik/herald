# -----------------------------------------------------------------------------
# ops-temporal.R — SDTM --DTC date / datetime operators
# -----------------------------------------------------------------------------
# Parsing utilities + operators for date completeness and comparisons.
# All operators accept ISO 8601 strings (with SDTM dash-substitution per
# SDTMIG s.4.1.4) and compare on the underlying datetime.

#' Parse an SDTM-style ISO 8601 string to POSIXct, or NA if unparseable
#'
#' Accepts full and truncated forms:
#'   "2024-01-15"            -> 2024-01-15 00:00:00 UTC
#'   "2024-01-15T14:30"      -> 2024-01-15 14:30:00 UTC
#'   "2024-01-15T14:30:00"   -> same
#'   "2024"                  -> 2024-01-01 00:00:00 UTC (year floor)
#'   "2024-01"               -> 2024-01-01 00:00:00 UTC (month floor)
#' Returns NA for anything with dashes inside the date part
#' ("2024---15", "--01-15") or time-only ("T14:30"), because those lack a
#' full, comparable timestamp.
#' @noRd
.parse_sdtm_dt <- function(x) {
  x <- as.character(x)
  n <- length(x)
  out <- rep(as.POSIXct(NA), n)

  # Quick pattern-triage: full YYYY-MM-DD[Thh:mm[:ss[.FFF]]]
  full_date_re <- "^(\\d{4})(?:-(\\d{2}))?(?:-(\\d{2}))?(?:T(\\d{2}):(\\d{2})(?::(\\d{2})(?:\\.\\d+)?)?)?(Z|[+-]\\d{2}:?\\d{2})?$"

  for (i in seq_len(n)) {
    s <- x[i]
    if (is.na(s) || !nzchar(s)) next
    if (grepl("-", substring(s, 5), fixed = FALSE)) {
      # Fast-fail: any dashes INSIDE the date portion (after year) need
      # deeper parsing; check structured form below.
    }
    m <- regmatches(s, regexec(full_date_re, s, perl = TRUE))[[1]]
    if (length(m) == 0L) next

    yr <- as.integer(m[2])
    mo <- if (nzchar(m[3])) as.integer(m[3]) else 1L
    dy <- if (nzchar(m[4])) as.integer(m[4]) else 1L
    hh <- if (nzchar(m[5])) as.integer(m[5]) else 0L
    mm <- if (nzchar(m[6])) as.integer(m[6]) else 0L
    ss <- if (nzchar(m[7])) as.integer(m[7]) else 0L

    if (is.na(yr) || is.na(mo) || is.na(dy)) next
    if (mo < 1 || mo > 12 || dy < 1 || dy > 31 ||
        hh < 0 || hh > 23 || mm < 0 || mm > 59 || ss < 0 || ss > 60) next

    # UTC throughout; ignore tz offset for now (comparison convention)
    iso <- sprintf("%04d-%02d-%02dT%02d:%02d:%02d", yr, mo, dy, hh, mm, ss)
    pt <- tryCatch(as.POSIXct(iso, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
                   error = function(e) NA)
    out[i] <- pt
  }
  out
}

#' Is the date portion fully specified (no dashes in YYYY-MM-DD)?
#' @noRd
.is_complete_sdtm_date <- function(x) {
  x <- as.character(x)
  # Must have YYYY-MM-DD in the prefix (possibly followed by Thh:mm...)
  # No internal dashes in the date portion.
  grepl("^\\d{4}-\\d{2}-\\d{2}(T.*)?$", x, perl = TRUE)
}

# --- operators ---------------------------------------------------------------

op_is_complete_date <- function(data, ctx, name) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  values <- as.character(col)
  missing <- is.na(values) | !nzchar(values)
  out <- logical(length(values))
  out[missing] <- NA
  out[!missing] <- .is_complete_sdtm_date(values[!missing])
  out
}
.register_op(
  "is_complete_date", op_is_complete_date,
  meta = list(
    kind = "temporal",
    summary = "SDTM --DTC date portion is YYYY-MM-DD (no dash-substitutions)",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_is_incomplete_date <- function(data, ctx, name) {
  m <- op_is_complete_date(data, ctx, name)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "is_incomplete_date", op_is_incomplete_date,
  meta = list(
    kind = "temporal",
    summary = "SDTM --DTC date portion is partial (dash-substituted or truncated)",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_invalid_date <- function(data, ctx, name) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  values <- as.character(col)
  missing <- is.na(values) | !nzchar(values)
  ok_iso   <- .valid_iso8601_sdtm(values[!missing])
  out <- logical(length(values))
  out[missing]  <- NA
  out[!missing] <- !ok_iso
  out
}
.register_op(
  "invalid_date", op_invalid_date,
  meta = list(
    kind = "temporal",
    summary = "Date value is not valid SDTM ISO 8601 format",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_invalid_duration <- function(data, ctx, name) {
  col <- data[[name]]
  if (is.null(col)) return(rep(NA, nrow(data)))
  values <- as.character(col)
  missing <- is.na(values) | !nzchar(values)
  # ISO 8601 duration: Pn[Y]n[M]n[D]T[n[H]n[M]n[S]]  e.g. P2Y3M4DT6H
  dur_re <- "^P(?:\\d+Y)?(?:\\d+M)?(?:\\d+D)?(?:T(?:\\d+H)?(?:\\d+M)?(?:\\d+(?:\\.\\d+)?S)?)?$"
  valid <- grepl(dur_re, values[!missing], perl = TRUE) & values[!missing] != "P"
  out <- logical(length(values))
  out[missing] <- NA
  out[!missing] <- !valid
  out
}
.register_op(
  "invalid_duration", op_invalid_duration,
  meta = list(
    kind = "temporal",
    summary = "Duration value is not valid ISO 8601 duration",
    arg_schema = list(name = list(type = "string", required = TRUE)),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

# --- op_value_not_iso8601 (unified date / duration format check) -----------
# Dispatches to op_invalid_date or op_invalid_duration based on `kind`.
# kind = "date"     -> fires TRUE when value is NOT a valid SDTM ISO 8601 date
#                      (same as op_invalid_date -- dash-substitution accepted)
# kind = "duration" -> fires TRUE when value is NOT a valid ISO 8601 duration
# NA and empty values are advisory (return NA).

op_value_not_iso8601 <- function(data, ctx, name,
                                 kind = c("date", "duration")) {
  kind <- match.arg(kind)
  if (kind == "date") {
    op_invalid_date(data, ctx, name)
  } else {
    op_invalid_duration(data, ctx, name)
  }
}
.register_op(
  "value_not_iso8601", op_value_not_iso8601,
  meta = list(
    kind          = "temporal",
    summary       = "Value does not conform to ISO 8601 date or duration format",
    arg_schema    = list(
      name = list(type = "string",  required = TRUE),
      kind = list(type = "string",  required = FALSE, default = "date",
                  enum = c("date", "duration"))
    ),
    cost_hint     = "O(n)",
    column_arg    = "name",
    returns_na_ok = TRUE,
    examples      = list(
      list(name = "TSVAL",   kind = "date"),
      list(name = "TDSTOFF", kind = "duration")
    )
  )
)

# --- ordinal date comparisons ----------------------------------------------

.date_cmp <- function(col, value, op, data) {
  if (is.null(col)) return(rep(NA, nrow(data)))
  lhs <- .parse_sdtm_dt(col)
  # value is either a literal date string or another column name (if
  # value_is_literal == FALSE). For now treat as literal if it looks like
  # one; else look up as a column.
  v_char <- as.character(value)
  if (length(v_char) == 1L && v_char %in% names(data)) {
    rhs <- .parse_sdtm_dt(data[[v_char]])
  } else {
    # Multi-element `value` from a resolved cross-ref (e.g. `$max_*`,
    # `DOM.COL`) implies a join-by-key the op can't express. Return NA.
    if (length(v_char) > 1L) return(rep(NA, nrow(data)))
    rhs <- .parse_sdtm_dt(v_char)
    if (length(rhs) == 1L) rhs <- rep(rhs, length(lhs))
  }
  # Comparison; both-NA rows -> NA
  out <- op(lhs, rhs)
  out[is.na(lhs) | is.na(rhs)] <- NA
  out
}

op_date_greater_than <- function(data, ctx, name, value) {
  .date_cmp(data[[name]], value, `>`, data)
}
.register_op(
  "date_greater_than", op_date_greater_than,
  meta = list(
    kind = "temporal",
    summary = "Date column > literal / other date column",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "any", required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_date_less_than <- function(data, ctx, name, value) {
  .date_cmp(data[[name]], value, `<`, data)
}
.register_op(
  "date_less_than", op_date_less_than,
  meta = list(
    kind = "temporal", summary = "Date column < literal / other date column",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "any", required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_date_equal_to <- function(data, ctx, name, value) {
  .date_cmp(data[[name]], value, `==`, data)
}
.register_op(
  "date_equal_to", op_date_equal_to,
  meta = list(
    kind = "temporal", summary = "Date column == literal / other date column",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "any", required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_date_not_equal_to <- function(data, ctx, name, value) {
  m <- .date_cmp(data[[name]], value, `==`, data)
  ifelse(is.na(m), NA, !m)
}
.register_op(
  "date_not_equal_to", op_date_not_equal_to,
  meta = list(
    kind = "temporal", summary = "Date column != literal / other date column",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "any", required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_date_greater_than_or_equal_to <- function(data, ctx, name, value) {
  .date_cmp(data[[name]], value, `>=`, data)
}
.register_op(
  "date_greater_than_or_equal_to", op_date_greater_than_or_equal_to,
  meta = list(
    kind = "temporal", summary = "Date column >= literal / other date column",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "any", required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)

op_date_less_than_or_equal_to <- function(data, ctx, name, value) {
  .date_cmp(data[[name]], value, `<=`, data)
}
.register_op(
  "date_less_than_or_equal_to", op_date_less_than_or_equal_to,
  meta = list(
    kind = "temporal", summary = "Date column <= literal / other date column",
    arg_schema = list(
      name = list(type = "string", required = TRUE),
      value = list(type = "any", required = TRUE)
    ),
    cost_hint = "O(n)", column_arg = "name", returns_na_ok = TRUE
  )
)
