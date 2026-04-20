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

  # SDTM / ADaM `--VAR` wildcard expansion. For each candidate domain
  # prefix (SDTM 2-char, ADaM "AD" prefix -> SDTM parent, SUPP prefix, etc.)
  # pick the first that yields a column actually present in data.
  candidates <- .domain_prefix_candidates(ctx, data)
  args <- .expand_wildcard_args(args, data, candidates)

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

#' Candidate domain prefixes for --VAR wildcard resolution
#'
#' The `--VAR` wildcard is an **SDTM-IG convention only** (SDTMIG s.2.5.1).
#' ADaMIG does not use it — ADaM variables are explicitly named
#' (AVAL, AVALC, PARAM, PARAMCD, ADT, ADY, ASTDY, AENDY, TRTEMFL, etc.).
#' So our resolver returns candidates only for SDTM + SEND datasets and
#' returns an empty list for ADaM. SUPP-- domains keep parent-domain
#' resolution because their rules sometimes reference the parent via `--`.
#'
#' Resolution order (first candidate that yields an existing column wins):
#'
#'   SDTM / SEND (AE, DM, LB, EX, VS, ...) -> first 2 chars of dataset name
#'   SUPP-- (SUPPAE, SUPPDM, ...)          -> parent-domain 2 chars (AE, DM)
#'   ADaM  (ADAE, ADLB, ADSL, ...)         -> NONE (wildcard stays unresolved;
#'                                            op sees `--VAR` as column,
#'                                            returns NA -> advisory)
#' @noRd
.domain_prefix_candidates <- function(ctx, data) {
  ds <- if (!is.null(ctx$current_dataset)) toupper(ctx$current_dataset) else NA_character_

  # ADaM datasets use explicit naming, no `--` convention.
  if (!is.na(ds) && startsWith(ds, "AD") && nchar(ds) >= 3L) {
    return(character(0))
  }

  candidates <- character()

  # Explicit domain override from ctx takes priority (e.g. a rule author
  # forces the prefix).
  if (!is.null(ctx$current_domain) && nzchar(ctx$current_domain)) {
    candidates <- c(candidates, toupper(ctx$current_domain))
  }

  if (!is.na(ds) && nzchar(ds)) {
    # SUPP-- domains: parent 2-char comes first (SUPPAE -> AE)
    if (startsWith(ds, "SUPP") && nchar(ds) >= 6L) {
      candidates <- c(candidates, substr(ds, 5L, 6L))
    }
    # SDTM / SEND: first 2 chars of dataset name
    candidates <- c(candidates, substr(ds, 1L, 2L))
  }

  # DOMAIN column fallback (rare — mostly for synthetic tests)
  if (!is.null(data$DOMAIN)) {
    u <- unique(as.character(data$DOMAIN))
    u <- u[nzchar(u)]
    if (length(u) == 1L) candidates <- c(candidates, toupper(u))
  }

  unique(candidates[nzchar(candidates)])
}

#' Resolve a `--VAR` wildcard against a dataset's actual columns
#' @noRd
.resolve_wildcard <- function(var_wildcard, data, candidates) {
  if (length(candidates) == 0L) return(var_wildcard)
  tail <- substr(var_wildcard, 3L, nchar(var_wildcard))
  # First candidate that produces a column actually in data wins
  for (cand in candidates) {
    col <- paste0(cand, tail)
    if (col %in% names(data)) return(col)
  }
  # No match: use the first (primary) candidate so downstream op can
  # report missing-column via its normal path (returns NA mask)
  paste0(candidates[1], tail)
}

.expand_wildcard_args <- function(args, data, candidates) {
  if (length(candidates) == 0L) return(args)
  for (nm in names(args)) {
    v <- args[[nm]]
    if (is.character(v) && length(v) == 1L && startsWith(v, "--")) {
      args[[nm]] <- .resolve_wildcard(v, data, candidates)
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
