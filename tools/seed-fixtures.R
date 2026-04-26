# -----------------------------------------------------------------------------
# tools/seed-fixtures.R -- auto-seed golden fixtures for executable rules
# -----------------------------------------------------------------------------
# Run from the package root:
#
#   Rscript tools/seed-fixtures.R [--force]
#
# Writes tools/rule-authoring/fixtures/<authority>/<rule_id>/{positive,negative}.json
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

# Workaround for an engine quirk: when a rule's check_tree carries an
# empty `expand` slot (`expand: ""` in the YAML), .expand_indexed leaves
# the slot in the tree, which then leaks into the operator's args via
# .eval_leaf and breaks ops that don't accept an `expand` argument
# (e.g. base_not_equal_abl_row). Stripping the empty expand here makes
# the seeder fire those rules correctly without changing engine source.
local({
  if (!exists(".expand_indexed", envir = asNamespace("herald"),
              inherits = FALSE)) return(invisible(NULL))
  old_fn <- herald:::.expand_indexed
  patched <- function(check_tree, data) {
    if (is.list(check_tree) && !is.null(check_tree$expand)) {
      raw_expand <- as.character(unlist(check_tree$expand))
      raw_expand <- raw_expand[nzchar(raw_expand)]
      if (length(raw_expand) == 0L) check_tree$expand <- NULL
    }
    old_fn(check_tree, data)
  }
  utils::assignInNamespace(".expand_indexed", patched, ns = "herald")
})

