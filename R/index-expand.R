# -----------------------------------------------------------------------------
# index-expand.R -- expand xx / y / zz indexed variable placeholders
# -----------------------------------------------------------------------------
# Per ADaMIG Section 3: CDISC defines indexed-variable conventions used in
# standard names:
#   xx -- integer 01-99, zero-padded to two digits  (TRTxxPN, APERIODxx)
#   y  -- integer 1-9, NOT zero-padded, single digit (TRTPGy, RANDy)
#   zz -- integer 01-99, zero-padded (same shape as xx; used when the name
#         already contains xx for another slot, e.g. TRxxPGzz)
#   w  -- integer 1-9, NOT zero-padded (ADaMIG stratum index, STRATwR)
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
  y = "[1-9]",
  zz = "[0-9]{2}",
  w = "[1-9]",
  # `stem` is a prefix wildcard used for suffix-style rules
  # ("a variable ending in GRyN ..."); matches an alphanumeric stem
  # starting with a letter. Mirrors P21's `@*` / `_*` concept
  # (MagicVariable.regexify:198-223) where each wildcard compiles to
  # a regex capture group; here it is `[A-Z][A-Z0-9]+`.
  stem = "[A-Z][A-Z0-9]+"
)

# Order matters when a template contains multiple placeholders: longer
# placeholders must be substituted first so e.g. `xx` inside `TRxxPGy`
# doesn't accidentally collide with a later one-char scan. Sorted by
# decreasing length.
.INDEX_PATTERN_ORDER <- names(.INDEX_PATTERNS)[
  order(-nchar(names(.INDEX_PATTERNS)))
]

#' Find every concrete value for placeholder `ph` in `cols` that matches the
#' name template. e.g. template="TRTxxPN", cols include "TRT01PN","TRT02PN"
#' -> c("01","02").
#' @noRd
.index_values_in_cols <- function(template, cols, ph) {
  if (!grepl(ph, template, fixed = TRUE)) {
    return(character())
  }
  stem <- .INDEX_PATTERNS[[ph]]
  if (is.null(stem)) {
    return(character())
  }
  rx <- paste0(
    "^",
    gsub(ph, sprintf("(%s)", stem), template, fixed = TRUE),
    "$"
  )
  m <- regmatches(cols, regexec(rx, cols))
  vals <- character()
  for (x in m) {
    if (length(x) >= 2L) vals <- c(vals, x[[2L]])
  }
  unique(vals)
}

#' Visit every leaf of a check_tree and collect the set of name templates
#' (character vector) that contain the placeholder.
#' @noRd
.collect_indexed_names <- function(node, ph, acc = character()) {
  if (!is.list(node) || length(node) == 0L) {
    return(acc)
  }
  if (
    !is.null(node$name) &&
      grepl(ph, as.character(node$name), fixed = TRUE)
  ) {
    acc <- c(acc, as.character(node$name))
  }
  for (k in c("all", "any")) {
    ch <- node[[k]]
    if (!is.null(ch)) {
      for (cc in ch) {
        acc <- .collect_indexed_names(cc, ph, acc)
      }
    }
  }
  if (!is.null(node$not)) {
    acc <- .collect_indexed_names(node$not, ph, acc)
  }
  acc
}

#' Deep-substitute a concrete `value` for every occurrence of placeholder
#' `ph` in every leaf's `name` under `node`. Also rewrites nested string
#' fields inside `value` (e.g. `value.related_name`, `value.group_by`)
#' so operators that accept wildcard names via structured args pick up
#' the substitution. Returns the modified tree.
#' @noRd
.substitute_index <- function(node, ph, value) {
  if (!is.list(node) || length(node) == 0L) {
    return(node)
  }
  if (!is.null(node$name)) {
    node$name <- gsub(ph, value, as.character(node$name), fixed = TRUE)
  }
  if (!is.null(node$value)) {
    node$value <- .substitute_index_deep(node$value, ph, value)
  }
  for (k in c("all", "any")) {
    ch <- node[[k]]
    if (!is.null(ch)) {
      node[[k]] <- lapply(ch, .substitute_index, ph = ph, value = value)
    }
  }
  if (!is.null(node$not)) {
    node$not <- .substitute_index(node$not, ph, value)
  }
  node
}

#' Recursively rewrite every character element in a nested list,
#' substituting `ph` -> `value` anywhere it appears. Used for op args
#' like `value.related_name` and `value.group_by` where the index
#' placeholder must be resolved alongside the primary `name` leaf.
#' @noRd
.substitute_index_deep <- function(x, ph, value) {
  if (is.character(x)) {
    return(gsub(ph, value, x, fixed = TRUE))
  }
  if (is.list(x)) {
    return(lapply(x, .substitute_index_deep, ph = ph, value = value))
  }
  x
}

