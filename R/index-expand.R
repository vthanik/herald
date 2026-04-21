# -----------------------------------------------------------------------------
# index-expand.R -- expand xx / y / zz indexed variable placeholders
# -----------------------------------------------------------------------------
# Per ADaMIG Section 3: CDISC defines indexed-variable conventions used in
# standard names:
#   xx -- integer 01-99, zero-padded to two digits  (TRTxxPN, APERIODxx)
#   y  -- integer 1-9, NOT zero-padded, single digit (TRTPGy, RANDy)
#   zz -- integer 01-99, zero-padded (same shape as xx; used when the name
#         already contains xx for another slot, e.g. TRxxPGzz)
#
# A rule that references an indexed name (e.g. "TRTxxPN is present and TRTxxP
# is not present") applies PER concrete index value. If a dataset carries
# TRT01PN and TRT02PN, the rule must evaluate against both pairs (TRT01PN /
# TRT01P and TRT02PN / TRT02P) with matching indices.
#
# Design: the YAML check_tree can carry a top-level `expand:` key declaring
# which placeholder is used:
#
#   check:
#     expand: xx          # or "y", or "zz"
#     all:
#     - name: TRTxxPN
#       operator: exists
#     - name: TRTxxP
#       operator: not_exists
#
# At walk time, .expand_indexed() scans the dataset's column list for every
# concrete value that matches at least one leaf's name template, then
# deep-substitutes each value into a clone of the subtree and wraps the
# clones in a top-level `{any}` combinator. ANY matching index-instance
# that violates triggers the rule.
#
# When the placeholder resolves to zero concrete values (e.g. a dataset
# without any TRTxxPN columns), the rule is not applicable -- we return
# NA so the engine emits one advisory and never a false fire.

.INDEX_PATTERNS <- list(
  xx = "[0-9]{2}",
  y  = "[1-9]",
  zz = "[0-9]{2}"
)

#' Find every concrete value for placeholder `ph` in `cols` that matches the
#' name template. e.g. template="TRTxxPN", cols include "TRT01PN","TRT02PN"
#' -> c("01","02").
#' @noRd
.index_values_in_cols <- function(template, cols, ph) {
  if (!grepl(ph, template, fixed = TRUE)) return(character())
  stem <- .INDEX_PATTERNS[[ph]]
  if (is.null(stem)) return(character())
  rx <- paste0("^",
               gsub(ph, sprintf("(%s)", stem), template, fixed = TRUE),
               "$")
  m <- regmatches(cols, regexec(rx, cols))
  vals <- character()
  for (x in m) if (length(x) >= 2L) vals <- c(vals, x[[2L]])
  unique(vals)
}

#' Visit every leaf of a check_tree and collect the set of name templates
#' (character vector) that contain the placeholder.
#' @noRd
.collect_indexed_names <- function(node, ph, acc = character()) {
  if (!is.list(node) || length(node) == 0L) return(acc)
  if (!is.null(node$name) &&
      grepl(ph, as.character(node$name), fixed = TRUE)) {
    acc <- c(acc, as.character(node$name))
  }
  for (k in c("all", "any")) {
    ch <- node[[k]]
    if (!is.null(ch)) for (cc in ch) acc <- .collect_indexed_names(cc, ph, acc)
  }
  if (!is.null(node$not)) acc <- .collect_indexed_names(node$not, ph, acc)
  acc
}

#' Deep-substitute a concrete `value` for every occurrence of placeholder
#' `ph` in every leaf's `name` under `node`. Non-`name` fields are not
#' touched. Returns the modified tree.
#' @noRd
.substitute_index <- function(node, ph, value) {
  if (!is.list(node) || length(node) == 0L) return(node)
  if (!is.null(node$name)) {
    node$name <- gsub(ph, value, as.character(node$name), fixed = TRUE)
  }
  for (k in c("all", "any")) {
    ch <- node[[k]]
    if (!is.null(ch)) node[[k]] <- lapply(ch, .substitute_index,
                                          ph = ph, value = value)
  }
  if (!is.null(node$not)) {
    node$not <- .substitute_index(node$not, ph, value)
  }
  node
}

