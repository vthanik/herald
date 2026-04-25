# -----------------------------------------------------------------------------
# herald-ops.R  --  operator registry + metadata
# -----------------------------------------------------------------------------
# Every operator in R/ops-*.R calls .register_op() at package load. The
# walker in R/rules-walk.R looks up operators from .OP_TABLE; docs and
# tooling look up metadata from .OP_META.
#
# Operator contract:
#   op(data, ctx, ...) -> logical(nrow(data))
#     TRUE  = record passes the check (rule satisfied)
#     FALSE = record fails the check (finding emitted)
#     NA    = indeterminate (advisory, no finding)
#
# Why two envs instead of S7 per op: operators are a homogeneous catalog of
# callables  --  no polymorphism to dispatch on. S7 would tax the hot path
# (1500+ rules x N rows) with property lookups for no gain.

.OP_TABLE <- new.env(parent = emptyenv()) # name -> function
.OP_META <- new.env(parent = emptyenv()) # name -> metadata list

# Metadata schema (all fields optional; defaults shown):
#   name           chr(1)   the registry key
#   kind           chr(1)   "string"|"compare"|"existence"|"set"|"temporal"|"cross"|"spec"
#   summary        chr(1)   one-line description for docs
#   arg_schema     list     list(argname = list(type, required, default))
#   cost_hint      chr(1)   "O(n)"|"O(n log n)"|"O(n*m)"
#   column_arg     chr(1)   which arg names the column being scanned, NA if none
#   returns_na_ok  lgl(1)   whether NA means indeterminate (advisory)
#   examples       list     small examples
#   registered_in  chr(1)   source file, auto-filled at registration
.DEFAULT_META <- list(
  name = NA_character_,
  kind = NA_character_,
  summary = "",
  arg_schema = list(),
  cost_hint = "O(n)",
  column_arg = NA_character_,
  returns_na_ok = TRUE,
  examples = list(),
  registered_in = NA_character_
)

.register_op <- function(name, fn, meta = list()) {
  call <- rlang::caller_env()
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    herald_error_runtime(
      "{.arg name} must be a non-empty scalar character string.",
      call = call
    )
  }
  if (!is.function(fn)) {
    herald_error_runtime("{.arg fn} must be a function.", call = call)
  }

  if (exists(name, envir = .OP_TABLE, inherits = FALSE)) {
    cli::cli_warn("Operator {.val {name}} is being re-registered.")
  }

  merged <- utils::modifyList(.DEFAULT_META, meta)
  merged$name <- name
  if (is.na(merged$registered_in)) {
    merged$registered_in <- .caller_source_file()
  }

  assign(name, fn, envir = .OP_TABLE)
  assign(name, merged, envir = .OP_META)
  invisible(NULL)
}

#' Look up a registered operator function
#' @noRd
.get_op <- function(name) {
  if (!exists(name, envir = .OP_TABLE, inherits = FALSE)) {
    herald_error_runtime(c(
      "Unknown operator {.val {name}}.",
      "i" = "Registered operators: {.val {sort(ls(.OP_TABLE))}}"
    ))
  }
  get(name, envir = .OP_TABLE)
}

#' Operator metadata accessor
#'
#' `.op_meta(NULL)` returns a tibble of every registered operator.
#' `.op_meta("iso8601")` returns the single metadata list.
#'
#' @noRd
.op_meta <- function(name = NULL) {
  if (!is.null(name)) {
    if (!exists(name, envir = .OP_META, inherits = FALSE)) {
      herald_error_runtime("No metadata for operator {.val {name}}.")
    }
    return(get(name, envir = .OP_META))
  }
  # Return all, as a tibble
  all_names <- sort(ls(.OP_META))
  if (length(all_names) == 0L) {
    return(tibble::tibble(
      name = character(),
      kind = character(),
      summary = character(),
      cost_hint = character(),
      column_arg = character(),
      returns_na_ok = logical(),
      registered_in = character()
    ))
  }
  rows <- lapply(all_names, function(n) get(n, envir = .OP_META))
  tibble::tibble(
    name = vapply(rows, `[[`, character(1), "name"),
    kind = vapply(rows, function(r) r$kind %||% NA_character_, character(1)),
    summary = vapply(rows, `[[`, character(1), "summary"),
    cost_hint = vapply(rows, `[[`, character(1), "cost_hint"),
    column_arg = vapply(
      rows,
      function(r) r$column_arg %||% NA_character_,
      character(1)
    ),
    returns_na_ok = vapply(rows, `[[`, logical(1), "returns_na_ok"),
    registered_in = vapply(
      rows,
      function(r) r$registered_in %||% NA_character_,
      character(1)
    )
  )
}

#' Names of all registered operators (sorted)
#' @noRd
.list_ops <- function() sort(ls(.OP_TABLE))

# --- internal: figure out which file called .register_op() -------------------
# Walks the call stack looking for the first frame outside herald-ops.R.
.caller_source_file <- function() {
  calls <- sys.calls()
  for (i in rev(seq_along(calls))) {
    srcref <- attr(calls[[i]], "srcref")
    if (is.null(srcref)) {
      next
    }
    file <- attr(srcref, "srcfile")$filename
    if (is.null(file) || !nzchar(file)) {
      next
    }
    bn <- basename(file)
    if (identical(bn, "herald-ops.R")) {
      next
    }
    return(bn)
  }
  NA_character_
}

# --- cross-dataset reference resolver ---------------------------------------

#' Resolve a reference dataset from ctx$datasets
#'
#' Used by cross-dataset operators. Returns NULL when the dataset is absent
#' and records the miss to `ctx$missing_refs` so the caller can surface it
#' as a skipped_refs banner item.
#' @noRd
.ref_ds <- function(ctx, ref_name) {
  if (is.null(ctx) || is.null(ctx$datasets)) {
    return(NULL)
  }
  up <- toupper(as.character(ref_name))
  hit <- ctx$datasets[[up]]
  if (is.null(hit)) {
    .record_missing_ref(
      ctx,
      rule_id = ctx$current_rule_id,
      kind = "dataset",
      name = up
    )
  }
  hit
}