#' Parse the `expand:` slot into a character vector of placeholder names.
#' Accepts scalars ("xx"), comma-separated strings ("xx,y"), or explicit
#' YAML sequences (c("xx", "y")). Whitespace is trimmed and unknown
#' placeholders are dropped with a warning-less pass-through -- the
#' caller treats the expand as a no-op when the vector is empty.
#' @noRd
.parse_expand_spec <- function(expand) {
  if (is.null(expand)) {
    return(character())
  }
  if (length(expand) > 1L) {
    raw <- as.character(unlist(expand))
  } else {
    raw <- as.character(expand)
    if (length(raw) == 1L && grepl("[,;| ]", raw)) {
      raw <- trimws(strsplit(raw, "[,;| ]+", perl = TRUE)[[1L]])
    }
  }
  raw <- raw[nzchar(raw)]
  raw[raw %in% names(.INDEX_PATTERNS)]
}

#' Match every column against a template with one OR MORE placeholders,
#' extracting each placeholder's concrete value per matching column.
#' Returns a list of named tuples: `list(list(xx="01", y="3"),
#' list(xx="02", y="5"), ...)`. Mirrors P21's `MagicVariable.regexify`
#' (MagicVariable.java:198-223) which compiles `#`/`@`/`_` wildcards to
#' regex capture groups and iterates `matcher.matches()` over the
#' variable list (line 104-147).
#' @noRd
.multi_values_in_cols <- function(template, cols, phs) {
  present_phs <- phs[vapply(
    phs,
    function(p) {
      grepl(p, template, fixed = TRUE)
    },
    logical(1L)
  )]
  if (length(present_phs) == 0L) {
    return(list())
  }

  # Sort placeholders by appearance order so capture-group index matches
  # the left-to-right order in the template -- this is how regex capture
  # groups are numbered.
  positions <- vapply(
    present_phs,
    function(p) {
      regexpr(p, template, fixed = TRUE)[[1L]]
    },
    integer(1L)
  )
  ordered_phs <- present_phs[order(positions)]

  rx <- template
  # Substitute longest placeholders first so `xx` inside template doesn't
  # get clobbered by a later single-char substitution.
  for (p in .INDEX_PATTERN_ORDER) {
    if (!p %in% ordered_phs) {
      next
    }
    rx <- sub(p, sprintf("(%s)", .INDEX_PATTERNS[[p]]), rx, fixed = TRUE)
  }
  rx <- paste0("^", rx, "$")

  m <- regmatches(cols, regexec(rx, cols))
  out <- list()
  for (entry in m) {
    if (length(entry) != length(ordered_phs) + 1L) {
      next
    }
    # Build tuple in the requested `phs` order (consistent across
    # templates) with NA for placeholders missing from this template.
    tup <- stats::setNames(as.list(entry[-1L]), ordered_phs)
    for (missing_ph in setdiff(phs, names(tup))) {
      tup[[missing_ph]] <- NA_character_
    }
    out <- c(out, list(tup[phs]))
  }
  out
}

#' Collect every leaf `name` in the tree that contains AT LEAST ONE of
#' the placeholders in `phs`.
#' @noRd
.collect_indexed_names_any <- function(node, phs, acc = character()) {
  if (!is.list(node) || length(node) == 0L) {
    return(acc)
  }
  if (
    !is.null(node$name) &&
      any(vapply(
        phs,
        function(p) grepl(p, as.character(node$name), fixed = TRUE),
        logical(1L)
      ))
  ) {
    acc <- c(acc, as.character(node$name))
  }
  for (k in c("all", "any")) {
    ch <- node[[k]]
    if (!is.null(ch)) {
      for (cc in ch) {
        acc <- .collect_indexed_names_any(cc, phs, acc)
      }
    }
  }
  if (!is.null(node$not)) {
    acc <- .collect_indexed_names_any(node$not, phs, acc)
  }
  acc
}

#' Deep-substitute a full tuple of (placeholder -> value) mappings into
#' every leaf's `name`. Missing values (NA) in the tuple are skipped so
#' a template using only a subset of the placeholders keeps its
#' remaining placeholders intact for the operator to surface as a
#' missing column -> NA mask.
#' @noRd
.substitute_tuple <- function(node, tuple) {
  for (ph in names(tuple)) {
    v <- tuple[[ph]]
    if (is.na(v)) {
      next
    }
    node <- .substitute_index(node, ph, v)
  }
  node
}

