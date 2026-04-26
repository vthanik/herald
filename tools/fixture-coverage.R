# -----------------------------------------------------------------------------
# tools/fixture-coverage.R -- golden-fixture coverage gate (ratchet)
# -----------------------------------------------------------------------------
# Enumerates executable rules (check_tree contains at least one `operator`
# leaf) and checks whether each has both positive.json + negative.json under
# tools/rule-authoring/fixtures/<authority>/<rule_id>/.
#
# Gate behaviour:
#   - Every NEW executable rule must ship with fixtures. CI blocks if any
#     rule not in known-missing.txt is missing fixtures (exit 1).
#   - known-missing.txt is the baseline of previously-known gaps. It can
#     only shrink over time -- never grow. Update it by running this script
#     after manually authoring fixtures for those rules.
#   - Pass `--update-baseline` to write a new known-missing.txt and exit 0.
#     Use this only when intentionally acknowledging a new unfixable rule.
#
# Prints a terminal summary and writes tools/rule-authoring/fixtures/COVERAGE.md

suppressPackageStartupMessages({
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)
update_baseline <- "--update-baseline" %in% args

fx_root      <- file.path("tools", "rule-authoring", "fixtures")
out_md       <- file.path(fx_root, "COVERAGE.md")
known_path   <- file.path(fx_root, "known-missing.txt")

# -- classify rules ---------------------------------------------------------

has_operator_leaf <- function(node) {
  if (!is.list(node) || length(node) == 0L) return(FALSE)
  if (!is.null(node[["operator"]])) return(TRUE)
  for (key in c("all", "any")) {
    ch <- node[[key]]
    if (!is.null(ch)) for (c in ch) if (has_operator_leaf(c)) return(TRUE)
  }
  if (!is.null(node[["not"]])) return(has_operator_leaf(node[["not"]]))
  FALSE
}

cat_rds <- system.file("rules", "rules.rds", package = "herald")
if (!nzchar(cat_rds)) cat_rds <- file.path("inst", "rules", "rules.rds")
catalog <- readRDS(cat_rds)

is_exec <- vapply(catalog$check_tree, has_operator_leaf, logical(1))
exec_rules <- catalog[is_exec, c("id", "authority"), drop = FALSE]

# -- check fixture presence -------------------------------------------------

has_fixture <- function(authority, rule_id, which) {
  path <- file.path(fx_root, tolower(authority), rule_id, paste0(which, ".json"))
  file.exists(path)
}

pos <- mapply(has_fixture, exec_rules$authority, exec_rules$id,
              MoreArgs = list(which = "positive"))
neg <- mapply(has_fixture, exec_rules$authority, exec_rules$id,
              MoreArgs = list(which = "negative"))

covered      <- pos & neg
missing_pos  <- !pos & neg
missing_neg  <- pos & !neg
missing_both <- !pos & !neg

missing_ids  <- exec_rules$id[!pos | !neg]

n_exec <- nrow(exec_rules)
n_cov  <- sum(covered)
pct    <- if (n_exec > 0L) round(100 * n_cov / n_exec, 1) else 0

# -- ratchet check ----------------------------------------------------------

known_ids <- if (file.exists(known_path)) readLines(known_path) else character(0)

new_missing  <- setdiff(missing_ids, known_ids)   # newly broken -- FAIL
now_fixed    <- setdiff(known_ids, missing_ids)    # previously missing, now done
still_known  <- intersect(missing_ids, known_ids)  # known gap, not yet fixed

# -- terminal summary -------------------------------------------------------

cat("Golden-fixture coverage\n")
cat(sprintf("  Executable rules:       %d\n", n_exec))
cat(sprintf("  Covered (both fixtures):%d  (%.1f%%)\n", n_cov, pct))
cat(sprintf("  Missing positive only:  %d\n", sum(missing_pos)))
cat(sprintf("  Missing negative only:  %d\n", sum(missing_neg)))
cat(sprintf("  Missing both:           %d\n", sum(missing_both)))
if (length(now_fixed) > 0L) {
  cat(sprintf("  Resolved since baseline:%d  (good!)\n", length(now_fixed)))
}
if (length(new_missing) > 0L) {
  cat(sprintf("  NEW missing (not in baseline): %d  [FAIL]\n", length(new_missing)))
  for (id in new_missing) cat(sprintf("    - %s\n", id))
}

# -- markdown report --------------------------------------------------------

gate_note <- if (length(new_missing) == 0L) {
  sprintf(
    "Gate: PASS. All %d missing rules are in the known baseline.",
    length(still_known)
  )
} else {
  sprintf(
    "Gate: FAIL. %d rule(s) newly missing fixtures (not in baseline).",
    length(new_missing)
  )
}

md <- c(
  "# Golden-fixture coverage",
  "",
  sprintf("_generated %s by tools/fixture-coverage.R_",
          format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
  "",
  "| metric | count |",
  "|---|---:|",
  sprintf("| executable rules | %d |", n_exec),
  sprintf("| covered (both fixtures) | %d |", n_cov),
  sprintf("| missing positive only | %d |", sum(missing_pos)),
  sprintf("| missing negative only | %d |", sum(missing_neg)),
  sprintf("| missing both | %d |", sum(missing_both)),
  sprintf("| coverage | %.1f%% |", pct),
  "",
  gate_note,
  "",
  "## Covered rules",
  ""
)

if (n_cov > 0L) {
  md <- c(md, paste("-", exec_rules$id[covered]))
} else {
  md <- c(md, "_none yet_")
}

md <- c(md, "",
  "## Known missing (baseline -- need manual fixtures)",
  ""
)
if (length(still_known) > 0L) {
  md <- c(md, paste("-", utils::head(sort(still_known), 20L)))
  if (length(still_known) > 20L) {
    md <- c(md, sprintf("- _...and %d more_", length(still_known) - 20L))
  }
} else {
  md <- c(md, "_none -- full coverage achieved!_")
}

dir.create(dirname(out_md), recursive = TRUE, showWarnings = FALSE)
writeLines(md, out_md, useBytes = TRUE)
cat(sprintf("\nCoverage report written to %s\n", out_md))

# -- update baseline if requested -------------------------------------------

if (update_baseline) {
  writeLines(sort(missing_ids), known_path)
  cat(sprintf("Baseline updated: %d rules in %s\n", length(missing_ids), known_path))
  invisible(0L)
} else if (length(new_missing) > 0L) {
  cat(sprintf(
    "\nFAIL: %d new executable rule(s) lack fixtures.\n",
    length(new_missing)
  ))
  cat("Run: Rscript tools/seed-fixtures.R\n")
  cat("If unfixable, run: Rscript tools/fixture-coverage.R --update-baseline\n")
  quit(status = 1L, save = "no")
}
