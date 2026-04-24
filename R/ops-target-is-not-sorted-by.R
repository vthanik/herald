# ops-target-is-not-sorted-by.R -- target_is_not_sorted_by
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
