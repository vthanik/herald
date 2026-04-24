# -----------------------------------------------------------------------------
# rules-operations.R -- Operations pre-compute dispatcher
# -----------------------------------------------------------------------------
# Called once per (rule, dataset) pair in validate() BEFORE walk_tree().
# Runs every entry in rule$operations against the appropriate dataset,
# stamps the result as a `$id`-named column on `data`, and also caches it
# in ctx$op_results so that `value: "$id"` substitutions via
# substitute_crossrefs() pick it up without a second lookup.
#
# Entry schema (PascalCase from CORE YAML, lowercased after compile):
#   id:       "$token_name"   -- column name to stamp; starts with "$"
#   operator: "distinct"      -- key in .OP_TABLE_OPS
#   name:     "DOMAIN"        -- target column in data (optional)
#   domain:   "EX"            -- dataset to run against (default: current)
#   group:    "USUBJID"       -- grouping variable (optional)
#
# Result-stamping rules (mirror base_operation._handle_operation_result):
#   scalar / length-1 vector -> broadcast to all rows.
#   vector of length nrow(data) -> row-wise assignment.
#   anything else -> list-column (each row holds the same value).

#' Dispatch all Operations entries for one rule against one dataset.
#'
#' @param rule_ops  list of Operations entry lists (rule$operations).
#' @param data      the current target data.frame.
#' @param datasets  full named list of datasets from ctx (for cross-domain ops).
#' @param ctx       herald_ctx environment.
#' @return data with `$id` columns appended for each successful operation.
#' @noRd
.apply_operations <- function(rule_ops, data, datasets, ctx) {
  if (is.null(rule_ops) || length(rule_ops) == 0L) return(data)
  if (!is.data.frame(data)) return(data)
  n <- nrow(data)
  if (n == 0L) return(data)

  for (op_entry in rule_ops) {
    op_id   <- op_entry[["id"]] %||% NA_character_
    op_name <- op_entry[["operator"]] %||% NA_character_
    if (is.na(op_id) || is.na(op_name) || !nzchar(op_id)) next

    fn <- .get_operation(op_name)
    if (is.null(fn)) {
      # Unknown operation: record error, leave $id out (leaf -> NA advisory)
      if (!is.null(ctx)) ctx$op_errors <- c(
        ctx$op_errors,
        list(list(kind = "unknown_operation", operator = op_name, id = op_id))
      )
      next
    }

    # Resolve the target dataset: op_entry$domain overrides the current one.
    target_ds_name <- toupper(op_entry[["domain"]] %||% "")
    target_data <- if (nzchar(target_ds_name) &&
                       !is.null(datasets[[target_ds_name]])) {
      datasets[[target_ds_name]]
    } else {
      data
    }

    result <- tryCatch(
      fn(target_data, ctx, op_entry),
      error = function(e) {
        if (!is.null(ctx)) ctx$op_errors <- c(
          ctx$op_errors,
          list(list(kind = "operation_error", operator = op_name,
                    id = op_id, message = conditionMessage(e)))
        )
        NULL
      }
    )
    if (is.null(result)) next

    # Cache in ctx so substitute_crossrefs() finds it via resolve_ref().
    if (!is.null(ctx)) {
      if (is.null(ctx$op_results)) ctx$op_results <- list()
      ctx$op_results[[op_id]] <- result
    }

    # Stamp as column on data (for `name: $id` leaf resolution).
    data <- .stamp_op_result(data, op_id, result, n)
  }
  data
}

#' Stamp an Operations result as a column on `data`.
#'
#' Follows CDISC's three-case result-handling contract:
#'   scalar / length 1 -> recycle to all n rows.
#'   length == n        -> row-wise (e.g. per-row dy calculation).
#'   other length       -> list-column, each row holds the same value.
#' @noRd
.stamp_op_result <- function(data, col_name, result, n) {
  if (length(result) == 1L) {
    data[[col_name]] <- result          # recycled by data.frame
  } else if (length(result) == n) {
    data[[col_name]] <- result
  } else {
    # Array result (e.g. vector of distinct domain codes) -- list-column.
    data[[col_name]] <- rep(list(result), n)
  }
  data
}
