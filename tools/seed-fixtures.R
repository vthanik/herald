# -----------------------------------------------------------------------------
# tools/seed-fixtures.R -- auto-seed golden fixtures for executable rules
# -----------------------------------------------------------------------------
# Run from the package root:
#
#   Rscript tools/seed-fixtures.R [--force]
#
# Writes tests/testthat/fixtures/golden/<authority>/<rule_id>/{positive,negative}.json
#
# Phase 1c + 2 + C scope:
#   * single-leaf + multi-leaf `{all: [...]}` / `{any: [...]}` trees
#   * `{not: leaf}` wrappers (leaf polarity tracked + swapped at emit time)
#   * --VAR wildcard expansion for SDTM rules (class -> representative domain)
#   * spec-based class resolution for class-scoped rules
#   * multi-row structural operators (is_unique_set, is_not_unique_set,
#     is_unique_relationship, is_not_unique_relationship)
#   * comparison, date compare, case-insensitive, prefix/suffix operators
#   * Phase C: $<dom>_<col> and $usubjids_in_<dom> cross-dataset refs --
#     seeder builds the referenced dataset alongside the main dataset with
#     controlled values so the leaf can fire (positive) or pass (negative).
#
# Still skipped: nested combinators (`{all: [{all: [...]}]}`), meta-refs
# like `$domain_label` / `$list_dataset_names` / spec-driven refs,
# aggregate refs (`$max_ex_exstdtc`), `r_expression` rules, narrative trees.
#
# Idempotency: fixtures authored manually (`authored: "manual"`) are never
# overwritten. Auto-seeded fixtures ARE overwritten on each run.
#
# Run-to-verify: every candidate is fed through validate() with the
# constructed spec to confirm the variant actually fires (or not).

suppressPackageStartupMessages({
  library(jsonlite)
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(quiet = TRUE)
  } else {
    library(herald)
  }
})

SEEDER_VERSION <- "auto-seed@4"

WHITELIST_OPS <- c(
  # existence
  "exists", "not_exists", "non_empty", "empty",
  # equality + compare
  "equal_to", "not_equal_to",
  "equal_to_case_insensitive", "not_equal_to_case_insensitive",
  "greater_than", "less_than",
  "greater_than_or_equal_to", "less_than_or_equal_to",
  # date compare
  "date_greater_than", "date_less_than",
  "date_equal_to", "date_not_equal_to",
  "date_greater_than_or_equal_to", "date_less_than_or_equal_to",
  # string match
  "matches_regex", "not_matches_regex",
  "contains", "does_not_contain",
  "starts_with", "ends_with",
  "longer_than", "shorter_than", "length_le",
  # prefix / suffix
  "prefix_equal_to", "prefix_not_equal_to",
  "prefix_matches_regex", "not_prefix_matches_regex",
  "suffix_matches_regex", "not_suffix_matches_regex",
  # set membership
  "is_contained_by", "is_not_contained_by",
  "is_contained_by_case_insensitive", "is_not_contained_by_case_insensitive",
  # structural (multi-row)
  "is_unique_set", "is_not_unique_set",
  "is_unique_relationship", "is_not_unique_relationship",
  # temporal / format
  "iso8601", "is_complete_date", "is_incomplete_date",
  "invalid_date"
)

# Canonical SDTM class -> representative domain for --VAR wildcard expansion.
CLASS_TO_DOMAIN <- list(
  "EVENTS"          = "AE",
  "INTERVENTIONS"   = "CM",
  "FINDINGS"        = "LB",
  "FINDINGS ABOUT"  = "FA",
  "FINDINGS-ABOUT"  = "FA",
  "SPECIAL PURPOSE" = "DM",
  "SPECIAL-PURPOSE" = "DM",
  "TRIAL DESIGN"    = "TA",
  "TRIAL-DESIGN"    = "TA",
  "RELATIONSHIP"    = "RELREC"
)

fx_root <- file.path("tests", "testthat", "fixtures", "golden")
dir.create(fx_root, recursive = TRUE, showWarnings = FALSE)

# -- tree walking -----------------------------------------------------------

#' Walk a check_tree and return a flat list of
#' `list(leaf = <leaf-node>, inverted = <logical>)` entries, or NULL when
#' the tree has a shape we don't support (nested combinator, narrative,
#' r_expression).
.extract_leaves <- function(node, inverted = FALSE) {
  if (!is.list(node) || length(node) == 0L) return(NULL)
  if (!is.null(node[["r_expression"]])) return(NULL)
  if (!is.null(node[["narrative"]])) return(NULL)

  if (!is.null(node[["operator"]])) {
    return(list(list(leaf = node, inverted = inverted)))
  }
  if (!is.null(node[["not"]])) {
    return(.extract_leaves(node[["not"]], inverted = !inverted))
  }
  for (key in c("all", "any")) {
    ch <- node[[key]]
    if (!is.null(ch)) {
      leaves <- list()
      for (c in ch) {
        sub <- .extract_leaves(c, inverted = inverted)
        if (is.null(sub)) return(NULL)
        leaves <- c(leaves, sub)
      }
      return(leaves)
    }
  }
  NULL
}

