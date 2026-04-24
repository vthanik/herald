# ops-inconsistent-enumerated-columns.R -- inconsistent_enumerated_columns
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
