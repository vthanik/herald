# -----------------------------------------------------------------------------
# tools/seed-fixtures.R -- auto-seed golden fixtures for executable rules
# -----------------------------------------------------------------------------
# Run from the package root:
#
#   Rscript tools/seed-fixtures.R [--force]
#
# Writes tests/testthat/fixtures/golden/<authority>/<rule_id>/{positive,negative}.json
#
# Phase 1b scope:
#   * single-leaf and multi-leaf `{all: [...]}` / `{any: [...]}` trees
#   * --VAR wildcard expansion for SDTM rules (class -> representative domain)
#   * spec-based class resolution for class-scoped rules
#   * whitelisted operators across existence, compare, string, temporal
#
# Skipped: `not` wrappers, nested combinators, cross-dataset refs
# (`$dm_usubjid` style), `r_expression`, `is_unique_set`-family.
#
# Idempotency: fixtures authored manually (`authored: "manual"`) are never
# overwritten. Auto-seeded fixtures ARE overwritten.
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

SEEDER_VERSION <- "auto-seed@2"

WHITELIST_OPS <- c(
  # existence
  "exists", "not_exists", "non_empty", "empty",
  # compare
  "equal_to", "not_equal_to",
  # string / regex
  "matches_regex", "not_matches_regex",
  "contains", "does_not_contain",
  "starts_with", "ends_with",
  "longer_than", "shorter_than", "length_le",
  # set
  "is_contained_by", "is_not_contained_by",
  # temporal / format
  "iso8601", "is_complete_date", "is_incomplete_date"
)

# Canonical SDTM class -> representative domain. Used when a rule's scope
# specifies only a class and the auto-seeder needs a concrete dataset name
# + domain prefix for --VAR wildcard expansion.
CLASS_TO_DOMAIN <- list(
  "EVENTS"                        = "AE",
  "INTERVENTIONS"                 = "CM",
  "FINDINGS"                      = "LB",
  "FINDINGS ABOUT"                = "FA",
  "FINDINGS-ABOUT"                = "FA",
  "SPECIAL PURPOSE"               = "DM",
  "SPECIAL-PURPOSE"               = "DM",
  "TRIAL DESIGN"                  = "TA",
  "TRIAL-DESIGN"                  = "TA",
  "RELATIONSHIP"                  = "RELREC"
)

fx_root <- file.path("tests", "testthat", "fixtures", "golden")
dir.create(fx_root, recursive = TRUE, showWarnings = FALSE)

# -- tree walking -----------------------------------------------------------

#' Return the list of operator leaves for a supported tree shape, or NULL
#' when unsupported (has `not` wrappers, nested combinators, narrative, etc).
.extract_leaves <- function(node) {
  if (!is.list(node) || length(node) == 0L) return(NULL)
  if (!is.null(node[["not"]])) return(NULL)          # phase 2 territory
  if (!is.null(node[["r_expression"]])) return(NULL) # never auto-seedable
  if (!is.null(node[["narrative"]])) return(NULL)

  # Bare leaf
  if (!is.null(node[["operator"]])) return(list(node))

  for (key in c("all", "any")) {
    ch <- node[[key]]
    if (!is.null(ch)) {
      leaves <- list()
      for (c in ch) {
        if (!is.list(c)) return(NULL)
        if (!is.null(c[["not"]])) return(NULL)
        if (is.null(c[["operator"]])) return(NULL)   # nested combinator
        leaves[[length(leaves) + 1L]] <- c
      }
      return(leaves)
    }
  }
  NULL
}

# -- dataset + spec picker --------------------------------------------------

#' Decide the dataset name + class + optional spec for a rule's fixture.
#' Returns list(name, class, spec). `spec` is NULL when class scope is ALL
#' or absent (no spec needed).
.pick_dataset_and_spec <- function(rule) {
  doms    <- rule[["scope"]][["domains"]]
  classes <- rule[["scope"]][["classes"]]

  concrete_doms <- character()
  if (!is.null(doms) && length(doms) > 0L) {
    u <- toupper(as.character(unlist(doms)))
    concrete_doms <- u[nzchar(u) & u != "ALL" & !grepl("^SUPP", u) &
                       nchar(u) >= 2L & nchar(u) <= 8L]
  }

  # Class narrowing first -- it's usually the more restrictive filter.
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
  if (startsWith(as.character(name), "--") && !is.na(domain) && nzchar(domain)) {
    paste0(domain, substring(name, 3L))
  } else {
    as.character(name)
  }
}

# -- per-op seed variants ---------------------------------------------------