# -- dataset + spec picker --------------------------------------------------

.pick_dataset_and_spec <- function(rule) {
  doms    <- rule[["scope"]][["domains"]]
  classes <- rule[["scope"]][["classes"]]

  concrete_doms <- character()
  if (!is.null(doms) && length(doms) > 0L) {
    u <- toupper(as.character(unlist(doms)))
    concrete_doms <- u[nzchar(u) & u != "ALL" & !grepl("^SUPP", u) &
                       nchar(u) >= 2L & nchar(u) <= 8L]
  }

  concrete_cls <- character()
  if (!is.null(classes) && length(classes) > 0L) {
    u <- toupper(as.character(unlist(classes)))
    concrete_cls <- u[nzchar(u) & u != "ALL"]
  }
  class_pick <- if (length(concrete_cls) > 0L) concrete_cls[[1L]] else NA_character_

  ds_name <- NA_character_
  if (length(concrete_doms) > 0L) {
    ds_name <- concrete_doms[[1L]]
  } else if (!is.na(class_pick)) {
    d <- CLASS_TO_DOMAIN[[class_pick]]
    if (!is.null(d)) ds_name <- d
  }
  if (is.na(ds_name)) {
    std <- toupper(rule[["standard"]] %||% "")
    if (grepl("ADAM", std)) ds_name <- "ADSL"
    else if (grepl("SDTM|SEND", std)) ds_name <- "DM"
  }

  spec <- NULL
  if (!is.na(class_pick) && !is.na(ds_name)) {
    spec <- structure(
      list(
        ds_spec = data.frame(
          dataset = ds_name,
          class   = class_pick,
          stringsAsFactors = FALSE
        )
      ),
      class = c("herald_spec", "list")
    )
  }
  list(name = ds_name, class = class_pick, spec = spec)
}

.expand_wildcard <- function(name, domain) {
  if (is.na(domain) || !nzchar(domain)) return(as.character(name))
  vapply(as.character(name), function(nm) {
    if (startsWith(nm, "--")) paste0(domain, substring(nm, 3L)) else nm
  }, character(1L), USE.NAMES = FALSE)
}

# -- per-op seed variants ---------------------------------------------------

.val_first <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NA_character_)
  as.character(unlist(x))[[1L]]
}

.vals_all <- function(x) {
  if (is.null(x) || length(x) == 0L) return(character())
  as.character(unlist(x))
}

.mk <- function(name, v) stats::setNames(list(v), name)

.shift_date <- function(date_str, days) {
  # Accept YYYY-MM-DD; return shifted date string. Any parse error -> NA.
  d <- tryCatch(
    suppressWarnings(as.Date(date_str)),
    error = function(e) NA
  )
  if (length(d) != 1L || is.na(d)) return(NA_character_)
  format(d + as.integer(days))
}

# -- $-prefixed cross-dataset refs (Phase C) --------------------------------
#
# CDISC CORE rules use tokens like "$dm_usubjid" to mean "unique values of
# DM.USUBJID". The engine resolves these at walk time (see R/rules-crossrefs.R).
# For fixture seeding we need to additionally produce the *referenced* dataset
# with controlled values so the positive variant can fire and the negative
# variant can not fire.

# Tokens that are meta / dynamic / spec-driven -- we can't auto-seed these.
SPECIAL_DOLLAR_TOKENS <- c(
  "$list_dataset_names", "$study_domains", "$domain_label",
  "$arm_list", "$allowed_variables",
  "$required_variables", "$expected_variables",
  "$dataset_name", "$domain_lib_ccode",
  "$column_order_from_library", "$arms_in_ta"
)

# Known token aliases we can rewrite to `list(dataset, column)`.
# `$armcd_list` is documented by the engine's build_crossrefs as an alias for
# TA.ARMCD; seeding it is equivalent to seeding `$ta_armcd`.
DOLLAR_ALIASES <- list(
  "$armcd_list" = list(dataset = "TA", column = "ARMCD")
)

