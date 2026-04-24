# ops-operation-study-domains.R -- study_domains + dataset_names operations
# Returns the uppercase names of all datasets present in the current study.
# Unlocks: CG0369 (RDOMAIN must reference an existing study dataset),
#          CG0332, CG0333 (split-domain parent must exist).

.op_operation_study_domains <- function(data, ctx, params) {
  if (!is.null(ctx$datasets)) toupper(names(ctx$datasets)) else character(0)
}

.register_operation(
  "study_domains",
  .op_operation_study_domains,
  meta = list(
    kind      = "cross",
    summary   = "Uppercase dataset names in the current validate() call.",
    returns   = "array",
    cost_hint = "O(1)"
  )
)

# dataset_names is an alias
.register_operation(
  "dataset_names",
  .op_operation_study_domains,
  meta = list(
    kind      = "cross",
    summary   = "Alias for study_domains: uppercase dataset names.",
    returns   = "array",
    cost_hint = "O(1)"
  )
)
