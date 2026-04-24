# -----------------------------------------------------------------------------
# herald-operations.R -- Operations pre-compute registry
# -----------------------------------------------------------------------------
# CDISC CORE rules carry an `Operations:` block that materialises derived
# values (aggregates, lookups, cross-dataset scalars) BEFORE the Check: tree
# runs. Each entry stamps its result as a `$id`-named column on the evaluation
# frame so Check leaves can reference it with `name: $id` or `value: "$id"`.
#
# This mirrors the OperationsFactory pattern in the official CDISC rules engine
# (cdisc-rules-engine/operations/operations_factory.py:89-142):
#   YAML operator key -> registered R function
#   result broadcast onto the frame under the `$id` column name
#
# Operation function contract:
#   op_op_<name>(data, ctx, params) -> scalar | vector(nrow(data)) | list
#     data:   the target data frame (already scoped to the right dataset).
#     ctx:    herald_ctx (may be NULL in unit tests).
#     params: the full Operations entry list (id, operator, name, domain, group, ...).
#   Return value handling (mirrors base_operation._handle_operation_result):
#     scalar (length 1)  -> broadcast to all nrow(data) rows as a column.
#     vector length == nrow(data) -> assign row-by-row as a column.
#     any other length   -> store as a list-column (each row gets the same value).
#   Returning NULL signals failure; the $id column is left out (leaf -> NA advisory).

.OP_TABLE_OPS  <- new.env(parent = emptyenv())   # name -> function
.OP_META_OPS   <- new.env(parent = emptyenv())   # name -> metadata list

.DEFAULT_META_OPS <- list(
  name         = NA_character_,
  kind         = NA_character_,
  summary      = "",
  returns      = "scalar",    # "scalar" | "vector" | "array"
  cost_hint    = "O(n)",
  registered_in = NA_character_
)

#' Register an Operations pre-compute function
#' @noRd
.register_operation <- function(name, fn, meta = list()) {
  stopifnot(is.character(name), length(name) == 1L, nzchar(name))
  stopifnot(is.function(fn))

  if (exists(name, envir = .OP_TABLE_OPS, inherits = FALSE)) {
    cli::cli_warn("Operation {.val {name}} is being re-registered.")
  }

  merged <- utils::modifyList(.DEFAULT_META_OPS, meta)
  merged$name <- name
  if (is.na(merged$registered_in)) {
    merged$registered_in <- .caller_source_file()
  }

  assign(name, fn, envir = .OP_TABLE_OPS)
  assign(name, merged, envir = .OP_META_OPS)
  invisible(NULL)
}

#' Look up a registered Operations function; returns NULL if not found.
#' @noRd
.get_operation <- function(name) {
  if (!exists(name, envir = .OP_TABLE_OPS, inherits = FALSE)) return(NULL)
  get(name, envir = .OP_TABLE_OPS)
}

#' Names of all registered Operations (sorted)
#' @noRd
.list_operations <- function() sort(ls(.OP_TABLE_OPS))
