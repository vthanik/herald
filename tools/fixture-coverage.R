# -----------------------------------------------------------------------------
# tools/fixture-coverage.R -- golden-fixture coverage report
# -----------------------------------------------------------------------------
# Enumerates executable rules (check_tree contains at least one `operator`
# leaf) and checks whether each has both positive.json + negative.json under
# tools/rule-authoring/fixtures/<authority>/<rule_id>/.
#
# Prints a terminal summary and writes tools/rule-authoring/fixtures/COVERAGE.md
# for PR reviewers.
#
# Exit code is ALWAYS 0 for Phase 1a (warn-only CI gate). Flip to
# `quit(status = 1)` when coverage threshold is enforced (Phase 3).

suppressPackageStartupMessages({
  library(jsonlite)
})

fx_root <- file.path("tools", "rule-authoring", "fixtures")
out_md  <- file.path("tools", "rule-authoring", "fixtures", "COVERAGE.md")

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

n_exec <- nrow(exec_rules)
n_cov  <- sum(covered)
pct    <- if (n_exec > 0L) round(100 * n_cov / n_exec, 1) else 0

# -- terminal summary -------------------------------------------------------

cat("Golden-fixture coverage\n")
cat(sprintf("  Executable rules:       %d\n", n_exec))
cat(sprintf("  Covered (both fixtures):%d  (%.1f%%)\n", n_cov, pct))
cat(sprintf("  Missing positive only:  %d\n", sum(missing_pos)))
cat(sprintf("  Missing negative only:  %d\n", sum(missing_neg)))
cat(sprintf("  Missing both (pending): %d\n", sum(missing_both)))
cat("\nCoverage gate: WARN-ONLY (see tools/fixture-coverage.R for threshold notes).\n")

# -- markdown report --------------------------------------------------------

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
  sprintf("| missing both (pending) | %d |", sum(missing_both)),
  sprintf("| coverage | %.1f%% |", pct),
  "",
  "Gate: WARN-ONLY. Will flip to hard-fail at 80%+ coverage.",
  "",
  "## Covered rules",
  ""
)

if (n_cov > 0L) {
  md <- c(md,
    paste("-", exec_rules$id[covered])
  )
} else {
  md <- c(md, "_none yet_")
}

md <- c(md, "",
  "## First 20 pending rules",
  ""
)
pending_ids <- exec_rules$id[missing_both]
if (length(pending_ids) > 0L) {
  md <- c(md, paste("-", utils::head(pending_ids, 20L)))
  if (length(pending_ids) > 20L) {
    md <- c(md, sprintf("- _...and %d more_", length(pending_ids) - 20L))
  }
} else {
  md <- c(md, "_none_")
}

dir.create(dirname(out_md), recursive = TRUE, showWarnings = FALSE)
writeLines(md, out_md, useBytes = TRUE)
cat(sprintf("\nCoverage report written to %s\n", out_md))

# Always exit 0 (warn-only for Phase 1a).
invisible(0L)
