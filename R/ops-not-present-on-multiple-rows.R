# ops-not-present-on-multiple-rows.R -- not_present_on_multiple_rows_within
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
