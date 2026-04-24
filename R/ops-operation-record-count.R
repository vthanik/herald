# ops-operation-record-count.R -- record_count operation
# Returns the number of rows in the target dataset as a scalar integer.
# Unlocks: CG0272, CG0408, CG0281, CG0531, CG0562.

.op_operation_record_count <- function(data, ctx, params) {
  nrow(data)
}

.register_operation(
  "record_count",
  .op_operation_record_count,
  meta = list(
    kind      = "cross",
    summary   = "Number of rows in the target dataset.",
    returns   = "scalar",
    cost_hint = "O(1)"
  )
)