#' Expand a check_tree that declares an `expand:` placeholder against a
#' dataset's column list.
#'
#' Return shape is a list describing the expansion:
#'   $indexed      -- logical, TRUE if an `expand:` key was present and
#'                     resolved to at least one concrete value.
#'   $placeholder  -- character(1), the placeholder (`xx`, `y`, `zz`)
#'                     or NA.
#'   $instances    -- named list of per-instance trees (names are the
#'                     concrete index values, e.g. "01", "02"). Empty
#'                     when `$indexed` is FALSE or when no columns matched.
#'   $tree         -- the un-expanded tree for callers that want a single
#'                     walk (legacy path): `{any: [...]}` of all
#'                     instances, or a narrative stub when nothing matched,
#'                     or the original tree when not indexed.
#' @noRd
.expand_indexed <- function(check_tree, data) {
  no_expansion <- function(t) list(indexed = FALSE,
                                    placeholder = NA_character_,
                                    instances = list(), tree = t)
  if (!is.list(check_tree) || is.null(check_tree$expand)) {
    return(no_expansion(check_tree))
  }
  ph <- as.character(check_tree$expand)[[1L]]
  if (!ph %in% names(.INDEX_PATTERNS)) return(no_expansion(check_tree))

  body <- check_tree
  body$expand <- NULL

  templates <- .collect_indexed_names(body, ph)
  if (length(templates) == 0L) return(no_expansion(body))

  cols <- names(data)
  values <- unique(unlist(lapply(templates, .index_values_in_cols,
                                 cols = cols, ph = ph)))
  if (length(values) == 0L) {
    stub <- list(narrative = sprintf("no %s-indexed columns present", ph))
    return(list(indexed = TRUE, placeholder = ph,
                instances = list(), tree = stub))
  }
  instances <- stats::setNames(
    lapply(values, function(v) .substitute_index(body, ph, v)),
    values
  )
  list(indexed = TRUE, placeholder = ph,
       instances = instances,
       tree = list(any = unname(instances)))
}

#' Substitute a concrete index value for every occurrence of the
#' placeholder in a template string (rule message, variable field, etc.).
#' @noRd
.render_indexed_text <- function(txt, ph, value) {
  if (is.null(txt) || is.na(txt) || !nzchar(txt)) return(txt)
  gsub(ph, value, as.character(txt), fixed = TRUE)
}

#' Render a rule-message template by replacing all `--` occurrences with
#' the dataset's 2-char prefix. SDTM rules express variable wildcards as
#' `--VAR` (e.g. `--REASND`); when the rule fires on dataset `AE` the
#' finding message should read `AEREASND not present in dataset` rather
#' than `--REASND not present in dataset`.
#'
#' The substitution only runs when ds_name begins with two uppercase
#' letters and is NOT an ADaM dataset (ADaMIG does not use `--`). This
#' mirrors `.domain_prefix_candidates()` in R/rules-walk.R.
#' @noRd
.render_domain_prefix <- function(txt, ds_name) {
  if (is.null(txt) || is.na(txt) || !nzchar(txt)) return(txt)
  if (!grepl("--", txt, fixed = TRUE)) return(txt)
  u <- toupper(as.character(ds_name %||% ""))
  if (!nzchar(u) || nchar(u) < 2L) return(txt)
  # ADaM datasets do not use -- wildcards.
  if (startsWith(u, "AD") && nchar(u) >= 3L) return(txt)
  # SUPP-- domains expand via parent 2 chars (SUPPAE -> AE).
  prefix <- if (startsWith(u, "SUPP") && nchar(u) >= 6L) substr(u, 5L, 6L)
            else substr(u, 1L, 2L)
  gsub("--", prefix, as.character(txt), fixed = TRUE)
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L ||
                             (length(a) == 1L && is.na(a))) b else a
