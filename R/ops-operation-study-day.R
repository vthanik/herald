# ops-operation-study-day.R -- study_day_from_dates operation (dy)
# Computes the per-row CDISC study day: --DY = (date - RFSTDTC) + 1 for dates
# on/after RFSTDTC; (date - RFSTDTC) for dates before RFSTDTC (no day 0).
# Unlocks: CG0006 (--DY must equal this formula).
#
# params$name: the date column to compute from (e.g. AESTDTC).
# Requires DM.RFSTDTC in ctx$datasets[["DM"]].
# Returns a vector of computed --DY values (integer or NA) of length nrow(data).

.op_operation_study_day <- function(data, ctx, params) {
  col <- as.character(params[["name"]] %||% "")
  if (!nzchar(col)) return(rep(NA_integer_, nrow(data)))

  idx <- which(toupper(names(data)) == toupper(col))
  if (length(idx) == 0L) return(rep(NA_integer_, nrow(data)))

  # Get RFSTDTC from DM via USUBJID join
  dm <- ctx$datasets[["DM"]] %||% ctx$datasets[["dm"]]
  if (is.null(dm)) return(rep(NA_integer_, nrow(data)))
  rfstdtc_col <- which(toupper(names(dm)) == "RFSTDTC")
  usubjid_dm  <- which(toupper(names(dm)) == "USUBJID")
  if (length(rfstdtc_col) == 0L || length(usubjid_dm) == 0L) {
    return(rep(NA_integer_, nrow(data)))
  }

  rf_map <- stats::setNames(
    as.character(dm[[rfstdtc_col[[1L]]]]),
    as.character(dm[[usubjid_dm[[1L]]]])
  )

  usubjid_data <- which(toupper(names(data)) == "USUBJID")
  subj <- if (length(usubjid_data) > 0L) as.character(data[[usubjid_data[[1L]]]]) else rep(NA_character_, nrow(data))

  .sdtm_study_day <- function(dt_str, ref_str) {
    if (is.na(dt_str) || is.na(ref_str) || !nzchar(dt_str) || !nzchar(ref_str)) return(NA_integer_)
    # Truncate to 10 chars (date part of ISO-8601)
    dt  <- tryCatch(as.Date(substr(dt_str,  1L, 10L)), error = function(e) NA)
    ref <- tryCatch(as.Date(substr(ref_str, 1L, 10L)), error = function(e) NA)
    if (is.na(dt) || is.na(ref)) return(NA_integer_)
    diff <- as.integer(dt - ref)
    if (diff >= 0L) diff + 1L else diff
  }

  mapply(function(dt, subj_id) {
    rf <- rf_map[[subj_id]]
    .sdtm_study_day(dt, rf)
  },
  as.character(data[[idx[[1L]]]]),
  subj,
  USE.NAMES = FALSE)
}

.register_operation(
  "dy",
  .op_operation_study_day,
  meta = list(
    kind      = "temporal",
    summary   = "Per-row CDISC study day (--DY formula) relative to DM.RFSTDTC.",
    returns   = "vector",
    cost_hint = "O(n)"
  )
)
