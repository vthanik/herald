# -----------------------------------------------------------------------------
# rules-walk.R — data-driven rule-tree walker
# -----------------------------------------------------------------------------
# Walks a rule's check_tree (nested list from YAML/JSON) against a dataset
# and returns a logical mask of length nrow(data):
#   TRUE  = record passes the check (rule satisfied)
#   FALSE = record fails the check (finding emitted)
#   NA    = indeterminate (advisory, never a finding)
#
# Short-circuit behaviour:
#   {all: [...]} narrows the active-row set passed to later children, so
#                rows that already failed an earlier child aren't re-scored.
#   {any: [...]} symmetrical: rows already passing are dropped from later
#                children.
#
# Error isolation: every leaf operator call is wrapped in tryCatch; on
# failure, that leaf contributes NA for every row and an entry is recorded
# in ctx$op_errors. One bad operator cannot halt validation of other rules.

#' Walk a check_tree node
#'
#' @param node  the check_tree fragment (named list)
#' @param data  the scoped data frame
#' @param ctx   a herald_ctx (list) — carries op_cache, op_errors, etc.
#' @return logical vector of length `nrow(data)`
#' @noRd
walk_tree <- function(node, data, ctx = NULL) {
  n <- nrow(data)
  if (is.null(n) || n == 0L) return(logical(0))

  # --- empty / narrative / missing ---
  if (is.null(node) || length(node) == 0L) {
    return(rep(NA, n))
  }

  # --- {narrative: "..."} advisory only ---
  if (!is.null(node[["narrative"]])) {
    return(rep(NA, n))
  }

  # --- {r_expression: "..."} escape hatch ---
  if (!is.null(node[["r_expression"]])) {
    return(.eval_r_expression(node[["r_expression"]], data, ctx))
  }

  # --- combinators ---
  if (!is.null(node[["all"]])) return(.walk_all(node[["all"]], data, ctx))
  if (!is.null(node[["any"]])) return(.walk_any(node[["any"]], data, ctx))
  if (!is.null(node[["not"]])) return(!walk_tree(node[["not"]], data, ctx))

  # --- leaf ---
  if (!is.null(node[["operator"]])) {
    return(.eval_leaf(node, data, ctx))
  }

  # Unknown shape — record as advisory
  if (!is.null(ctx)) ctx$op_errors <- c(
    ctx$op_errors, list(list(kind = "unknown_node", node = node))
  )
  rep(NA, n)
}

# --- combinators -------------------------------------------------------------

.walk_all <- function(children, data, ctx) {
  n <- nrow(data)
  if (length(children) == 0L) return(rep(TRUE, n))

  pass       <- rep(TRUE, n)   # all children so far returned TRUE
  false_seen <- rep(FALSE, n)  # at least one child explicitly returned FALSE
  na_seen    <- rep(FALSE, n)  # at least one child returned NA
  active     <- rep(TRUE, n)   # rows still in the running (not yet failed)

  for (child in children) {
    if (!any(active)) break
    sub <- walk_tree(child, data[active, , drop = FALSE], ctx)
    full <- rep(NA, n)
    full[active] <- sub

    false_seen <- false_seen | (!is.na(full) & !full)
    na_seen    <- na_seen    | is.na(full)
    pass       <- pass & (full %in% TRUE)
    active     <- active & (full %in% TRUE)
  }

  # Resolve per row:
  #   TRUE   iff pass is still TRUE (every child returned TRUE)
  #   FALSE  iff any child explicitly returned FALSE
  #   NA     iff not a pass and no explicit FALSE (only NA contributed)
  out <- rep(TRUE, n)
  out[false_seen] <- FALSE
  out[!false_seen & !pass & na_seen] <- NA
  out
}

.walk_any <- function(children, data, ctx) {
  n <- nrow(data)
  if (length(children) == 0L) return(rep(FALSE, n))

  any_true   <- rep(FALSE, n)  # at least one child returned TRUE
  false_seen <- rep(FALSE, n)  # at least one child explicitly returned FALSE
  na_seen    <- rep(FALSE, n)  # at least one child returned NA
  active     <- rep(TRUE, n)   # rows still in the running (not yet succeeded)

  for (child in children) {
    if (!any(active)) break
    sub <- walk_tree(child, data[active, , drop = FALSE], ctx)
    full <- rep(NA, n)
    full[active] <- sub

    false_seen <- false_seen | (!is.na(full) & !full)
    na_seen    <- na_seen    | is.na(full)
    any_true   <- any_true   | (full %in% TRUE)
    active     <- active & !(full %in% TRUE)
  }

  # Resolve per row:
  #   TRUE   iff at least one child returned TRUE
  #   FALSE  iff no TRUE and every child returned FALSE (no NA contributed)
  #   NA     iff no TRUE and at least one NA (undecidable)
  out <- rep(FALSE, n)
  out[any_true] <- TRUE
  out[!any_true & na_seen] <- NA
  out
}

