# -----------------------------------------------------------------------------
# rules-crossrefs.R -- resolve $-prefixed cross-dataset references
# -----------------------------------------------------------------------------
# CDISC CORE rules frequently reference values from OTHER datasets via short
# $-prefixed tokens:
#
#   $dm_usubjid  -> unique USUBJID values in DM
#   $ta_armcd    -> unique ARMCD values in TA
#   $tv_visitnum -> unique VISITNUM values in TV
#   $usubjids_in_ex = alias for $ex_usubjid
#   $list_dataset_names = names(datasets)
#   $study_domains      = names(datasets)
#   $domain_label       = attr(datasets[[ctx$current_dataset]], "label")
#
# We resolve these at walk time so the operator sees the concrete vector
# instead of the literal string. Unresolved refs short-circuit the leaf to
# NA (advisory), so missing datasets produce honest "could not verify" rather
# than silent false-passes.
#
# Not in scope (M-$refs-v2):
#   $records_in_dataset, $column_order_from_dataset, $dataset_variables
#   -- these use $tokens as COLUMN names, which would require every
#   existence-style op to be aware of synthetic columns.

# -- index construction ------------------------------------------------------

#' Build a cross-reference lookup table for the lifetime of one `validate()`
#' call. Static refs (`$dm_usubjid`, `$list_dataset_names`, ...) are computed
#' up-front; dynamic ones (`$domain_label`) are encoded as resolver functions
#' of shape `function(ctx) -> character`.
#'
#' @param datasets named list of data frames keyed by UPPERCASE dataset name.
#' @param spec optional herald_spec for spec-driven refs.
#' @return a named list: names are lowercased ref tokens INCLUDING the `$`
#'   prefix; values are either character vectors or `function(ctx)`.
#' @noRd
build_crossrefs <- function(datasets, spec = NULL) {
  out <- list()

  if (length(datasets) > 0L) {
    ds_names <- toupper(names(datasets))
    out[["$list_dataset_names"]] <- ds_names
    out[["$study_domains"]]      <- ds_names

    for (ds_name in ds_names) {
      d <- datasets[[ds_name]]
      if (!is.data.frame(d)) next
      for (col in names(d)) {
        values <- unique(as.character(d[[col]]))
        values <- values[!is.na(values) & nzchar(values)]

        # Regular pattern: $<dom>_<col> (lowercase)
        tok <- paste0("$", tolower(ds_name), "_", tolower(col))
        out[[tok]] <- values

        # Alias: $usubjids_in_<dom> for the USUBJID column
        if (identical(col, "USUBJID")) {
          alias <- paste0("$usubjids_in_", tolower(ds_name))
          out[[alias]] <- values
        }
        # Alias: $armcd_list -> TA.ARMCD (convention)
        if (identical(ds_name, "TA") && identical(col, "ARMCD")) {
          out[["$armcd_list"]] <- values
        }
      }
    }
  }

  # Dynamic: $domain_label depends on ctx$current_dataset.
  out[["$domain_label"]] <- function(ctx) {
    ds <- ctx$current_dataset
    if (is.null(ds) || is.null(ctx$datasets[[ds]])) return(character(0))
    lbl <- attr(ctx$datasets[[ds]], "label")
    if (is.null(lbl)) return(character(0))
    as.character(lbl)
  }

  # Spec-driven refs are resolved only when a spec was supplied. Any ref
  # that requires the spec but is unavailable resolves to NULL (unresolved).
  if (!is.null(spec)) {
    ds_spec <- spec[["ds_spec"]]
    if (is.data.frame(ds_spec)) {
      # $required_variables / $allowed_variables are per-dataset in CDISC
      # CORE; represent as closures.
      out[["$required_variables"]] <- function(ctx) {
        .spec_cols(spec, ctx$current_dataset, c("required", "Required"))
      }
      out[["$allowed_variables"]] <- function(ctx) {
        .spec_cols(spec, ctx$current_dataset, c("allowed", "Allowed",
                                                "permissible", "Permissible"))
      }
    }
  }

  out
}

