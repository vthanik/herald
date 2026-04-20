# -----------------------------------------------------------------------------
# tools/seed-fixtures.R -- auto-seed golden fixtures for executable rules
# -----------------------------------------------------------------------------
# Run from the package root:
#
#   Rscript tools/seed-fixtures.R [--force]
#
# Writes to tests/testthat/fixtures/golden/<authority>/<rule_id>/{positive,negative}.json
#
# MVP scope (Phase 1a): single-leaf trees where the leaf operator is in the
# whitelist below. Dataset name is picked from `scope$domains` when a concrete
# 2-10 char name is present; otherwise a standard-based fallback. Rules we
# can't seed mechanically are reported with their skip reason and left alone.
#
# Idempotency: fixtures authored manually (`authored: "manual"`) are never
# overwritten. Auto-seeded fixtures (`authored: "auto-seed@..."`) ARE
# overwritten so regenerating picks up seeder changes.
#
# Run-to-verify: each candidate pair is fed through validate() to confirm
# which variant fires. Rules where neither or both variants fire are skipped.

suppressPackageStartupMessages({
  library(jsonlite)
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(quiet = TRUE)
  } else {
    library(herald)
  }
})

SEEDER_VERSION <- "auto-seed@1"
# Whitelist expanded from the planned 3-op MVP after discovering the real
# catalog is dominated by wildcard + class-scoped rules. These five operators
# cover the single-leaf, concrete-column, ALL-scoped shapes that actually
# appear in inst/rules/rules.rds. Phase 1b will expand further once the
# seeder can handle --VAR expansion + spec-based class resolution.
WHITELIST_OPS  <- c("equal_to", "non_empty", "iso8601", "exists", "not_exists")

fx_root <- file.path("tests", "testthat", "fixtures", "golden")
dir.create(fx_root, recursive = TRUE, showWarnings = FALSE)

# -- helpers ----------------------------------------------------------------

.extract_leaf <- function(node) {
  # Returns the inner operator leaf for single-operator-leaf trees, else NULL.
  # Handles: {operator: ...}, {all: [leaf]}, {any: [leaf]}, {not: leaf},
  # and the all/any-wrapped-not variants.
  if (!is.list(node) || length(node) == 0L) return(NULL)
  if (!is.null(node[["operator"]])) return(node)
  for (key in c("all", "any")) {
    ch <- node[[key]]
    if (!is.null(ch) && length(ch) == 1L) {
      return(.extract_leaf(ch[[1L]]))
    }
  }
  if (!is.null(node[["not"]])) return(.extract_leaf(node[["not"]]))
  NULL
}

.pick_dataset_name <- function(rule) {
  doms <- rule[["scope"]][["domains"]]
  if (!is.null(doms) && length(doms) > 0L) {
    doms <- toupper(as.character(unlist(doms)))
    doms <- doms[nzchar(doms) & doms != "ALL" & !grepl("^SUPP", doms)]
    doms <- doms[nchar(doms) >= 2L & nchar(doms) <= 8L]
    if (length(doms) > 0L) return(doms[[1L]])
  }
  has_classes <- length(rule[["scope"]][["classes"]] %||% list()) > 0L
  if (has_classes) return(NA_character_)  # class-only: needs spec to resolve
  std <- toupper(rule[["standard"]] %||% "")
  if (grepl("ADAM", std)) return("ADSL")
  if (grepl("SDTM|SEND", std)) return("DM")
  NA_character_
}

.seed_variants <- function(op, leaf) {
  # Returns list(variantA = <named-list-of-cols>, variantB = ...)
  # Both variants are 1-row datasets with just the target column.
  name <- leaf[["name"]]
  if (is.null(name) || !nzchar(as.character(name))) return(NULL)
  name <- as.character(name)

  mk <- function(v) stats::setNames(list(v), name)

  switch(
    op,
    equal_to = {
      v <- leaf[["value"]]
      if (is.null(v) || length(v) == 0L) return(NULL)
      val <- as.character(v)[[1L]]
      # Variant A matches; variant B doesn't.
      other <- if (val == "OTHER") "ANOTHER" else "OTHER"
      list(A = mk(val), B = mk(other))
    },
    non_empty = list(
      A = mk("value"),   # leaf evaluates TRUE (non-empty)
      B = mk("")         # leaf evaluates FALSE (empty)
    ),
    iso8601 = list(
      A = mk("2026-01-15T12:00:00"),   # valid
      B = mk("not-a-date")             # invalid
    ),
    exists = list(
      A = mk("value"),                         # column present -> leaf TRUE
      B = list(`_placeholder_` = "x")          # column absent  -> leaf FALSE
    ),
    not_exists = list(
      A = list(`_placeholder_` = "x"),         # column absent  -> leaf TRUE
      B = mk("value")                          # column present -> leaf FALSE
    ),
    NULL
  )
}

