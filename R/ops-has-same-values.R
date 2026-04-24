# ops-has-same-values.R -- has_same_values
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