#' Parse a `$`-prefixed token into `list(dataset, column)`, or return NULL if
#' the token is special-purpose, aggregate, or doesn't match the
#' `$<2-char-dom>_<col>` / `$usubjids_in_<dom>` conventions.
.parse_dollar_ref <- function(token) {
  if (!is.character(token) || length(token) != 1L) return(NULL)
  if (!startsWith(token, "$")) return(NULL)
  low <- tolower(token)
  if (low %in% SPECIAL_DOLLAR_TOKENS) return(NULL)
  if (!is.null(DOLLAR_ALIASES[[low]])) return(DOLLAR_ALIASES[[low]])
  # Aggregate / nested-query tokens (not yet supported).
  if (grepl("^\\$(max|min|sum|count|avg)_", low)) return(NULL)

  # Alias: $usubjids_in_<dom>
  if (startsWith(low, "$usubjids_in_")) {
    dom <- toupper(substring(low, nchar("$usubjids_in_") + 1L))
    if (!nzchar(dom)) return(NULL)
    return(list(dataset = dom, column = "USUBJID"))
  }
  # Generic `$<word>_in_<dom>` aliases we don't resolve.
  if (grepl("^\\$[a-z]+_in_", low)) return(NULL)

  # Regular pattern: $<dom>_<col>. CDISC domains are 2 chars.
  if (nchar(low) < 5L) return(NULL)
  if (substring(low, 4L, 4L) != "_") return(NULL)
  dom <- toupper(substring(low, 2L, 3L))
  col <- toupper(substring(low, 5L))
  if (!nzchar(dom) || !nzchar(col)) return(NULL)
  list(dataset = dom, column = col)
}

#' Return a {A, B} variant where each side is {main, extras}. Used when a
#' leaf's `value` is a $-ref pointing at a different dataset.
#' Returns NULL for ops we don't know how to seed with a cross-ref value.
.dollar_variant <- function(op, name, ref) {
  ds   <- ref$dataset
  col  <- ref$column

  same   <- "SAME_VAL"
  other  <- "OTHER_001"
  target <- "TARGET_X"

  mk_main <- function(v) stats::setNames(list(v), name)
  mk_ref  <- function(v) stats::setNames(
    list(stats::setNames(list(v), col)), ds
  )

  switch(
    op,
    is_not_contained_by = list(
      A = list(main = mk_main(target), extras = mk_ref(other)),
      B = list(main = mk_main(same),   extras = mk_ref(same))
    ),
    is_contained_by = list(
      A = list(main = mk_main(same),   extras = mk_ref(same)),
      B = list(main = mk_main(target), extras = mk_ref(other))
    ),
    is_not_contained_by_case_insensitive = list(
      A = list(main = mk_main(target),         extras = mk_ref(other)),
      B = list(main = mk_main(tolower(same)),  extras = mk_ref(toupper(same)))
    ),
    is_contained_by_case_insensitive = list(
      A = list(main = mk_main(tolower(same)),  extras = mk_ref(toupper(same))),
      B = list(main = mk_main(target),         extras = mk_ref(other))
    ),
    not_equal_to = list(
      A = list(main = mk_main(target), extras = mk_ref(other)),
      B = list(main = mk_main(same),   extras = mk_ref(same))
    ),
    equal_to = list(
      A = list(main = mk_main(same),   extras = mk_ref(same)),
      B = list(main = mk_main(target), extras = mk_ref(other))
    ),
    equal_to_case_insensitive = list(
      A = list(main = mk_main(tolower(same)), extras = mk_ref(toupper(same))),
      B = list(main = mk_main(target),        extras = mk_ref(other))
    ),
    not_equal_to_case_insensitive = list(
      A = list(main = mk_main(target),        extras = mk_ref(other)),
      B = list(main = mk_main(tolower(same)), extras = mk_ref(toupper(same)))
    ),
    date_greater_than = {
      v <- "2026-01-15"
      list(
        A = list(main = mk_main(.shift_date(v,  1L)), extras = mk_ref(v)),
        B = list(main = mk_main(.shift_date(v, -1L)), extras = mk_ref(v))
      )
    },
    date_less_than = {
      v <- "2026-01-15"
      list(
        A = list(main = mk_main(.shift_date(v, -1L)), extras = mk_ref(v)),
        B = list(main = mk_main(.shift_date(v,  1L)), extras = mk_ref(v))
      )
    },
    date_equal_to = {
      v <- "2026-01-15"
      list(
        A = list(main = mk_main(v),                   extras = mk_ref(v)),
        B = list(main = mk_main(.shift_date(v,  1L)), extras = mk_ref(v))
      )
    },
    date_not_equal_to = {
      v <- "2026-01-15"
      list(
        A = list(main = mk_main(.shift_date(v,  1L)), extras = mk_ref(v)),
        B = list(main = mk_main(v),                   extras = mk_ref(v))
      )
    },
    date_greater_than_or_equal_to = {
      v <- "2026-01-15"
      list(
        A = list(main = mk_main(v),                   extras = mk_ref(v)),
        B = list(main = mk_main(.shift_date(v, -1L)), extras = mk_ref(v))
      )
    },
    date_less_than_or_equal_to = {
      v <- "2026-01-15"
      list(
        A = list(main = mk_main(v),                   extras = mk_ref(v)),
        B = list(main = mk_main(.shift_date(v,  1L)), extras = mk_ref(v))
      )
    },
    NULL
  )
}