.run_rule <- function(rule_id, ds_name, cols) {
  df <- as.data.frame(cols, stringsAsFactors = FALSE, check.names = FALSE)
  r  <- validate(files = stats::setNames(list(df), ds_name),
                 rules = rule_id, quiet = TRUE)
  fired_rows <- r$findings$row[r$findings$status == "fired"]
  fired_rows <- fired_rows[!is.na(fired_rows)]
  list(fires = length(fired_rows) > 0L, rows = as.integer(fired_rows))
}

.write_fixture <- function(path, rule_id, fix_type, ds_name, cols,
                           expected, notes) {
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
  json <- jsonlite::toJSON(obj, auto_unbox = TRUE, pretty = TRUE,
                           null = "null", digits = NA)
  writeLines(json, path, useBytes = TRUE)
}

.fx_paths <- function(authority, rule_id) {
  dir <- file.path(fx_root, tolower(authority), rule_id)
  # NOTE: do NOT create the directory here -- only create when we actually
  # write fixtures (see .write_fixture). Otherwise a skipped rule leaves an
  # empty dir behind.
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

args <- commandArgs(trailingOnly = TRUE)
force <- "--force" %in% args

cat_rds <- system.file("rules", "rules.rds", package = "herald")
if (!nzchar(cat_rds)) cat_rds <- file.path("inst", "rules", "rules.rds")
catalog <- readRDS(cat_rds)

n_total   <- nrow(catalog)
n_seeded  <- 0L
n_skipped <- 0L
reasons   <- character()

cat(sprintf("seed-fixtures: scanning %d rules\n", n_total))

for (i in seq_len(n_total)) {
  rule <- as.list(catalog[i, , drop = FALSE])
  rule$scope      <- rule$scope[[1L]]
  rule$check_tree <- rule$check_tree[[1L]]
  rule_id <- rule$id

  leaf <- .extract_leaf(rule$check_tree)
  if (is.null(leaf)) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "multi-leaf-tree")
    next
  }
  op <- as.character(leaf$operator %||% "")
  if (!op %in% WHITELIST_OPS) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, paste0("op-not-whitelisted:", op))
    next
  }

  ds_name <- .pick_dataset_name(rule)
  if (is.na(ds_name)) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "no-dataset-name")
    next
  }

  variants <- .seed_variants(op, leaf)
  if (is.null(variants)) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "variants-unavailable")
    next
  }

  # Respect manual fixtures
  paths <- .fx_paths(rule$authority %||% "unknown", rule_id)
  if (!isTRUE(force) &&
      (.is_manual(paths$positive) || .is_manual(paths$negative))) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, "manual-fixture-present")
    next
  }

  out_A <- .run_rule(rule_id, ds_name, variants$A)
  out_B <- .run_rule(rule_id, ds_name, variants$B)

  if (out_A$fires == out_B$fires) {
    n_skipped <- n_skipped + 1L
    reasons <- c(reasons, if (out_A$fires) "both-fire" else "neither-fires")
    next
  }

  if (out_A$fires) {
    pos_cols <- variants$A; pos_out <- out_A
    neg_cols <- variants$B; neg_out <- out_B
  } else {
    pos_cols <- variants$B; pos_out <- out_B
    neg_cols <- variants$A; neg_out <- out_A
  }

  notes_pos <- sprintf("auto-seeded for leaf op '%s'; should fire", op)
  notes_neg <- sprintf("auto-seeded for leaf op '%s'; should not fire", op)

  .write_fixture(paths$positive, rule_id, "positive", ds_name, pos_cols,
                 pos_out, notes_pos)
  .write_fixture(paths$negative, rule_id, "negative", ds_name, neg_cols,
                 neg_out, notes_neg)
  n_seeded <- n_seeded + 1L
}

cat(sprintf("seed-fixtures: seeded %d rules, skipped %d\n",
            n_seeded, n_skipped))
top_reasons <- sort(table(reasons), decreasing = TRUE)
cat("top skip reasons:\n")
for (i in seq_len(min(8L, length(top_reasons)))) {
  cat(sprintf("  %-30s %5d\n", names(top_reasons)[i], top_reasons[[i]]))
}