#' Expand a check_tree that declares an `expand:` slot against a
#' dataset's column list.
#'
#' Accepts single-placeholder (`expand: xx`) OR multi-placeholder
#' (`expand: [xx, y]` / `expand: "xx,y"`) specs. For multi-placeholder,
#' iterates the Cartesian product of placeholder values actually found
#' in matching columns, producing one instance per (xx, y) tuple. A
#' stem placeholder (`stem`, P21 `*`-wildcard analogue) lets
#' suffix-style rules iterate every column stem.
#'
#' Return shape:
#'   $indexed      -- TRUE if `expand:` was present and resolved to at
#'                     least one tuple.
#'   $placeholder  -- comma-joined placeholder list.
#'   $instances    -- named list of per-tuple trees (names are the
#'                     concrete tuple values).
#'   $tree         -- `{any: [...]}` of all instances, or narrative
#'                     stub when nothing matched, or the original tree
#'                     when not indexed.
#' @noRd
.expand_indexed <- function(check_tree, data) {
  no_expansion <- function(t) {
    list(
      indexed = FALSE,
      placeholder = NA_character_,
      instances = list(),
      tuples = list(),
      tree = t
    )
  }
  if (!is.list(check_tree) || is.null(check_tree$expand)) {
    return(no_expansion(check_tree))
  }
  phs <- .parse_expand_spec(check_tree$expand)
  if (length(phs) == 0L) {
    return(no_expansion(check_tree))
  }

  body <- check_tree
  body$expand <- NULL

  templates <- unique(.collect_indexed_names_any(body, phs))
  if (length(templates) == 0L) {
    return(no_expansion(body))
  }

  cols <- names(data)
  tuples <- list()
  for (tmpl in templates) {
    tuples <- c(tuples, .multi_values_in_cols(tmpl, cols, phs))
  }
  # Deduplicate tuples.
  keys <- vapply(
    tuples,
    function(t) {
      paste(
        vapply(phs, function(p) as.character(t[[p]]), character(1L)),
        collapse = "|"
      )
    },
    character(1L)
  )
  tuples <- tuples[!duplicated(keys)]

  if (length(tuples) == 0L) {
    stub <- list(
      narrative = sprintf(
        "no [%s]-indexed columns present",
        paste(phs, collapse = ",")
      )
    )
    return(list(
      indexed = TRUE,
      placeholder = paste(phs, collapse = ","),
      instances = list(),
      tuples = list(),
      tree = stub
    ))
  }

  # Instance names: for single-placeholder, preserve the concrete value
  # (e.g. "01") so existing callers that `gsub` the placeholder against
  # `names(instances)[i]` keep working. For multi-placeholder, use
  # "ph1=v1,ph2=v2" form and rely on `$tuples` for rendering.
  instance_names <- if (length(phs) == 1L) {
    vapply(tuples, function(t) as.character(t[[phs[[1L]]]]), character(1L))
  } else {
    vapply(
      tuples,
      function(t) {
        paste(
          vapply(phs, function(p) sprintf("%s=%s", p, t[[p]]), character(1L)),
          collapse = ","
        )
      },
      character(1L)
    )
  }
  instances <- stats::setNames(
    lapply(tuples, function(t) .substitute_tuple(body, t)),
    instance_names
  )
  tuples_named <- stats::setNames(tuples, instance_names)
  list(
    indexed = TRUE,
    placeholder = paste(phs, collapse = ","),
    instances = instances,
    tuples = tuples_named,
    tree = list(any = unname(instances))
  )
}

#' Substitute a concrete index value for every occurrence of the
#' placeholder in a template string (rule message, variable field, etc.).
#' @noRd
.render_indexed_text <- function(txt, ph, value) {
  if (is.null(txt) || is.na(txt) || !nzchar(txt)) {
    return(txt)
  }
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
  # txt may be a multi-element character vector (e.g. composite-key
  # `name: [STUDYID, SUBJID]` in an `is_not_unique_set` tree). Handle
  # vectors by recursing element-wise.
  if (is.null(txt)) {
    return(txt)
  }
  if (length(txt) > 1L) {
    return(vapply(txt, .render_domain_prefix, character(1L), ds_name = ds_name))
  }
  if (is.na(txt) || !nzchar(txt)) {
    return(txt)
  }
  if (!grepl("--", txt, fixed = TRUE)) {
    return(txt)
  }
  u <- toupper(as.character(ds_name %||% ""))
  if (!nzchar(u) || nchar(u) < 2L) {
    return(txt)
  }
  # ADaM datasets do not use -- wildcards.
  if (startsWith(u, "AD") && nchar(u) >= 3L) {
    return(txt)
  }
  # SUPP-- domains expand via parent 2 chars (SUPPAE -> AE).
  prefix <- if (startsWith(u, "SUPP") && nchar(u) >= 6L) {
    substr(u, 5L, 6L)
  } else {
    substr(u, 1L, 2L)
  }
  gsub("--", prefix, as.character(txt), fixed = TRUE)
}