# -- per-op seed variants ---------------------------------------------------
# Each case returns either a flat {A = cols, B = cols} (no extras) or the
# richer {A = {main, extras}, B = {main, extras}} shape used by $-ref ops.
# `.normalize_variant` downstream collapses both into the rich shape.

.leaf_variants <- function(op, leaf, domain, main_dataset = NULL) {
  raw_name <- leaf[["name"]]
  if (is.null(raw_name)) return(NULL)
  raw_vec <- as.character(unlist(raw_name))
  if (length(raw_vec) == 0L || !all(nzchar(raw_vec))) return(NULL)
  if (any(startsWith(raw_vec, "$"))) return(NULL)
  name_vec <- .expand_wildcard(raw_vec, domain)
  name <- name_vec[[1L]]  # primary column (used by scalar-name ops)

  val1 <- .val_first(leaf[["value"]])

  # Phase C: detect $-ref leaf values and dispatch to dollar-variant path.
  if (!is.na(val1) && startsWith(val1, "$")) {
    ref <- .parse_dollar_ref(val1)
    if (is.null(ref)) return(NULL)
    main_up <- toupper(as.character(main_dataset %||% ""))
    if (identical(ref$dataset, main_up)) return(NULL)
    return(.dollar_variant(op, name, ref))
  }

  switch(
    op,
    # -- existence ---------------------------------------------------------
    exists       = list(A = .mk(name, "value"),
                        B = list(`_placeholder_` = "x")),
    not_exists   = list(A = list(`_placeholder_` = "x"),
                        B = .mk(name, "value")),
    non_empty    = list(A = .mk(name, "value"), B = .mk(name, "")),
    empty        = list(A = .mk(name, ""), B = .mk(name, "value")),

    # -- equality ----------------------------------------------------------
    equal_to = {
      if (is.na(val1)) return(NULL)
      other <- if (identical(val1, "OTHER")) "ANOTHER" else "OTHER"
      list(A = .mk(name, val1), B = .mk(name, other))
    },
    not_equal_to = {
      if (is.na(val1)) return(NULL)
      other <- if (identical(val1, "OTHER")) "ANOTHER" else "OTHER"
      list(A = .mk(name, other), B = .mk(name, val1))
    },
    equal_to_case_insensitive = {
      if (is.na(val1)) return(NULL)
      list(A = .mk(name, toupper(val1)),
           B = .mk(name, paste0("NO-", val1)))
    },
    not_equal_to_case_insensitive = {
      if (is.na(val1)) return(NULL)
      list(A = .mk(name, paste0("NO-", val1)),
           B = .mk(name, toupper(val1)))
    },

    # -- numeric compare ---------------------------------------------------
    greater_than = {
      n <- suppressWarnings(as.numeric(val1))
      if (is.na(n)) return(NULL)
      list(A = .mk(name, n + 1), B = .mk(name, n - 1))
    },
    less_than = {
      n <- suppressWarnings(as.numeric(val1))
      if (is.na(n)) return(NULL)
      list(A = .mk(name, n - 1), B = .mk(name, n + 1))
    },
    greater_than_or_equal_to = {
      n <- suppressWarnings(as.numeric(val1))
      if (is.na(n)) return(NULL)
      list(A = .mk(name, n), B = .mk(name, n - 1))
    },
    less_than_or_equal_to = {
      n <- suppressWarnings(as.numeric(val1))
      if (is.na(n)) return(NULL)
      list(A = .mk(name, n), B = .mk(name, n + 1))
    },

    # -- date compare ------------------------------------------------------
    date_greater_than = {
      after  <- .shift_date(val1, 1L); before <- .shift_date(val1, -1L)
      if (is.na(after) || is.na(before)) return(NULL)
      list(A = .mk(name, after), B = .mk(name, before))
    },
    date_less_than = {
      after  <- .shift_date(val1, 1L); before <- .shift_date(val1, -1L)
      if (is.na(after) || is.na(before)) return(NULL)
      list(A = .mk(name, before), B = .mk(name, after))
    },
    date_equal_to = {
      after <- .shift_date(val1, 1L)
      if (is.na(after)) return(NULL)
      list(A = .mk(name, val1), B = .mk(name, after))
    },
    date_not_equal_to = {
      after <- .shift_date(val1, 1L)
      if (is.na(after)) return(NULL)
      list(A = .mk(name, after), B = .mk(name, val1))
    },
    date_greater_than_or_equal_to = {
      before <- .shift_date(val1, -1L)
      if (is.na(before)) return(NULL)
      list(A = .mk(name, val1), B = .mk(name, before))
    },
    date_less_than_or_equal_to = {
      after <- .shift_date(val1, 1L)
      if (is.na(after)) return(NULL)
      list(A = .mk(name, val1), B = .mk(name, after))
    },

    # -- string ------------------------------------------------------------
    contains = {
      if (is.na(val1)) return(NULL)
      list(A = .mk(name, paste0("xx", val1, "xx")), B = .mk(name, "no-match"))
    },
    does_not_contain = {
      if (is.na(val1)) return(NULL)
      list(A = .mk(name, "no-match"), B = .mk(name, paste0("xx", val1, "xx")))
    },
    starts_with = {
      if (is.na(val1)) return(NULL)
      list(A = .mk(name, paste0(val1, "Z")), B = .mk(name, paste0("Z", val1)))
    },
    ends_with = {
      if (is.na(val1)) return(NULL)
      list(A = .mk(name, paste0("Z", val1)), B = .mk(name, paste0(val1, "Z")))
    },
    longer_than = {
      n <- suppressWarnings(as.integer(val1))
      if (is.na(n)) return(NULL)
      list(A = .mk(name, strrep("x", n + 2L)),
           B = .mk(name, strrep("x", max(0L, n - 1L))))
    },
    shorter_than = {
      n <- suppressWarnings(as.integer(val1))
      if (is.na(n)) return(NULL)
      list(A = .mk(name, strrep("x", max(0L, n - 1L))),
           B = .mk(name, strrep("x", n + 2L)))
    },
    length_le = {
      n <- suppressWarnings(as.integer(val1))
      if (is.na(n)) return(NULL)
      list(A = .mk(name, strrep("x", max(0L, n - 1L))),
           B = .mk(name, strrep("x", n + 2L)))
    },

    matches_regex     = list(A = .mk(name, "TESTvalue"), B = .mk(name, "!!!")),
    not_matches_regex = list(A = .mk(name, "!!!"), B = .mk(name, "TESTvalue")),

    # -- prefix / suffix ---------------------------------------------------
    prefix_equal_to = {
      if (is.na(val1)) return(NULL)
      list(A = .mk(name, paste0(val1, "ZZZZ")),
           B = .mk(name, paste0("ZZ",  "ZZZZ")))
    },
    prefix_not_equal_to = {
      if (is.na(val1)) return(NULL)
      list(A = .mk(name, paste0("ZZ",  "ZZZZ")),
           B = .mk(name, paste0(val1, "ZZZZ")))
    },
    prefix_matches_regex = list(
      A = .mk(name, "TESTvalueXX"), B = .mk(name, "!!!valueXX")
    ),
    not_prefix_matches_regex = list(
      A = .mk(name, "!!!valueXX"), B = .mk(name, "TESTvalueXX")
    ),
    suffix_matches_regex = list(
      A = .mk(name, "XXvalueTEST"), B = .mk(name, "XXvalue!!!")
    ),
    not_suffix_matches_regex = list(
      A = .mk(name, "XXvalue!!!"), B = .mk(name, "XXvalueTEST")
    ),

    # -- set membership ----------------------------------------------------
    is_contained_by = {
      allowed <- .vals_all(leaf[["value"]])
      if (length(allowed) == 0L) return(NULL)
      list(A = .mk(name, allowed[[1L]]),
           B = .mk(name, paste0("NOT_IN_", allowed[[1L]])))
    },
    is_not_contained_by = {
      allowed <- .vals_all(leaf[["value"]])
      if (length(allowed) == 0L) return(NULL)
      # $-ref values are handled above by .parse_dollar_ref / .dollar_variant.
      list(A = .mk(name, paste0("NOT_IN_", allowed[[1L]])),
           B = .mk(name, allowed[[1L]]))
    },
    is_contained_by_case_insensitive = {
      allowed <- .vals_all(leaf[["value"]])
      if (length(allowed) == 0L) return(NULL)
      list(A = .mk(name, toupper(allowed[[1L]])),
           B = .mk(name, paste0("NOT_IN_", allowed[[1L]])))
    },
    is_not_contained_by_case_insensitive = {
      allowed <- .vals_all(leaf[["value"]])
      if (length(allowed) == 0L) return(NULL)
      list(A = .mk(name, paste0("NOT_IN_", allowed[[1L]])),
           B = .mk(name, toupper(allowed[[1L]])))
    },

    # -- structural (multi-row) -------------------------------------------
    # is_unique_set: TRUE when row's key is unique (count == 1)
    # is_not_unique_set: TRUE when row's key is duplicated
    is_unique_set = {
      key_cols <- name_vec
      A <- stats::setNames(lapply(key_cols, function(c) c("a", "b")), key_cols)
      B <- stats::setNames(lapply(key_cols, function(c) c("a", "a")), key_cols)
      list(A = A, B = B)
    },
    is_not_unique_set = {
      key_cols <- name_vec
      A <- stats::setNames(lapply(key_cols, function(c) c("a", "a")), key_cols)
      B <- stats::setNames(lapply(key_cols, function(c) c("a", "b")), key_cols)
      list(A = A, B = B)
    },

    # relationship: X -> Y should be functional (X determines Y).
    # is_unique_relationship: TRUE when it is functional (all good).
    # is_not_unique_relationship: TRUE when X maps to >1 Y value (violation).
    is_unique_relationship = {
      rel <- leaf[["value"]]
      related <- if (is.list(rel)) rel$related_name else rel
      if (is.null(related) || !nzchar(as.character(related))) return(NULL)
      related <- .expand_wildcard(as.character(related), domain)
      if (related == name) return(NULL)
      A <- stats::setNames(list(c("a","a"), c("1","1")), c(name, related))  # 1:1
      B <- stats::setNames(list(c("a","a"), c("1","2")), c(name, related))  # 1:many
      list(A = A, B = B)
    },
    is_not_unique_relationship = {
      rel <- leaf[["value"]]
      related <- if (is.list(rel)) rel$related_name else rel
      if (is.null(related) || !nzchar(as.character(related))) return(NULL)
      related <- .expand_wildcard(as.character(related), domain)
      if (related == name) return(NULL)
      A <- stats::setNames(list(c("a","a"), c("1","2")), c(name, related))  # 1:many
      B <- stats::setNames(list(c("a","a"), c("1","1")), c(name, related))  # 1:1
      list(A = A, B = B)
    },

    # -- temporal / format -----------------------------------------------
    iso8601 = list(A = .mk(name, "2026-01-15T12:00:00"),
                   B = .mk(name, "not-a-date")),
    is_complete_date   = list(A = .mk(name, "2026-01-15"), B = .mk(name, "2026-01-")),
    is_incomplete_date = list(A = .mk(name, "2026-01-"),   B = .mk(name, "2026-01-15")),
    invalid_date       = list(A = .mk(name, "not-a-date"), B = .mk(name, "2026-01-15")),

    NULL
  )
}