# Workaround: .collect_indexed_names_any walks node$name + combinator
# children + node$not, but it does NOT walk into structured args like
# `value$related_name` (used by is_unique_relationship /
# is_not_unique_relationship). For multi-placeholder rules where one
# placeholder lives only inside value$related_name, the engine never
# discovers a tuple that resolves it -- so columns stay templated
# ("TR01PGy" with literal 'y') and the op returns NA. Extending the
# collection to also visit node$value$related_name yields the right
# tuples and lets the seeder fire those rules.
local({
  if (!exists(".collect_indexed_names_any", envir = asNamespace("herald"),
              inherits = FALSE)) return(invisible(NULL))
  old_fn <- herald:::.collect_indexed_names_any
  patched <- function(node, phs, acc = character()) {
    acc <- old_fn(node, phs, acc)
    if (is.list(node) && !is.null(node$value)) {
      v <- node$value
      if (is.list(v) && !is.null(v$related_name)) {
        rn <- as.character(v$related_name)
        if (length(rn) == 1L && any(vapply(phs, function(p) {
          grepl(p, rn, fixed = TRUE)
        }, logical(1L)))) {
          acc <- c(acc, rn)
        }
      }
    }
    unique(acc)
  }
  utils::assignInNamespace(".collect_indexed_names_any", patched, ns = "herald")
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
  "prefix_is_not_contained_by", "suffix_is_not_contained_by",
  # set membership
  "is_contained_by", "is_not_contained_by",
  "is_contained_by_case_insensitive", "is_not_contained_by_case_insensitive",
  "value_in_codelist", "value_in_dictionary", "value_in_srs_table",
  # structural (multi-row)
  "is_unique_set", "is_not_unique_set",
  "is_unique_relationship", "is_not_unique_relationship",
  "differs_by_key", "matches_by_key",
  "less_than_by_key", "less_than_or_equal_by_key",
  "greater_than_by_key", "greater_than_or_equal_by_key",
  "missing_in_ref", "subject_has_matching_row",
  "is_inconsistent_across_dataset",
  "max_n_records_per_group_matching",
  "any_index_missing_ref_var",
  # temporal / format
  "iso8601", "is_complete_date", "is_incomplete_date",
  "invalid_date", "value_not_iso8601", "invalid_duration",
  # token/arithmetic
  "not_contains_all", "is_not_diff", "is_not_pct_diff",
  # metadata / structural
  "label_by_suffix_missing", "var_by_suffix_not_numeric",
  "dataset_name_length_not_in_range",
  # ADaM baseline
  "no_baseline_record", "base_not_equal_abl_row"
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
  "RELATIONSHIP"    = "RELREC",
  "SUBJECT LEVEL ANALYSIS DATASET" = "ADSL",
  "BASIC DATA STRUCTURE" = "ADVS",
  "OCCURRENCE DATA STRUCTURE" = "ADAE",
  "TIME-TO-EVENT" = "ADTTE",
  "ADVERSE EVENT" = "ADAE",
  "ADSL" = "ADSL",
  "BDS" = "ADVS",
  "OCCDS" = "ADAE",
  "TTE" = "ADTTE"
)

fx_root <- file.path("tools", "rule-authoring", "fixtures")
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
  datasets <- rule[["scope"]][["datasets"]]
  doms    <- rule[["scope"]][["domains"]]
  classes <- rule[["scope"]][["classes"]]

  concrete_datasets <- character()
  if (!is.null(datasets) && length(datasets) > 0L) {
    u <- as.character(unlist(datasets))
    concrete_datasets <- u[nzchar(u) & u != "ALL"]
  }

  concrete_doms <- character()
  if (!is.null(doms) && length(doms) > 0L) {
    u <- toupper(as.character(unlist(doms)))
    # Map SUPP-- wildcard -> a representative SUPPAE dataset.
    u <- vapply(u, function(d) {
      if (identical(d, "SUPP--")) return("SUPPAE")
      d
    }, character(1L))
    concrete_doms <- u[nzchar(u) & u != "ALL" &
                       !(grepl("^SUPP", u) & u != "SUPPAE") &
                       nchar(u) >= 2L & nchar(u) <= 8L]
  }

  concrete_cls <- character()
  if (!is.null(classes) && length(classes) > 0L) {
    u <- toupper(as.character(unlist(classes)))
    concrete_cls <- u[nzchar(u) & u != "ALL"]
  }
  class_pick <- if (length(concrete_cls) > 0L) concrete_cls[[1L]] else NA_character_

  ds_name <- NA_character_
  if (length(concrete_datasets) > 0L) {
    ds_name <- concrete_datasets[[1L]]
  } else if (length(concrete_doms) > 0L) {
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

.seed_expand_tuple <- function(expand) {
  if (is.null(expand)) return(list())
  raw <- as.character(unlist(expand))
  if (length(raw) == 1L && grepl("[,;| ]", raw)) {
    raw <- trimws(strsplit(raw, "[,;| ]+", perl = TRUE)[[1L]])
  }
  raw <- raw[nzchar(raw)]
  vals <- list(stem = "PARAM", xx = "01", zz = "01", y = "1", w = "1")
  vals[intersect(raw, names(vals))]
}

.substitute_seed_tuple <- function(x, tuple) {
  if (length(tuple) == 0L) return(x)
  if (is.character(x)) {
    out <- x
    # Longer placeholders first: `stem` before `y`, `xx` before `x`.
    for (ph in names(tuple)[order(-nchar(names(tuple)))]) {
      out <- gsub(ph, tuple[[ph]], out, fixed = TRUE)
    }
    return(out)
  }
  if (is.list(x)) {
    return(lapply(x, .substitute_seed_tuple, tuple = tuple))
  }
  x
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

.dummy_dictionaries <- function() {
  fields <- c("pt", "pt_code", "llt", "llt_code", "hlt", "hlt_code",
              "hlgt", "hlgt_code", "soc", "soc_code", "drug", "code",
              "preferred_name", "unii", "synonyms")
  make <- function(name) {
    tbl <- as.data.frame(stats::setNames(rep(list("VALID"), length(fields)), fields),
                         stringsAsFactors = FALSE)
    custom_provider(tbl, name = name, fields = fields)
  }
  list(
    meddra  = make("meddra"),
    whodrug = make("whodrug"),
    srs     = make("srs"),
    loinc   = make("loinc"),
    snomed  = make("snomed")
  )
}

#' Return a literal value that satisfies (or fails) a regex.
#'
#' The CDISC corpus uses a small set of patterns: alphabetic prefixes
#' (`^[A-Z]+$`), 2-3 char domains (`^[A-Z]{2,3}$`), digit strings, anchored
#' integer matches (`^-?[0-9]+$`), and a few permissive `.*[a-z].*` style
#' regexes. We try a fixed pool of candidates against the regex and pick
#' the first that matches (or doesn't, depending on `want_match`).
#'
#' Returns NULL when no candidate satisfies the constraint -- the caller
#' falls back to skipping the leaf.
.sample_regex_match <- function(rx, want_match = TRUE) {
  if (is.null(rx) || is.na(rx) || !nzchar(rx)) return(NULL)
  candidates <- c(
    "AE", "DM", "LB", "VS", "ADAE", "ADSL",
    "TESTvalue", "test", "value123", "Heart Rate", "BMI",
    "1", "12", "123", "1234", "12345",
    "0", "-1", "-12",
    "X", "XX", "XXX",
    "abc", "ABC", "abcdef",
    "VAR_NAME", "VAR1", "VAR_1",
    "!!!", "%%%", "@@@",
    "  ", "", "?",
    "Y", "N", "U",
    "a", "Z",
    "Q1", "ABC123",
    "1.0", "1.5", "0.0",
    "AS01", "VAR01"
  )
  for (cand in candidates) {
    matched <- tryCatch(
      grepl(rx, cand, perl = TRUE),
      error = function(e) NA
    )
    if (is.na(matched)) next
    if (isTRUE(matched) == isTRUE(want_match)) return(cand)
  }
  NULL
}

#' Heuristic: does `val` look like a CDISC column name (uppercase letters
#' optionally followed by digits / underscores), rather than a literal
#' string value? Used by date / numeric ops to detect column-ref values
#' in rules that omit `value_is_literal: FALSE`.
.is_likely_col_ref <- function(val) {
  if (is.null(val) || is.na(val) || !nzchar(val)) return(FALSE)
  if (length(val) != 1L) return(FALSE)
  v <- as.character(val)
  if (startsWith(v, "$")) return(FALSE)
  if (grepl("\\.", v))    return(FALSE)
  # Pure digits / dates / mixed punctuation are literals.
  if (grepl("^-?[0-9.]+$", v)) return(FALSE)
  # SDTM / ADaM column names: optional `--` wildcard, all caps, 2-12 chars.
  grepl("^(--)?[A-Z][A-Z0-9_]{1,11}$", v)
}

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

#' Parse a `<DS>.<COL>` token (e.g. "DM.USUBJID") into `list(dataset, column)`.
#' Returns NULL when the token is not a literal cross-dataset column reference.
.parse_dotted_ref <- function(token) {
  if (!is.character(token) || length(token) != 1L) return(NULL)
  if (!nzchar(token) || !grepl("\\.", token)) return(NULL)
  if (startsWith(token, "$")) return(NULL)
  parts <- strsplit(token, ".", fixed = TRUE)[[1L]]
  if (length(parts) != 2L) return(NULL)
  dom <- toupper(parts[[1L]])
  col <- toupper(parts[[2L]])
  # Domain must be alphanumeric, 2-8 chars; column likewise.
  if (!grepl("^[A-Z][A-Z0-9]{1,7}$", dom)) return(NULL)
  if (!grepl("^[A-Z][A-Z0-9_]*$", col))    return(NULL)
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

# Build A/B variants for `value_is_literal: FALSE` leaves where the value
# refers to another column in the same dataset. Both columns live in the
# main dataset; A side fires the leaf, B side does not.
.cross_col_variant <- function(op, name, other_col) {
  mk2 <- function(a, b) stats::setNames(list(a, b), c(name, other_col))
  switch(
    op,
    equal_to = list(
      A = mk2("SAME", "SAME"),
      B = mk2("DIFF", "SAME")
    ),
    not_equal_to = list(
      A = mk2("DIFF", "SAME"),
      B = mk2("SAME", "SAME")
    ),
    equal_to_case_insensitive = list(
      A = mk2("same", "SAME"),
      B = mk2("diff", "SAME")
    ),
    not_equal_to_case_insensitive = list(
      A = mk2("diff", "SAME"),
      B = mk2("same", "SAME")
    ),
    greater_than = list(
      A = mk2(2, 1),
      B = mk2(1, 2)
    ),
    less_than = list(
      A = mk2(1, 2),
      B = mk2(2, 1)
    ),
    greater_than_or_equal_to = list(
      A = mk2(2, 2),
      B = mk2(1, 2)
    ),
    less_than_or_equal_to = list(
      A = mk2(1, 1),
      B = mk2(2, 1)
    ),
    date_greater_than = list(
      A = mk2("2026-01-16", "2026-01-15"),
      B = mk2("2026-01-14", "2026-01-15")
    ),
    date_less_than = list(
      A = mk2("2026-01-14", "2026-01-15"),
      B = mk2("2026-01-16", "2026-01-15")
    ),
    date_greater_than_or_equal_to = list(
      A = mk2("2026-01-15", "2026-01-15"),
      B = mk2("2026-01-14", "2026-01-15")
    ),
    date_less_than_or_equal_to = list(
      A = mk2("2026-01-15", "2026-01-15"),
      B = mk2("2026-01-16", "2026-01-15")
    ),
    NULL
  )
}

# -- per-op seed variants ---------------------------------------------------
# Each case returns either a flat {A = cols, B = cols} (no extras) or the
# richer {A = {main, extras}, B = {main, extras}} shape used by $-ref ops.
# `.normalize_variant` downstream collapses both into the rich shape.

# Variants for ops that don't use a `name` arg. Each derives its target
# column(s) from suffix / b_var+a_var / etc.
.no_name_variant <- function(op, leaf, domain) {
  switch(
    op,
    label_by_suffix_missing = {
      suffix <- as.character(leaf[["suffix"]] %||% "")
      phrase <- as.character(leaf[["value"]] %||% "")
      if (!nzchar(suffix) || !nzchar(phrase)) return(NULL)
      good_label <- paste0("Some ", phrase, " value")
      bad_label  <- "Mismatched Label"
      col <- paste0("X", toupper(suffix))
      mk_col <- function(label) {
        v <- "v1"
        attr(v, "label") <- label
        stats::setNames(list(v), col)
      }
      list(A = mk_col(bad_label), B = mk_col(good_label))
    },
    dataset_name_length_not_in_range = NULL,
    base_not_equal_abl_row = {
      b_var   <- as.character(leaf[["b_var"]] %||% "")
      a_var   <- as.character(leaf[["a_var"]] %||% "")
      abl_col <- as.character(leaf[["abl_col"]] %||% "ABLFL")
      abl_value <- as.character(leaf[["abl_value"]] %||% "Y")
      group_by  <- as.character(unlist(leaf[["group_by"]] %||% character(0)))
      gate <- as.character(leaf[["basetype_gate"]] %||% "any")
      if (!nzchar(b_var) || !nzchar(a_var) || length(group_by) == 0L) return(NULL)
      group_by <- .expand_wildcard(group_by, domain)
      A <- list()
      B <- list()
      A[[b_var]] <- c("X", "Y")
      A[[a_var]] <- c("X", "Y")
      A[[abl_col]] <- c(abl_value, "N")
      B[[b_var]] <- c("Y", "Y")
      B[[a_var]] <- c("Y", "Y")
      B[[abl_col]] <- c(abl_value, "N")
      for (g in group_by) {
        if (g == b_var || g == a_var || g == abl_col) next
        A[[g]] <- c("G1", "G1")
        B[[g]] <- c("G1", "G1")
      }
      if (gate == "populated") {
        A[["BASETYPE"]] <- c("BTYPE", "BTYPE")
        B[["BASETYPE"]] <- c("BTYPE", "BTYPE")
      }
      list(A = A, B = B)
    },
    no_baseline_record = {
      nm <- as.character(leaf[["name"]] %||% "")
      flag_var <- as.character(leaf[["flag_var"]] %||% "")
      flag_value <- as.character(leaf[["flag_value"]] %||% "")
      group_by <- as.character(unlist(leaf[["group_by"]] %||% character(0)))
      if (!nzchar(nm) || !nzchar(flag_var) || !nzchar(flag_value)) return(NULL)
      if (length(group_by) == 0L) return(NULL)
      nm <- .expand_wildcard(nm, domain)[[1L]]
      group_by <- .expand_wildcard(group_by, domain)
      A <- list()
      B <- list()
      A[[nm]] <- c("v1", "v1")
      A[[flag_var]] <- c("N", "N")
      B[[nm]] <- c("v1", "v1")
      B[[flag_var]] <- c(flag_value, "N")
      for (g in group_by) {
        if (g == nm || g == flag_var) next
        A[[g]] <- c("G1", "G1")
        B[[g]] <- c("G1", "G1")
      }
      list(A = A, B = B)
    },
    NULL
  )
}

.leaf_variants <- function(op, leaf, domain, main_dataset = NULL) {
  # Some ops do not use a `name` field. They derive their target column(s)
  # from other args (suffix / b_var+a_var / dataset_name). Handle them up
  # front so we don't reject them on the missing-name guard below.
  if (op %in% c("label_by_suffix_missing",
                "dataset_name_length_not_in_range",
                "base_not_equal_abl_row",
                "no_baseline_record")) {
    return(.no_name_variant(op, leaf, domain))
  }

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

  # `value_is_literal: FALSE` -- the value is a column name in the current
  # dataset, not a literal. Seed both columns so the leaf has somewhere to
  # compare against. Only supported for simple compare ops.
  vis_lit <- leaf[["value_is_literal"]]
  if (!is.null(vis_lit) && isFALSE(as.logical(vis_lit))) {
    other_col <- .expand_wildcard(val1, domain)[[1L]]
    if (!is.na(other_col) && nzchar(other_col) && other_col != name) {
      return(.cross_col_variant(op, name, other_col))
    }
    return(NULL)
  }

  # Dotted cross-dataset reference: value like "DM.USUBJID" means the column
  # USUBJID in the DM dataset. Same semantics as `$dm_usubjid`. The validator
  # treats some ops differently (matches_by_key vs is_not_contained_by) so
  # we only auto-route ops that .dollar_variant knows how to seed.
  if (!is.na(val1)) {
    dref <- .parse_dotted_ref(val1)
    if (!is.null(dref)) {
      main_up <- toupper(as.character(main_dataset %||% ""))
      if (!identical(dref$dataset, main_up)) {
        v <- .dollar_variant(op, name, dref)
        if (!is.null(v)) return(v)
      }
    }
  }

  # Cross-dataset column presence: exists("AE.AESTDY") means column AESTDY
  # exists in dataset AE, not a literal column named "AE.AESTDY" in the main
  # dataset.
  if (identical(op, "exists") &&
      grepl("^[A-Z][A-Z0-9]{1,3}\\.[A-Z][A-Z0-9_]*$", name)) {
    parts <- strsplit(name, ".", fixed = TRUE)[[1L]]
    ref_ds <- parts[[1L]]
    ref_col <- parts[[2L]]
    return(list(
      A = list(main = list(`_placeholder_` = "x"),
               extras = stats::setNames(list(.mk(ref_col, "value")), ref_ds)),
      B = list(main = list(`_placeholder_` = "x"),
               extras = stats::setNames(list(list(`_placeholder_` = "x")), ref_ds))
    ))
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
    # Two flavours: (1) literal date string in `value`; (2) column name
    # naming another column to compare against. The engine auto-detects
    # column refs via `v %in% names(data)`. The seeder handles both.
    date_greater_than = {
      if (.is_likely_col_ref(val1)) {
        v <- .cross_col_variant("date_greater_than", name, val1)
        if (!is.null(v)) return(v)
      }
      after  <- .shift_date(val1, 1L); before <- .shift_date(val1, -1L)
      if (is.na(after) || is.na(before)) return(NULL)
      list(A = .mk(name, after), B = .mk(name, before))
    },
    date_less_than = {
      if (.is_likely_col_ref(val1)) {
        v <- .cross_col_variant("date_less_than", name, val1)
        if (!is.null(v)) return(v)
      }
      after  <- .shift_date(val1, 1L); before <- .shift_date(val1, -1L)
      if (is.na(after) || is.na(before)) return(NULL)
      list(A = .mk(name, before), B = .mk(name, after))
    },
    date_equal_to = {
      if (.is_likely_col_ref(val1)) return(NULL)
      after <- .shift_date(val1, 1L)
      if (is.na(after)) return(NULL)
      list(A = .mk(name, val1), B = .mk(name, after))
    },
    date_not_equal_to = {
      if (.is_likely_col_ref(val1)) return(NULL)
      after <- .shift_date(val1, 1L)
      if (is.na(after)) return(NULL)
      list(A = .mk(name, after), B = .mk(name, val1))
    },
    date_greater_than_or_equal_to = {
      if (.is_likely_col_ref(val1)) {
        v <- .cross_col_variant("date_greater_than_or_equal_to", name, val1)
        if (!is.null(v)) return(v)
      }
      before <- .shift_date(val1, -1L)
      if (is.na(before)) return(NULL)
      list(A = .mk(name, val1), B = .mk(name, before))
    },
    date_less_than_or_equal_to = {
      if (.is_likely_col_ref(val1)) {
        v <- .cross_col_variant("date_less_than_or_equal_to", name, val1)
        if (!is.null(v)) return(v)
      }
      after <- .shift_date(val1, 1L)
      if (is.na(after)) return(NULL)
      list(A = .mk(name, val1), B = .mk(name, after))
    },

    # -- string ------------------------------------------------------------
    contains = {
      if (is.na(val1)) return(NULL)
      # Negative variant must NOT contain val1 -- "no-match" itself contains
      # "-" or "match" sub-strings of common values, so use a sterile filler.
      neg <- paste0("Z", strrep("Q", 6L), "Z")
      list(A = .mk(name, paste0("xx", val1, "xx")), B = .mk(name, neg))
    },
    does_not_contain = {
      if (is.na(val1)) return(NULL)
      neg <- paste0("Z", strrep("Q", 6L), "Z")
      list(A = .mk(name, neg), B = .mk(name, paste0("xx", val1, "xx")))
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

    matches_regex     = {
      rx <- as.character(val1)
      pos_val <- .sample_regex_match(rx, want_match = TRUE)
      neg_val <- .sample_regex_match(rx, want_match = FALSE)
      if (is.null(pos_val) || is.null(neg_val)) return(NULL)
      list(A = .mk(name, pos_val), B = .mk(name, neg_val))
    },
    not_matches_regex = {
      rx <- as.character(val1)
      # Positive (fires when value does NOT match): pick a non-matching value.
      neg_val <- .sample_regex_match(rx, want_match = FALSE)
      pos_val <- .sample_regex_match(rx, want_match = TRUE)
      if (is.null(pos_val) || is.null(neg_val)) return(NULL)
      list(A = .mk(name, neg_val), B = .mk(name, pos_val))
    },

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
    value_in_codelist = {
      codelist <- as.character(leaf[["codelist"]] %||% "")
      package  <- tolower(as.character(leaf[["package"]] %||% "sdtm"))
      if (!nzchar(codelist)) return(NULL)
      if (!package %in% c("sdtm", "adam")) package <- "sdtm"
      ct <- tryCatch(load_ct(package), error = function(e) NULL)
      if (is.null(ct)) return(NULL)
      entry <- .lookup_codelist(ct, codelist)
      if (is.null(entry) || is.null(entry$terms$submissionValue)) return(NULL)
      allowed <- as.character(entry$terms$submissionValue)
      allowed <- allowed[!is.na(allowed) & nzchar(allowed)]
      if (length(allowed) == 0L) return(NULL)
      # op_value_in_codelist fires when value is NOT in CT.
      list(A = .mk(name, paste0("NOT_IN_", allowed[[1L]])),
           B = .mk(name, allowed[[1L]]))
    },
    value_in_dictionary = {
      # op_value_in_dictionary fires when a non-empty value is not found in
      # the named provider. .run_rule supplies deterministic dummy providers
      # whose every field contains "VALID".
      list(A = .mk(name, "INVALID"), B = .mk(name, "VALID"))
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
      group_by <- if (is.list(rel)) as.character(unlist(rel$group_by %||% character(0))) else character(0)
      if (is.null(related) || !nzchar(as.character(related))) return(NULL)
      related <- .expand_wildcard(as.character(related), domain)
      if (related == name) return(NULL)
      group_by <- .expand_wildcard(group_by, domain)
      A <- stats::setNames(list(c("a","a"), c("1","1")), c(name, related))  # 1:1
      B <- stats::setNames(list(c("a","a"), c("1","2")), c(name, related))  # 1:many
      for (g in group_by) {
        A[[g]] <- c("G1", "G1")
        B[[g]] <- c("G1", "G1")
      }
      list(A = A, B = B)
    },
    is_not_unique_relationship = {
      rel <- leaf[["value"]]
      related <- if (is.list(rel)) rel$related_name else rel
      group_by <- if (is.list(rel)) as.character(unlist(rel$group_by %||% character(0))) else character(0)
      if (is.null(related) || !nzchar(as.character(related))) return(NULL)
      related <- .expand_wildcard(as.character(related), domain)
      if (related == name) return(NULL)
      group_by <- .expand_wildcard(group_by, domain)
      A <- stats::setNames(list(c("a","a"), c("1","2")), c(name, related))  # 1:many
      B <- stats::setNames(list(c("a","a"), c("1","1")), c(name, related))  # 1:1
      for (g in group_by) {
        A[[g]] <- c("G1", "G1")
        B[[g]] <- c("G1", "G1")
      }
      list(A = A, B = B)
    },

    differs_by_key = {
      ref_ds  <- as.character(leaf$reference_dataset %||% "")
      ref_col <- as.character(leaf$reference_column %||% "")
      if (!nzchar(ref_ds) || !nzchar(ref_col)) return(NULL)
      key <- as.character(unlist(leaf$key %||% name))
      ref_key <- as.character(unlist(leaf$reference_key %||% key))
      if (length(key) != 1L || length(ref_key) != 1L) return(NULL)
      list(
        A = list(main = c(.mk(name, "DIFF"), .mk(key, "K1")),
                 extras = stats::setNames(list(c(.mk(ref_col, "SAME"), .mk(ref_key, "K1"))), ref_ds)),
        B = list(main = c(.mk(name, "SAME"), .mk(key, "K1")),
                 extras = stats::setNames(list(c(.mk(ref_col, "SAME"), .mk(ref_key, "K1"))), ref_ds))
      )
    },
    matches_by_key = {
      ref_ds  <- as.character(leaf$reference_dataset %||% "")
      ref_col <- as.character(leaf$reference_column %||% "")
      if (!nzchar(ref_ds) || !nzchar(ref_col)) return(NULL)
      key <- as.character(unlist(leaf$key %||% name))
      ref_key <- as.character(unlist(leaf$reference_key %||% key))
      if (length(key) != 1L || length(ref_key) != 1L) return(NULL)
      list(
        A = list(main = c(.mk(name, "SAME"), .mk(key, "K1")),
                 extras = stats::setNames(list(c(.mk(ref_col, "SAME"), .mk(ref_key, "K1"))), ref_ds)),
        B = list(main = c(.mk(name, "DIFF"), .mk(key, "K1")),
                 extras = stats::setNames(list(c(.mk(ref_col, "SAME"), .mk(ref_key, "K1"))), ref_ds))
      )
    },
    less_than_by_key = {
      ref_ds <- as.character(leaf$reference_dataset %||% ""); ref_col <- as.character(leaf$reference_column %||% "")
      if (!nzchar(ref_ds) || !nzchar(ref_col)) return(NULL)
      key <- as.character(unlist(leaf$key %||% "USUBJID")); ref_key <- as.character(unlist(leaf$reference_key %||% key))
      if (length(key) != 1L || length(ref_key) != 1L) return(NULL)
      list(A = list(main = c(.mk(name, 1), .mk(key, "K1")), extras = stats::setNames(list(c(.mk(ref_col, 2), .mk(ref_key, "K1"))), ref_ds)),
           B = list(main = c(.mk(name, 3), .mk(key, "K1")), extras = stats::setNames(list(c(.mk(ref_col, 2), .mk(ref_key, "K1"))), ref_ds)))
    },
    less_than_or_equal_by_key = {
      ref_ds <- as.character(leaf$reference_dataset %||% ""); ref_col <- as.character(leaf$reference_column %||% "")
      if (!nzchar(ref_ds) || !nzchar(ref_col)) return(NULL)
      key <- as.character(unlist(leaf$key %||% "USUBJID")); ref_key <- as.character(unlist(leaf$reference_key %||% key))
      if (length(key) != 1L || length(ref_key) != 1L) return(NULL)
      list(A = list(main = c(.mk(name, 2), .mk(key, "K1")), extras = stats::setNames(list(c(.mk(ref_col, 2), .mk(ref_key, "K1"))), ref_ds)),
           B = list(main = c(.mk(name, 3), .mk(key, "K1")), extras = stats::setNames(list(c(.mk(ref_col, 2), .mk(ref_key, "K1"))), ref_ds)))
    },
    greater_than_by_key = {
      ref_ds <- as.character(leaf$reference_dataset %||% ""); ref_col <- as.character(leaf$reference_column %||% "")
      if (!nzchar(ref_ds) || !nzchar(ref_col)) return(NULL)
      key <- as.character(unlist(leaf$key %||% "USUBJID")); ref_key <- as.character(unlist(leaf$reference_key %||% key))
      if (length(key) != 1L || length(ref_key) != 1L) return(NULL)
      list(A = list(main = c(.mk(name, 3), .mk(key, "K1")), extras = stats::setNames(list(c(.mk(ref_col, 2), .mk(ref_key, "K1"))), ref_ds)),
           B = list(main = c(.mk(name, 1), .mk(key, "K1")), extras = stats::setNames(list(c(.mk(ref_col, 2), .mk(ref_key, "K1"))), ref_ds)))
    },
    greater_than_or_equal_by_key = {
      ref_ds <- as.character(leaf$reference_dataset %||% ""); ref_col <- as.character(leaf$reference_column %||% "")
      if (!nzchar(ref_ds) || !nzchar(ref_col)) return(NULL)
      key <- as.character(unlist(leaf$key %||% "USUBJID")); ref_key <- as.character(unlist(leaf$reference_key %||% key))
      if (length(key) != 1L || length(ref_key) != 1L) return(NULL)
      list(A = list(main = c(.mk(name, 2), .mk(key, "K1")), extras = stats::setNames(list(c(.mk(ref_col, 2), .mk(ref_key, "K1"))), ref_ds)),
           B = list(main = c(.mk(name, 1), .mk(key, "K1")), extras = stats::setNames(list(c(.mk(ref_col, 2), .mk(ref_key, "K1"))), ref_ds)))
    },
    missing_in_ref = {
      ref_ds <- as.character(leaf$reference_dataset %||% "")
      if (!nzchar(ref_ds)) return(NULL)
      key <- as.character(unlist(leaf$key %||% name))
      ref_key <- as.character(unlist(leaf$reference_key %||% key))
      if (length(key) != 1L || length(ref_key) != 1L) return(NULL)
      list(A = list(main = .mk(key, "K_MISSING"), extras = stats::setNames(list(.mk(ref_key, "K_PRESENT")), ref_ds)),
           B = list(main = .mk(key, "K_PRESENT"), extras = stats::setNames(list(.mk(ref_key, "K_PRESENT")), ref_ds)))
    },
    subject_has_matching_row = {
      ref_ds <- as.character(leaf$reference_dataset %||% "")
      ref_col <- as.character(leaf$reference_column %||% "")
      exp <- as.character(leaf$expected_value %||% "")
      if (!nzchar(ref_ds) || !nzchar(ref_col) || !nzchar(exp)) return(NULL)
      key <- as.character(unlist(leaf$key %||% name))
      ref_key <- as.character(unlist(leaf$reference_key %||% key))
      if (length(key) != 1L || length(ref_key) != 1L) return(NULL)
      list(A = list(main = .mk(key, "K1"), extras = stats::setNames(list(c(.mk(ref_key, "K1"), .mk(ref_col, exp))), ref_ds)),
           B = list(main = .mk(key, "K1"), extras = stats::setNames(list(c(.mk(ref_key, "K1"), .mk(ref_col, paste0("NO_", exp)))), ref_ds)))
    },

    # -- temporal / format -----------------------------------------------
    iso8601 = list(A = .mk(name, "2026-01-15T12:00:00"),
                   B = .mk(name, "not-a-date")),
    is_complete_date   = list(A = .mk(name, "2026-01-15"), B = .mk(name, "2026-01-")),
    is_incomplete_date = list(A = .mk(name, "2026-01-"),   B = .mk(name, "2026-01-15")),
    invalid_date       = list(A = .mk(name, "not-a-date"), B = .mk(name, "2026-01-15")),
    value_not_iso8601  = list(A = .mk(name, "not-a-date"), B = .mk(name, "2026-01-15")),
    invalid_duration   = list(A = .mk(name, "not-duration"), B = .mk(name, "P1D")),

    not_contains_all = {
      vals <- .vals_all(leaf[["value"]])
      if (length(vals) == 0L) return(NULL)
      list(A = .mk(name, vals[[1L]]),
           B = .mk(name, paste(vals, collapse = " ")))
    },
    is_not_diff = {
      minuend <- as.character(leaf$minuend %||% "")
      subtrahend <- as.character(leaf$subtrahend %||% "")
      if (!nzchar(minuend) || !nzchar(subtrahend)) return(NULL)
      list(A = c(.mk(name, 99), .mk(minuend, 10), .mk(subtrahend, 3)),
           B = c(.mk(name, 7),  .mk(minuend, 10), .mk(subtrahend, 3)))
    },
    is_not_pct_diff = {
      minuend <- as.character(leaf$minuend %||% "")
      subtrahend <- as.character(leaf$subtrahend %||% "")
      denom <- as.character(leaf$denominator %||% subtrahend)
      if (!nzchar(minuend) || !nzchar(subtrahend) || !nzchar(denom)) return(NULL)
      list(A = c(.mk(name, 99), .mk(minuend, 12), .mk(subtrahend, 10), .mk(denom, 10)),
           B = c(.mk(name, 20), .mk(minuend, 12), .mk(subtrahend, 10), .mk(denom, 10)))
    },

    # -- prefix / suffix set membership ------------------------------------
    # First N (or last N) chars of value not in allowed set -> fires.
    prefix_is_not_contained_by = {
      allowed <- .vals_all(leaf[["value"]])
      pfx_len <- as.integer(leaf[["prefix"]] %||% 2L)
      if (length(allowed) == 0L) return(NULL)
      good <- toupper(substring(allowed[[1L]], 1L, pfx_len))
      bad  <- "ZZ"
      if (nchar(bad) < pfx_len) bad <- strrep("Z", pfx_len)
      bad <- substring(bad, 1L, pfx_len)
      list(A = .mk(name, paste0(bad, "TAIL")),
           B = .mk(name, paste0(good, "TAIL")))
    },
    suffix_is_not_contained_by = {
      allowed <- .vals_all(leaf[["value"]])
      sfx_len <- as.integer(leaf[["suffix"]] %||% 2L)
      if (length(allowed) == 0L) return(NULL)
      a1 <- allowed[[1L]]
      good <- toupper(substring(a1, max(1L, nchar(a1) - sfx_len + 1L)))
      bad  <- strrep("Z", sfx_len)
      list(A = .mk(name, paste0("HEAD", bad)),
           B = .mk(name, paste0("HEAD", good)))
    },

    # var_by_suffix_not_numeric: fires when the column is non-numeric.
    # The op uses the leaf's `name` directly (no wildcard expansion to
    # other domains). Negative needs a numeric column.
    var_by_suffix_not_numeric = {
      list(A = .mk(name, "abc"), B = .mk(name, 1))
    },

    # max_n_records_per_group_matching: more than max_n rows per group
    # match a value -> fires.
    max_n_records_per_group_matching = {
      val <- as.character(leaf[["value"]] %||% "")
      group_keys <- as.character(unlist(leaf[["group_keys"]] %||% character(0)))
      max_n <- as.integer(leaf[["max_n"]] %||% 1L)
      if (!nzchar(val) || length(group_keys) == 0L) return(NULL)
      group_keys <- .expand_wildcard(group_keys, domain)
      # Need (max_n + 1) rows matching, all in same group, to fire.
      n_match <- max_n + 1L
      n_neg   <- max_n
      A <- list()
      A[[name]] <- rep(val, n_match)
      B <- list()
      B[[name]] <- rep(val, n_neg)
      for (g in group_keys) {
        A[[g]] <- rep("G1", n_match)
        B[[g]] <- rep("G1", n_neg)
      }
      list(A = A, B = B)
    },

    # is_inconsistent_across_dataset: row's value differs from same-key
    # value in a reference dataset.
    is_inconsistent_across_dataset = {
      val <- leaf[["value"]]
      if (is.list(val)) {
        ref_ds <- as.character(val$reference_dataset %||% "")
        by_key <- as.character(val$by %||% name)
        ref_col <- as.character(val$column %||% name)
      } else if (is.character(val) && length(val) == 1L && grepl("\\.", val)) {
        parts <- strsplit(val, ".", fixed = TRUE)[[1L]]
        ref_ds <- parts[[1L]]
        ref_col <- parts[[2L]]
        by_key <- name
      } else {
        return(NULL)
      }
      if (!nzchar(ref_ds) || !nzchar(ref_col)) return(NULL)
      if (length(by_key) != 1L || !nzchar(by_key)) return(NULL)
      by_key  <- .expand_wildcard(by_key,  domain)[[1L]]
      ref_col <- .expand_wildcard(ref_col, domain)[[1L]]
      if (identical(toupper(ref_ds), toupper(main_dataset %||% ""))) return(NULL)
      list(
        A = list(
          main = c(.mk(name, "DIFF"), .mk(by_key, "K1")),
          extras = stats::setNames(list(c(.mk(ref_col, "SAME"), .mk(by_key, "K1"))), ref_ds)
        ),
        B = list(
          main = c(.mk(name, "SAME"), .mk(by_key, "K1")),
          extras = stats::setNames(list(c(.mk(ref_col, "SAME"), .mk(by_key, "K1"))), ref_ds)
        )
      )
    },

    # any_index_missing_ref_var: for each unique index value in `name`, the
    # reference dataset must contain the templated variable. Fires when
    # ANY index value's templated column is missing.
    any_index_missing_ref_var = {
      ref_ds <- as.character(leaf[["reference_dataset"]] %||% "")
      tmpl <- as.character(leaf[["name_template"]] %||% "")
      ph <- as.character(leaf[["placeholder"]] %||% "xx")
      if (!nzchar(ref_ds) || !nzchar(tmpl)) return(NULL)
      fmt <- switch(ph, "xx" = "%02d", "zz" = "%02d", "y" = "%d", "w" = "%d", "%02d")
      idx_val <- 1L
      formatted <- sprintf(fmt, idx_val)
      tmpl_col <- gsub(ph, formatted, tmpl, fixed = TRUE)
      list(
        A = list(
          main = .mk(name, idx_val),
          extras = stats::setNames(list(list(`_placeholder_` = "x")), ref_ds)
        ),
        B = list(
          main = .mk(name, idx_val),
          extras = stats::setNames(list(stats::setNames(list("x"), tmpl_col)), ref_ds)
        )
      )
    },

    # value_in_srs_table: fires when a non-empty value is NOT in the SRS
    # registry. The seeder's .dummy_dictionaries() injects a provider whose
    # every field returns "VALID" via contains(). Negative variant uses
    # "VALID"; positive uses anything else.
    value_in_srs_table = {
      list(A = .mk(name, "INVALID"), B = .mk(name, "VALID"))
    },

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
  r <- validate(files = files, spec = spec, rules = rule_id, quiet = TRUE,
                dictionaries = .dummy_dictionaries())
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

  # Submission-scope dataset existence rules: a single-leaf
  # `exists(<DSNAME>)` or `not_exists(<DSNAME>)` against the submission stub
  # is satisfied or violated by whether <DSNAME> appears in the file map
  # at all. Seed by swapping which datasets are present.
  is_sub <- isTRUE(as.logical(rule$scope$submission %||% FALSE))
  if (is_sub && length(leaves_info) == 1L &&
      ops[[1L]] %in% c("exists", "not_exists")) {
    leaf <- leaves_info[[1L]]$leaf
    target_ds <- toupper(as.character(leaf$name %||% ""))
    if (nzchar(target_ds) && !grepl("\\.", target_ds)) {
      # Build positive (rule fires) and negative (rule does not fire) maps.
      # `exists`     fires when target dataset is present.
      # `not_exists` fires when target dataset is absent.
      placeholder_ds <- if (target_ds == "DM") "AE" else "DM"
      placeholder_cols <- list(USUBJID = "S1")
      target_cols <- list(USUBJID = "S1")
      with_target <- stats::setNames(list(target_cols), target_ds)
      without_target <- stats::setNames(list(placeholder_cols), placeholder_ds)
      inverted_outer <- isTRUE(leaves_info[[1L]]$inverted)
      base_op <- ops[[1L]]
      effective_fires_when_present <- (base_op == "exists") != inverted_outer
      pos_map <- if (effective_fires_when_present) with_target else without_target
      neg_map <- if (effective_fires_when_present) without_target else with_target

      paths <- .fx_paths(rule$authority %||% "unknown", rule_id)
      if (!isTRUE(force) &&
          (.is_manual(paths$positive) || .is_manual(paths$negative))) {
        n_skipped <- n_skipped + 1L
        reasons <- c(reasons, "manual-fixture-present")
        next
      }

      out_pos <- .run_rule(rule_id, pos_map, spec = NULL)
      out_neg <- .run_rule(rule_id, neg_map, spec = NULL)
      if (!isTRUE(out_pos$fires) || isTRUE(out_neg$fires)) {
        n_skipped <- n_skipped + 1L
        reasons <- c(reasons,
          if (!out_pos$fires && !out_neg$fires) "neither-fires"
          else if (out_pos$fires && out_neg$fires) "both-fire"
          else "positive-no-fire")
        next
      }

      notes_pos <- sprintf("auto-seeded submission-scope %s; target dataset %s",
                           base_op, target_ds)
      notes_neg <- sprintf("auto-seeded submission-scope %s; target dataset %s (should not fire)",
                           base_op, target_ds)
      .write_fixture(paths$positive, rule_id, "positive", pos_map,
                     out_pos, notes_pos)
      .write_fixture(paths$negative, rule_id, "negative", neg_map,
                     out_neg, notes_neg)
      written_paths <- c(written_paths, paths$positive, paths$negative)
      n_seeded <- n_seeded + 1L
      next
    }
  }

  seed_tuple <- .seed_expand_tuple(rule$check_tree$expand)
  if (length(seed_tuple) > 0L) {
    leaves_info <- lapply(leaves_info, function(x) {
      leaf_name <- as.character(unlist(x$leaf$name %||% character()))
      name_has_placeholder <- any(vapply(names(seed_tuple), function(ph) {
        any(grepl(ph, leaf_name, fixed = TRUE))
      }, logical(1L)))
      if (name_has_placeholder) {
        x$leaf <- .substitute_seed_tuple(x$leaf, seed_tuple)
      }
      x
    })
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
    # Also collect dotted refs like "DM.USUBJID" in `value`.
    if (!is.na(v1) && length(v1) == 1L) {
      dref <- .parse_dotted_ref(v1)
      if (!is.null(dref)) dollar_targets <- c(dollar_targets, dref$dataset)
    }
    # Cross-dataset ops carry an explicit `reference_dataset` arg.
    rd <- as.character(lf$leaf[["reference_dataset"]] %||% "")
    if (length(rd) == 1L && nzchar(rd)) {
      dollar_targets <- c(dollar_targets, toupper(rd))
    }
    # exists("DS.COL") name pattern.
    nm1 <- as.character(unlist(lf$leaf$name %||% character()))
    if (length(nm1) == 1L &&
        grepl("^[A-Z][A-Z0-9]{1,7}\\.[A-Z][A-Z0-9_]*$", nm1)) {
      dollar_targets <- c(dollar_targets, toupper(strsplit(nm1, ".", fixed = TRUE)[[1L]][[1L]]))
    }
  }
  if (length(dollar_targets) > 0L &&
      toupper(ds_info$name) %in% toupper(dollar_targets)) {
    scope_doms <- rule$scope$domains
    explicit_scope <- length(scope_doms) > 0L &&
      any(nzchar(as.character(unlist(scope_doms))) &
          toupper(as.character(unlist(scope_doms))) != "ALL")
    if (!explicit_scope) {
      alt_candidates <- c("AE", "DS", "EX", "LB", "CM", "VS", "MH", "PR", "TS")
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

  paths <- .fx_paths(rule$authority %||% "unknown", rule_id)
  if (!isTRUE(force) &&
      (.is_manual(paths$positive) || .is_manual(paths$negative))) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "manual-fixture-present")
    next
  }

  # Build and verify candidate datasets. The first candidate is the old
  # all-A positive. Additional candidates handle `{any: [...]}` and mixed
  # trees where setting every leaf to its firing value creates conflicts or
  # accidentally disables a branch. We still rely on validate() as oracle:
  # no unverified candidate is written.
  .dataset_map_from_sides <- function(sides) {
    cols <- .merge_cols(lapply(sides, function(v) v$main))
    if (is.null(cols)) return(NULL)
    extras <- .merge_extras(lapply(sides, function(v) v$extras))
    if (is.null(extras)) return(NULL)
    c(stats::setNames(list(cols), ds_info$name), extras)
  }

  dataset_map_neg <- .dataset_map_from_sides(variants_B)
  if (is.null(dataset_map_neg)) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "leaf-col-conflict")
    next
  }

  pos_side_candidates <- list(variants_A)
  n_leaf <- length(variants_A)
  if (n_leaf > 1L) {
    for (j in seq_len(n_leaf)) {
      sides <- variants_B
      sides[[j]] <- variants_A[[j]]
      pos_side_candidates[[length(pos_side_candidates) + 1L]] <- sides
    }
    if (n_leaf <= 8L) {
      pairs <- utils::combn(seq_len(n_leaf), 2L, simplify = FALSE)
      for (pair in pairs) {
        sides <- variants_B
        sides[pair] <- variants_A[pair]
        pos_side_candidates[[length(pos_side_candidates) + 1L]] <- sides
      }
    }
  }

  out_neg <- .run_rule(rule_id, dataset_map_neg, spec = ds_info$spec)
  dataset_map_pos <- NULL
  out_pos <- list(fires = FALSE, rows = integer())
  for (sides in pos_side_candidates) {
    cand <- .dataset_map_from_sides(sides)
    if (is.null(cand)) next
    got <- .run_rule(rule_id, cand, spec = ds_info$spec)
    if (isTRUE(got$fires)) {
      dataset_map_pos <- cand
      out_pos <- got
      break
    }
  }

  if (!isTRUE(out_pos$fires) || isTRUE(out_neg$fires)) {
    reason <- if (!out_pos$fires && !out_neg$fires) "neither-fires"
              else if (out_pos$fires && out_neg$fires) "both-fire"
              else "positive-no-fire"
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, reason)
    next
  }

  any_inverted <- any(vapply(leaves_info, function(l) isTRUE(l$inverted), logical(1)))
  has_extras <- length(dataset_map_pos) > 1L
  extras_tag <- if (has_extras) sprintf(" (+%d ref ds)", length(dataset_map_pos) - 1L) else ""
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

# Prune stale auto-seed fixtures only when --force is active. A skipped rule
# may simply need a seeder improvement; pruning it silently on normal runs
# destroys previously-validated fixtures. Manual fixtures are always preserved.
n_pruned <- 0L
if (isTRUE(force)) {
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