#' Pull a character vector of column names from a herald_spec for a given
#' dataset, matching any of the column names in `col_names`. Returns
#' character(0) if nothing matches.
#' @noRd
.spec_cols <- function(spec, ds_name, col_names) {
  v <- spec[["var_spec"]]
  if (!is.data.frame(v)) return(character(0))
  ds_col <- v[["dataset"]] %||% v[["Dataset"]] %||% rep(NA_character_, nrow(v))
  hits <- toupper(as.character(ds_col)) == toupper(as.character(ds_name %||% ""))
  if (!any(hits, na.rm = TRUE)) return(character(0))
  sub <- v[which(hits), , drop = FALSE]
  # Find a flag column in col_names; values are logical or truthy strings
  flag_col <- intersect(col_names, names(sub))
  if (length(flag_col) == 0L) return(character(0))
  mark <- sub[[flag_col[[1L]]]]
  keep <- if (is.logical(mark)) mark else toupper(as.character(mark)) %in% c("Y","YES","TRUE","1")
  name_col <- sub[["variable"]] %||% sub[["Variable"]] %||% rep(NA_character_, nrow(sub))
  as.character(name_col[keep])
}

# -- resolution --------------------------------------------------------------

#' Resolve a single `$`-prefixed token against `ctx`. Returns either a
#' character vector OR `NULL` to signal the token is unknown/unresolved.
#' Always logs a ctx$op_errors entry on miss (so the final herald_result
#' surfaces which datasets/refs the run couldn't verify).
#' @noRd
resolve_ref <- function(token, ctx) {
  if (!is.character(token) || length(token) != 1L || !startsWith(token, "$")) {
    return(NULL)
  }
  key <- tolower(token)
  reg <- ctx$crossrefs
  if (is.null(reg) || is.null(reg[[key]])) {
    .log_unresolved(ctx, key)
    return(NULL)
  }
  entry <- reg[[key]]
  if (is.function(entry)) {
    val <- tryCatch(entry(ctx), error = function(e) NULL)
    if (is.null(val) || length(val) == 0L) {
      .log_unresolved(ctx, key)
      return(NULL)
    }
    return(as.character(val))
  }
  as.character(entry)
}

#' Scan an args list and substitute any $-token values with their resolved
#' vectors. Returns `list(args = <mutated>, unresolved = <logical>)`.
#' If any `$`-token can't be resolved, `unresolved = TRUE` and the caller
#' is expected to short-circuit the leaf to NA.
#' @noRd
substitute_crossrefs <- function(args, ctx) {
  if (!is.list(args) || length(args) == 0L) {
    return(list(args = args, unresolved = FALSE))
  }
  unresolved <- FALSE
  for (k in names(args)) {
    v <- args[[k]]
    # Only handle plain character values here. Structured list values
    # (e.g. {reference_dataset, by, column} for is_inconsistent_across_dataset)
    # are handled inside their own operators.
    if (!is.character(v)) next
    hits <- startsWith(v, "$")
    if (!any(hits)) next
    for (i in which(hits)) {
      resolved <- resolve_ref(v[[i]], ctx)
      if (is.null(resolved)) {
        unresolved <- TRUE
        break
      }
      # Replace this $-element with its resolved vector; when a value arg
      # holds a mix of $-tokens and literals, unroll into the final set.
      v <- c(v[-i], resolved)
    }
    if (unresolved) break
    args[[k]] <- v
  }
  list(args = args, unresolved = unresolved)
}

# -- internals --------------------------------------------------------------

.log_unresolved <- function(ctx, token) {
  if (is.null(ctx)) return(invisible(NULL))
  ctx$op_errors <- c(ctx$op_errors, list(list(
    kind     = "unresolved_crossref",
    token    = token,
    dataset  = ctx$current_dataset %||% NA_character_,
    rule_id  = ctx$current_rule_id %||% NA_character_
  )))
  invisible(NULL)
}
