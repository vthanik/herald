# ops-operation-distinct.R -- distinct operation
# Returns unique non-NA values of the named column from the target dataset.
# Unlocks: CG0656, CG0225, CG0545, CG0147, CG0148, CG0349, CG0350, CG0336,
#          CG0540, CG0214, CG0531, CG0412, CG0370, CG0109.
#
# params$name identifies the source column. When params$group is supplied the
# result is a vector of distinct values within the current row's group (not
# yet needed by any ported rule, but wired for completeness).

.op_operation_distinct <- function(data, ctx, params) {
  col <- as.character(params[["name"]] %||% "")
  if (!nzchar(col)) return(character(0))

  # Case-insensitive column match
  idx <- which(toupper(names(data)) == toupper(col))
  if (length(idx) == 0L) return(character(0))

  vals <- as.character(data[[idx[[1L]]]])
  vals <- vals[!is.na(vals) & nzchar(vals)]
  unique(vals)
}

.register_operation(
  "distinct",
  .op_operation_distinct,
  meta = list(
    kind      = "cross",
    summary   = "Unique non-NA values of a column from the target dataset.",
    returns   = "array",
    cost_hint = "O(n)"
  )
)
