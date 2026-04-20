# -----------------------------------------------------------------------------
# herald-ops.R — operator registry
# -----------------------------------------------------------------------------
# Every operator in R/ops-*.R registers itself here via .register_op() at
# package load. rules-dispatch.R looks up operators from this table when
# walking a rule's check_tree.
#
# An operator is a function:
#   op(data, ctx, ...) -> logical vector of length nrow(data),
#                          TRUE  = record passes the check (rule satisfied)
#                          FALSE = record fails the check (finding emitted)
#                          NA    = indeterminate (skipped, reported as warn)
#
# The `...` carries operator-specific args from the check_tree node.

.OP_TABLE <- new.env(parent = emptyenv())

.register_op <- function(name, fn) {
  stopifnot(is.character(name), length(name) == 1L, nzchar(name))
  stopifnot(is.function(fn))
  if (exists(name, envir = .OP_TABLE, inherits = FALSE)) {
    cli::cli_warn("Operator {.val {name}} is being re-registered.")
  }
  assign(name, fn, envir = .OP_TABLE)
  invisible(NULL)
}

#' Look up a registered operator
#' @noRd
.get_op <- function(name) {
  if (!exists(name, envir = .OP_TABLE, inherits = FALSE)) {
    cli::cli_abort(c(
      "Unknown operator {.val {name}}.",
      "i" = "Registered operators: {.val {ls(.OP_TABLE)}}"
    ))
  }
  get(name, envir = .OP_TABLE)
}

#' List all registered operators
#' @noRd
.list_ops <- function() sort(ls(.OP_TABLE))
