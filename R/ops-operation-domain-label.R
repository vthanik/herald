# ops-operation-domain-label.R -- domain_label operation
# Returns the dataset label attribute as a scalar character.
# Unlocks: CG0336 (--CAT = domain label), CG0350 (--SCAT = domain label).

.op_operation_domain_label <- function(data, ctx, params) {
  # Prefer ctx$current_dataset label; fall back to the attr on data itself.
  ds_name <- ctx$current_dataset %||% ""
  if (nzchar(ds_name) && !is.null(ctx$datasets)) {
    lbl <- attr(ctx$datasets[[ds_name]], "label")
    if (!is.null(lbl) && nzchar(as.character(lbl))) return(as.character(lbl))
  }
  lbl <- attr(data, "label")
  if (!is.null(lbl) && nzchar(as.character(lbl))) return(as.character(lbl))
  NA_character_
}

.register_operation(
  "domain_label",
  .op_operation_domain_label,
  meta = list(
    kind      = "cross",
    summary   = "Dataset label attribute as a scalar string.",
    returns   = "scalar",
    cost_hint = "O(1)"
  )
)