#' Return list(A = cols, B = cols) for one leaf. Variant A is the dataset
#' that should drive the operator to TRUE, B to FALSE. Returns NULL when we
#' can't seed this particular leaf (e.g. value absent, regex too opaque).
.leaf_variants <- function(op, leaf, domain) {
  raw_name <- as.character(leaf[["name"]] %||% "")
  if (!nzchar(raw_name)) return(NULL)
  if (startsWith(raw_name, "$")) return(NULL)  # cross-dataset ref
  name <- .expand_wildcard(raw_name, domain)
  if (!nzchar(name)) return(NULL)
  mk <- function(v) stats::setNames(list(v), name)

  val_first <- function(x) {
    if (is.null(x) || length(x) == 0L) return(NA_character_)
    as.character(x)[[1L]]
  }

  switch(
    op,
    exists       = list(A = mk("value"), B = list(`_placeholder_` = "x")),
    not_exists   = list(A = list(`_placeholder_` = "x"), B = mk("value")),
    non_empty    = list(A = mk("value"), B = mk("")),
    empty        = list(A = mk(""), B = mk("value")),

    equal_to = {
      v <- val_first(leaf[["value"]])
      if (is.na(v)) return(NULL)
      other <- if (identical(v, "OTHER")) "ANOTHER" else "OTHER"
      list(A = mk(v), B = mk(other))
    },
    not_equal_to = {
      v <- val_first(leaf[["value"]])
      if (is.na(v)) return(NULL)
      other <- if (identical(v, "OTHER")) "ANOTHER" else "OTHER"
      list(A = mk(other), B = mk(v))
    },

    contains = {
      v <- val_first(leaf[["value"]]); if (is.na(v)) return(NULL)
      list(A = mk(paste0("xx", v, "xx")), B = mk("no-match"))
    },
    does_not_contain = {
      v <- val_first(leaf[["value"]]); if (is.na(v)) return(NULL)
      list(A = mk("no-match"), B = mk(paste0("xx", v, "xx")))
    },
    starts_with = {
      v <- val_first(leaf[["value"]]); if (is.na(v)) return(NULL)
      list(A = mk(paste0(v, "Z")), B = mk(paste0("Z", v)))
    },
    ends_with = {
      v <- val_first(leaf[["value"]]); if (is.na(v)) return(NULL)
      list(A = mk(paste0("Z", v)), B = mk(paste0(v, "Z")))
    },

    longer_than = {
      n <- suppressWarnings(as.integer(val_first(leaf[["value"]])))
      if (is.na(n)) return(NULL)
      list(A = mk(strrep("x", n + 2L)), B = mk(strrep("x", max(0L, n - 1L))))
    },
    shorter_than = {
      n <- suppressWarnings(as.integer(val_first(leaf[["value"]])))
      if (is.na(n)) return(NULL)
      list(A = mk(strrep("x", max(0L, n - 1L))), B = mk(strrep("x", n + 2L)))
    },
    length_le = {
      n <- suppressWarnings(as.integer(val_first(leaf[["value"]])))
      if (is.na(n)) return(NULL)
      list(A = mk(strrep("x", max(0L, n - 1L))), B = mk(strrep("x", n + 2L)))
    },

    matches_regex = {
      # Run-to-verify will confirm; we guess alphanumerics for positive,
      # punctuation-only for negative.
      list(A = mk("TESTvalue"), B = mk("!!!"))
    },
    not_matches_regex = {
      list(A = mk("!!!"), B = mk("TESTvalue"))
    },

    is_contained_by = {
      v <- leaf[["value"]]
      if (is.null(v) || length(v) == 0L) return(NULL)
      allowed <- as.character(unlist(v))
      if (length(allowed) == 0L) return(NULL)
      not_in <- paste0("NOT_IN_", allowed[[1L]])
      list(A = mk(allowed[[1L]]), B = mk(not_in))
    },
    is_not_contained_by = {
      v <- leaf[["value"]]
      if (is.null(v) || length(v) == 0L) return(NULL)
      if (startsWith(as.character(v)[[1L]], "$")) return(NULL)
      allowed <- as.character(unlist(v))
      if (length(allowed) == 0L) return(NULL)
      not_in <- paste0("NOT_IN_", allowed[[1L]])
      list(A = mk(not_in), B = mk(allowed[[1L]]))
    },

    iso8601 = list(
      A = mk("2026-01-15T12:00:00"),
      B = mk("not-a-date")
    ),
    is_complete_date = list(
      A = mk("2026-01-15"), B = mk("2026-01-")
    ),
    is_incomplete_date = list(
      A = mk("2026-01-"), B = mk("2026-01-15")
    ),

    NULL
  )
}