# Merge per-leaf columns into one row-set. For a column touched by multiple
# leaves, prefer the "more specific" value (longer total string length);
# run-to-verify in the main loop filters cases where this heuristic picks
# a value that leaves the rule in the wrong state.
.col_specificity <- function(v) {
  s <- as.character(unlist(v))
  sum(nchar(s[!is.na(s)]), na.rm = TRUE)
}

.merge_cols <- function(leaf_cols) {
  out <- list()
  for (lc in leaf_cols) {
    if (is.null(lc)) return(NULL)
    for (k in names(lc)) {
      if (!is.null(out[[k]])) {
        if (identical(out[[k]], lc[[k]])) next
        if (.col_specificity(lc[[k]]) > .col_specificity(out[[k]])) {
          out[[k]] <- lc[[k]]
        }
      } else {
        out[[k]] <- lc[[k]]
      }
    }
  }
  out
}

# Normalize either a flat `{A = cols, B = cols}` or a rich
# `{A = {main, extras}, B = {main, extras}}` to the rich shape.
.normalize_variant <- function(v) {
  if (is.null(v)) return(NULL)
  norm_side <- function(x) {
    if (is.null(x)) return(NULL)
    if (is.list(x) && !is.null(x$main)) {
      return(list(main = x$main, extras = x$extras))
    }
    list(main = x, extras = NULL)
  }
  list(A = norm_side(v$A), B = norm_side(v$B))
}