# --- leaf dispatch -----------------------------------------------------------

.eval_leaf <- function(node, data, ctx) {
  op_name <- node[["operator"]]
  fn <- tryCatch(.get_op(op_name),
                 error = function(e) NULL)
  if (is.null(fn)) {
    if (!is.null(ctx)) ctx$op_errors <- c(
      ctx$op_errors, list(list(kind = "unknown_operator", operator = op_name))
    )
    return(rep(NA, nrow(data)))
  }

  # Strip 'operator' key; remaining keys are op args.
  args <- node[setdiff(names(node), "operator")]

  # SDTM `--VAR` wildcard expansion: replace the leading `--` with the
  # 2-char domain prefix from ctx$current_domain (falls back to the first
  # 2 chars of ctx$current_dataset). Applied to any string arg value
  # that starts with "--" (typically `name`, but also to `value` fields
  # when the value is a cross-reference to another variable).
  domain_prefix <- .domain_prefix(ctx, data)
  args <- .expand_wildcard_args(args, domain_prefix)

  tryCatch(
    do.call(fn, c(list(data = data, ctx = ctx), args)),
    error = function(e) {
      if (!is.null(ctx)) ctx$op_errors <- c(
        ctx$op_errors,
        list(list(kind = "op_error", operator = op_name,
                  message = conditionMessage(e)))
      )
      rep(NA, nrow(data))
    }
  )
}

.domain_prefix <- function(ctx, data) {
  if (!is.null(ctx$current_domain) && nzchar(ctx$current_domain)) {
    return(toupper(ctx$current_domain))
  }
  if (!is.null(ctx$current_dataset) && nzchar(ctx$current_dataset)) {
    return(toupper(substr(ctx$current_dataset, 1, 2)))
  }
  # Fall back to reading the DOMAIN column if present (single unique value)
  if (!is.null(data$DOMAIN)) {
    u <- unique(as.character(data$DOMAIN))
    u <- u[nzchar(u)]
    if (length(u) == 1L) return(toupper(u))
  }
  NA_character_
}

.expand_wildcard_args <- function(args, prefix) {
  if (is.na(prefix) || is.null(prefix)) return(args)
  for (nm in names(args)) {
    v <- args[[nm]]
    if (is.character(v) && length(v) == 1L && startsWith(v, "--")) {
      args[[nm]] <- paste0(prefix, substr(v, 3, nchar(v)))
    }
  }
  args
}

# --- r_expression escape hatch -----------------------------------------------

.eval_r_expression <- function(expr_str, data, ctx) {
  n <- nrow(data)
  mask_env <- tryCatch(rlang::new_data_mask(rlang::as_environment(data)),
                       error = function(e) NULL)
  if (is.null(mask_env)) return(rep(NA, n))

  result <- tryCatch({
    ex <- rlang::parse_expr(expr_str)
    rlang::eval_tidy(ex, data = mask_env)
  }, error = function(e) {
    if (!is.null(ctx)) ctx$op_errors <- c(
      ctx$op_errors,
      list(list(kind = "r_expression_error",
                expr = expr_str, message = conditionMessage(e)))
    )
    NULL
  })

  if (is.null(result)) return(rep(NA, n))
  if (length(result) == 1L) result <- rep(result, n)
  if (length(result) != n) return(rep(NA, n))
  as.logical(result)
}

# --- ctx constructor ---------------------------------------------------------

#' Build a herald_ctx environment for a validate() run
#'
#' The ctx is an environment (not a list) so operators + combinators can
#' append to `ctx$op_errors` by reference. Fields:
#'   op_errors   list   appended on each leaf failure / unknown operator
#'   op_cache    env    per-(dataset, column, op, args_hash) memoization
#' @noRd
new_herald_ctx <- function() {
  e <- new.env(parent = emptyenv())
  e$op_errors <- list()
  e$op_cache  <- new.env(parent = emptyenv())
  e
}