# Merge a list of per-leaf col-sets into one. Later leaves don't overwrite
# earlier keys -- if that happens (same column referenced twice) we return
# NULL so the seeder skips the rule.
.merge_cols <- function(leaf_cols) {
  out <- list()
  for (lc in leaf_cols) {
    if (is.null(lc)) return(NULL)
    for (k in names(lc)) {
      if (!is.null(out[[k]])) {
        # Only reconcile if identical values (tolerates the same leaf
        # appearing twice).
        if (!identical(out[[k]], lc[[k]])) return(NULL)
      } else {
        out[[k]] <- lc[[k]]
      }
    }
  }
  out
}

.run_rule <- function(rule_id, ds_name, cols, spec = NULL) {
  df <- as.data.frame(cols, stringsAsFactors = FALSE, check.names = FALSE)
  r  <- validate(
    files = stats::setNames(list(df), ds_name),
    spec  = spec,
    rules = rule_id,
    quiet = TRUE
  )
  fired_rows <- r$findings$row[r$findings$status == "fired"]
  fired_rows <- fired_rows[!is.na(fired_rows)]
  list(fires = length(fired_rows) > 0L, rows = as.integer(fired_rows))
}

# -- fixture I/O ------------------------------------------------------------

.write_fixture <- function(path, rule_id, fix_type, ds_name, cols,
                           expected, notes, ds_class = NA_character_) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  obj <- list(
    rule_id      = rule_id,
    fixture_type = fix_type,
    datasets     = stats::setNames(list(as.list(cols)), ds_name),
    expected     = list(
      fires = expected$fires,
      rows  = if (isTRUE(expected$fires)) as.integer(expected$rows) else integer()
    ),
    notes    = notes,
    authored = SEEDER_VERSION
  )
  if (!is.na(ds_class) && nzchar(ds_class)) {
    obj$spec <- list(
      class_map = stats::setNames(list(ds_class), ds_name)
    )
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

  leaves <- .extract_leaves(rule$check_tree)
  if (is.null(leaves) || length(leaves) == 0L) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "unsupported-tree-shape")
    next
  }

  ops <- vapply(leaves, function(l) as.character(l$operator %||% ""), character(1))
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

  # ADaM rules use concrete column names; non-ADaM picks from CLASS_TO_DOMAIN.
  is_adam <- grepl("^AD[A-Z]", ds_info$name)
  wildcard_domain <- if (is_adam) NA_character_ else ds_info$name

  variants_A <- vector("list", length(leaves))
  variants_B <- vector("list", length(leaves))
  seed_fail <- FALSE
  for (j in seq_along(leaves)) {
    v <- .leaf_variants(ops[[j]], leaves[[j]], wildcard_domain)
    if (is.null(v)) { seed_fail <- TRUE; break }
    variants_A[[j]] <- v$A
    variants_B[[j]] <- v$B
  }
  if (seed_fail) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "leaf-not-seedable")
    next
  }

  cols_pos <- .merge_cols(variants_A)
  cols_neg <- .merge_cols(variants_B)
  if (is.null(cols_pos) || is.null(cols_neg)) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "leaf-col-conflict")
    next
  }

  paths <- .fx_paths(rule$authority %||% "unknown", rule_id)
  if (!isTRUE(force) &&
      (.is_manual(paths$positive) || .is_manual(paths$negative))) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "manual-fixture-present")
    next
  }

  out_pos <- .run_rule(rule_id, ds_info$name, cols_pos, spec = ds_info$spec)
  out_neg <- .run_rule(rule_id, ds_info$name, cols_neg, spec = ds_info$spec)

  if (!isTRUE(out_pos$fires) || isTRUE(out_neg$fires)) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons,
      if (!out_pos$fires && !out_neg$fires) "neither-fires"
      else if (out_pos$fires && out_neg$fires) "both-fire"
      else "positive-no-fire")
    next
  }

  notes_pos <- sprintf("auto-seeded; %d leaf op(s): %s",
                       length(ops), paste(ops, collapse = ","))
  notes_neg <- sprintf("auto-seeded; %d leaf op(s): %s (should not fire)",
                       length(ops), paste(ops, collapse = ","))

  .write_fixture(paths$positive, rule_id, "positive", ds_info$name, cols_pos,
                 out_pos, notes_pos, ds_class = ds_info$class)
  .write_fixture(paths$negative, rule_id, "negative", ds_info$name, cols_neg,
                 out_neg, notes_neg, ds_class = ds_info$class)
  n_seeded <- n_seeded + 1L
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
  cat("top non-whitelisted ops (sample):\n")
  for (i in seq_len(min(10L, length(top_ops)))) {
    cat(sprintf("  %-28s %5d\n", names(top_ops)[i], top_ops[[i]]))
  }
}