# Merge a list of per-leaf `extras` maps (each keyed by referenced dataset
# name) into one `{<DS> = <merged-cols>}` map. Returns NULL on any conflict.
.merge_extras <- function(extras_list) {
  by_ds <- list()
  for (ex in extras_list) {
    if (is.null(ex)) next
    for (d in names(ex)) {
      by_ds[[d]] <- c(by_ds[[d]] %||% list(), list(ex[[d]]))
    }
  }
  out <- list()
  for (d in names(by_ds)) {
    merged <- .merge_cols(by_ds[[d]])
    if (is.null(merged)) return(NULL)
    out[[d]] <- merged
  }
  out
}

#' Run `validate()` for one rule against a named list of column-maps.
#' Returns list(fires, rows) where `rows` are the fired row indices in the
#' MAIN dataset (first entry in `dataset_map`).
.run_rule <- function(rule_id, dataset_map, spec = NULL) {
  files <- lapply(dataset_map, function(cols) {
    as.data.frame(cols, stringsAsFactors = FALSE, check.names = FALSE)
  })
  r <- validate(files = files, spec = spec, rules = rule_id, quiet = TRUE)
  main_name <- names(dataset_map)[[1L]]
  fired <- r$findings[r$findings$status == "fired", , drop = FALSE]
  main_rows <- fired$row[toupper(fired$dataset) == toupper(main_name)]
  main_rows <- main_rows[!is.na(main_rows)]
  list(fires = nrow(fired) > 0L, rows = as.integer(main_rows))
}

# -- fixture I/O ------------------------------------------------------------

