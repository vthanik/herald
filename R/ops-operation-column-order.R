# ops-operation-column-order.R -- column-order family of operations
# Returns variable lists used by column-ordering and variable-presence rules.
#
# Fully implemented (no library metadata needed):
#   get_column_order_from_dataset  - names of variables in current dataset.
#   expected_variables             - same (variables present in dataset).
#   required_variables             - from spec, or character(0) if no spec.
#   get_dataset_filtered_variables - names of variables in dataset.
#
# Requires CDISC SDTM model metadata (returns character(0) / advisory pending
# SDTM library integration):
#   get_model_column_order
#   get_parent_model_column_order
#   get_column_order_from_library
#   get_model_filtered_variables

.op_operation_col_order_dataset <- function(data, ctx, params) {
  names(data)
}

.op_operation_expected_variables <- function(data, ctx, params) {
  names(data)
}

.op_operation_required_variables <- function(data, ctx, params) {
  # Use spec when available; fall back to empty (advisory).
  spec <- ctx$spec
  if (is.null(spec)) return(character(0))
  ds <- ctx$current_dataset %||% ""
  .spec_cols(spec, ds, c("required", "Required"))
}

.op_operation_dataset_filtered_variables <- function(data, ctx, params) {
  names(data)
}

# Model/library ops: return empty pending CDISC SDTM model integration.
# Rules relying on these will return NA (advisory) rather than false-pass.
.op_operation_model_col_order <- function(data, ctx, params) character(0)
.op_operation_parent_model_col_order <- function(data, ctx, params) character(0)
.op_operation_library_col_order <- function(data, ctx, params) character(0)
.op_operation_model_filtered_variables <- function(data, ctx, params) character(0)

.register_operation("get_column_order_from_dataset", .op_operation_col_order_dataset,
  meta = list(kind = "cross", summary = "Variable names in current dataset.",
              returns = "array", cost_hint = "O(1)"))

.register_operation("expected_variables", .op_operation_expected_variables,
  meta = list(kind = "cross", summary = "Variable names present in dataset.",
              returns = "array", cost_hint = "O(1)"))

.register_operation("required_variables", .op_operation_required_variables,
  meta = list(kind = "cross", summary = "Required variables from spec.",
              returns = "array", cost_hint = "O(1)"))

.register_operation("get_dataset_filtered_variables",
  .op_operation_dataset_filtered_variables,
  meta = list(kind = "cross", summary = "Filtered variable names in dataset.",
              returns = "array", cost_hint = "O(1)"))

.register_operation("get_model_column_order", .op_operation_model_col_order,
  meta = list(kind = "cross",
              summary = "SDTM model variable order (pending library integration).",
              returns = "array", cost_hint = "O(1)"))

.register_operation("get_parent_model_column_order",
  .op_operation_parent_model_col_order,
  meta = list(kind = "cross",
              summary = "Parent SDTM model variable order (pending library integration).",
              returns = "array", cost_hint = "O(1)"))

.register_operation("get_column_order_from_library", .op_operation_library_col_order,
  meta = list(kind = "cross",
              summary = "CDISC library variable order (pending library integration).",
              returns = "array", cost_hint = "O(1)"))

.register_operation("get_model_filtered_variables",
  .op_operation_model_filtered_variables,
  meta = list(kind = "cross",
              summary = "Model-filtered variable list (pending library integration).",
              returns = "array", cost_hint = "O(1)"))
