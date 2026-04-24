# ops-operation-max-min-date.R -- max_date / min_date operations
# Returns the lexicographic max or min of ISO-8601 date strings in the named
# column of the target dataset. NA when the column is missing or all NA.
# Unlocks: CG0147/CG0148 (RFXENDTC/RFXSTDTC vs max/min EX date),
#          CG0172 (SSDTC < max DS.DSSTDTC), CG0143 (RFICDTC = min DSSTDTC).

.op_operation_max_date <- function(data, ctx, params) {
  col <- as.character(params[["name"]] %||% "")
  if (!nzchar(col)) return(NA_character_)
  idx <- which(toupper(names(data)) == toupper(col))
  if (length(idx) == 0L) return(NA_character_)
  vals <- as.character(data[[idx[[1L]]]])
  vals <- vals[!is.na(vals) & nzchar(vals)]
  if (length(vals) == 0L) return(NA_character_)
  max(vals)
}

.op_operation_min_date <- function(data, ctx, params) {
  col <- as.character(params[["name"]] %||% "")
  if (!nzchar(col)) return(NA_character_)
  idx <- which(toupper(names(data)) == toupper(col))
  if (length(idx) == 0L) return(NA_character_)
  vals <- as.character(data[[idx[[1L]]]])
  vals <- vals[!is.na(vals) & nzchar(vals)]
  if (length(vals) == 0L) return(NA_character_)
  min(vals)
}

.register_operation(
  "max_date",
  .op_operation_max_date,
  meta = list(
    kind      = "temporal",
    summary   = "Lexicographic max of ISO-8601 date strings in a column.",
    returns   = "scalar",
    cost_hint = "O(n)"
  )
)

.register_operation(
  "min_date",
  .op_operation_min_date,
  meta = list(
    kind      = "temporal",
    summary   = "Lexicographic min of ISO-8601 date strings in a column.",
    returns   = "scalar",
    cost_hint = "O(n)"
  )
)