.write_fixture <- function(path, rule_id, fix_type, dataset_map,
                           expected, notes, ds_class = NA_character_,
                           main_name = NULL) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  datasets <- lapply(dataset_map, as.list)
  obj <- list(
    rule_id      = rule_id,
    fixture_type = fix_type,
    datasets     = datasets,
    expected     = list(
      fires = expected$fires,
      rows  = if (isTRUE(expected$fires)) as.integer(expected$rows) else integer()
    ),
    notes    = notes,
    authored = SEEDER_VERSION
  )
  if (!is.na(ds_class) && nzchar(ds_class) && !is.null(main_name)) {
    obj$spec <- list(class_map = stats::setNames(list(ds_class), main_name))
  }
  json <- jsonlite::toJSON(obj, auto_unbox = TRUE, pretty = TRUE,
                           null = "null", digits = NA)
  writeLines(json, path, useBytes = TRUE)
}

.fx_paths <- function(authority, rule_id) {
  dir <- file.path(fx_root, tolower(authority), rule_id)
  list(
    dir = dir,
    positive = file.path(dir, "positive.json"),
    negative = file.path(dir, "negative.json")
  )
}

.is_manual <- function(path) {
  if (!file.exists(path)) return(FALSE)
  fx <- tryCatch(jsonlite::read_json(path, simplifyVector = FALSE),
                 error = function(e) NULL)
  if (is.null(fx)) return(FALSE)
  identical(fx$authored, "manual")
}

# -- main loop --------------------------------------------------------------

args  <- commandArgs(trailingOnly = TRUE)
force <- "--force" %in% args

# Track fixture files we write this run so we can garbage-collect stale
# auto-seeded fixtures from previous seeder versions whose rules no longer
# auto-seed (e.g. after an engine correctness fix).
written_paths <- character()

cat_rds <- system.file("rules", "rules.rds", package = "herald")
if (!nzchar(cat_rds)) cat_rds <- file.path("inst", "rules", "rules.rds")
catalog <- readRDS(cat_rds)

n_total   <- nrow(catalog)
n_seeded  <- 0L
n_skipped <- 0L
reasons   <- character()
note_op   <- character()

cat(sprintf("seed-fixtures: scanning %d rules\n", n_total))

for (i in seq_len(n_total)) {
  rule <- as.list(catalog[i, , drop = FALSE])
  rule$scope      <- rule$scope[[1L]]
  rule$check_tree <- rule$check_tree[[1L]]
  rule_id <- rule$id

  leaves_info <- .extract_leaves(rule$check_tree)
  if (is.null(leaves_info) || length(leaves_info) == 0L) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "unsupported-tree-shape")
    next
  }

  ops <- vapply(leaves_info, function(l) as.character(l$leaf$operator %||% ""),
                character(1))
  if (!all(ops %in% WHITELIST_OPS)) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "op-not-whitelisted")
    note_op <- c(note_op, ops[!ops %in% WHITELIST_OPS])
    next
  }

  ds_info <- .pick_dataset_and_spec(rule)
  if (is.na(ds_info$name)) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "no-dataset-name")
    next
  }

  # When the fallback main dataset collides with a $-ref target (e.g. a rule
  # scoped to ALL domains that references $dm_usubjid), swap to a non-
  # conflicting domain. Only do this when the rule has no explicit scope --
  # an explicit scope must be honoured.
  dollar_targets <- character()
  for (lf in leaves_info) {
    v1 <- .val_first(lf$leaf$value)
    if (!is.na(v1) && startsWith(v1, "$")) {
      ref <- .parse_dollar_ref(v1)
      if (!is.null(ref)) dollar_targets <- c(dollar_targets, ref$dataset)
    }
  }
  if (length(dollar_targets) > 0L &&
      toupper(ds_info$name) %in% toupper(dollar_targets)) {
    scope_doms <- rule$scope$domains
    explicit_scope <- length(scope_doms) > 0L &&
      any(nzchar(as.character(unlist(scope_doms))) &
          toupper(as.character(unlist(scope_doms))) != "ALL")
    if (!explicit_scope) {
      alt_candidates <- c("AE", "DS", "EX", "LB", "CM", "VS")
      alt <- alt_candidates[!alt_candidates %in% toupper(dollar_targets)]
      if (length(alt) > 0L) {
        ds_info$name  <- alt[[1L]]
        ds_info$class <- NA_character_
        ds_info$spec  <- NULL
      }
    }
  }

  is_adam <- grepl("^AD[A-Z]", ds_info$name)
  wildcard_domain <- if (is_adam) NA_character_ else ds_info$name

  variants_A <- vector("list", length(leaves_info))
  variants_B <- vector("list", length(leaves_info))
  seed_fail <- FALSE
  for (j in seq_along(leaves_info)) {
    v <- .leaf_variants(ops[[j]], leaves_info[[j]]$leaf,
                        wildcard_domain, main_dataset = ds_info$name)
    if (is.null(v)) { seed_fail <- TRUE; break }
    v <- .normalize_variant(v)
    # `not`-wrapped leaves: swap A <-> B so positive/negative semantics line
    # up with the outer rule.
    if (isTRUE(leaves_info[[j]]$inverted)) {
      variants_A[[j]] <- v$B
      variants_B[[j]] <- v$A
    } else {
      variants_A[[j]] <- v$A
      variants_B[[j]] <- v$B
    }
  }
  if (seed_fail) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "leaf-not-seedable")
    next
  }

  main_A_cols <- lapply(variants_A, function(v) v$main)
  main_B_cols <- lapply(variants_B, function(v) v$main)
  cols_pos <- .merge_cols(main_A_cols)
  cols_neg <- .merge_cols(main_B_cols)
  if (is.null(cols_pos) || is.null(cols_neg)) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "leaf-col-conflict")
    next
  }

  extras_pos <- .merge_extras(lapply(variants_A, function(v) v$extras))
  extras_neg <- .merge_extras(lapply(variants_B, function(v) v$extras))
  if (is.null(extras_pos) || is.null(extras_neg)) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "leaf-extras-conflict")
    next
  }

  paths <- .fx_paths(rule$authority %||% "unknown", rule_id)
  if (!isTRUE(force) &&
      (.is_manual(paths$positive) || .is_manual(paths$negative))) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "manual-fixture-present")
    next
  }

  dataset_map_pos <- c(stats::setNames(list(cols_pos), ds_info$name), extras_pos)
  dataset_map_neg <- c(stats::setNames(list(cols_neg), ds_info$name), extras_neg)

  out_pos <- .run_rule(rule_id, dataset_map_pos, spec = ds_info$spec)
  out_neg <- .run_rule(rule_id, dataset_map_neg, spec = ds_info$spec)

  if (!isTRUE(out_pos$fires) || isTRUE(out_neg$fires)) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons,
      if (!out_pos$fires && !out_neg$fires) "neither-fires"
      else if (out_pos$fires && out_neg$fires) "both-fire"
      else "positive-no-fire")
    next
  }

  any_inverted <- any(vapply(leaves_info, function(l) isTRUE(l$inverted), logical(1)))
  has_extras <- length(extras_pos) > 0L
  extras_tag <- if (has_extras) sprintf(" (+%d ref ds)", length(extras_pos)) else ""
  notes_pos <- sprintf("auto-seeded%s%s; %d leaf op(s): %s",
                       if (any_inverted) " (w/ not-wrapper)" else "",
                       extras_tag,
                       length(ops), paste(ops, collapse = ","))
  notes_neg <- sprintf("auto-seeded%s%s; %d leaf op(s): %s (should not fire)",
                       if (any_inverted) " (w/ not-wrapper)" else "",
                       extras_tag,
                       length(ops), paste(ops, collapse = ","))

  .write_fixture(paths$positive, rule_id, "positive", dataset_map_pos,
                 out_pos, notes_pos, ds_class = ds_info$class,
                 main_name = ds_info$name)
  .write_fixture(paths$negative, rule_id, "negative", dataset_map_neg,
                 out_neg, notes_neg, ds_class = ds_info$class,
                 main_name = ds_info$name)
  written_paths <- c(written_paths, paths$positive, paths$negative)
  n_seeded <- n_seeded + 1L
}

# Prune stale auto-seed fixtures: any auto-seeded file we did NOT write this
# run (meaning: its rule no longer meets the seeder's criteria) is deleted.
# Manual fixtures are always preserved.
n_pruned <- 0L
existing <- list.files(fx_root, pattern = "\\.(json)$",
                       recursive = TRUE, full.names = TRUE)
for (p in setdiff(existing, written_paths)) {
  if (.is_manual(p)) next
  file.remove(p)
  n_pruned <- n_pruned + 1L
}
# Sweep now-empty rule directories.
for (d in list.files(fx_root, recursive = TRUE, include.dirs = TRUE,
                     full.names = TRUE)) {
  if (dir.exists(d) && length(list.files(d)) == 0L) {
    unlink(d, recursive = TRUE)
  }
}
if (n_pruned > 0L) {
  cat(sprintf("seed-fixtures: pruned %d stale auto-seeded fixture file(s)\n",
              n_pruned))
}

cat(sprintf("seed-fixtures: seeded %d rules, skipped %d\n",
            n_seeded, n_skipped))
top_reasons <- sort(table(reasons), decreasing = TRUE)
cat("top skip reasons:\n")
for (i in seq_len(min(10L, length(top_reasons)))) {
  cat(sprintf("  %-26s %5d\n", names(top_reasons)[i], top_reasons[[i]]))
}
if (length(note_op) > 0L) {
  top_ops <- sort(table(note_op), decreasing = TRUE)
  cat("top non-whitelisted ops:\n")
  for (i in seq_len(min(10L, length(top_ops)))) {
    cat(sprintf("  %-28s %5d\n", names(top_ops)[i], top_ops[[i]]))
  }
}
