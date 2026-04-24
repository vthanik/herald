#!/usr/bin/env Rscript
# tools/rule-authoring/port-core.R
# ---------------------------------------------------------------------------
# Port CORE-library Check: trees into the paired narrative CG YAML files.
#
# Eligibility criteria (enforced inline):
#   1. catalog.csv row has overlap_type = "core-is-better" and
#      status = "narrative" (and bucket = "sdtm-ig-v2.0")
#   2. The paired CORE YAML has no Operations: block (no $-ref computed values)
#   3. All operator names used in the Check: tree are registered in herald's
#      ops registry (extracted from R/ops-*.R)
#
# Ineligible rules are logged and left as narrative (non-fatal).
#
# Each CG YAML gets:
#   check:     <lowercased check tree from CORE>
#   provenance.executability: predicate
#   provenance.core_crosswalk: CORE-NNNNNN
#
# Usage:
#   Rscript tools/rule-authoring/port-core.R [--dry-run]
# Run from the package root.

suppressPackageStartupMessages(library(yaml))

args    <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args

project_root <- getwd()
if (!dir.exists(file.path(project_root, "tools", "handauthored"))) {
  stop("Run from the package root (tools/handauthored/ must exist)")
}

catalog_csv <- file.path(project_root, "tools", "rule-authoring", "catalog.csv")
core_root   <- file.path(project_root, "tools", "handauthored", "cdisc", "sdtm-library-api")
cg_root     <- file.path(project_root, "tools", "handauthored", "cdisc", "sdtm-ig-v2.0")

stopifnot(file.exists(catalog_csv))

# ---- extract known operator names -------------------------------------------

.known_ops <- local({
  op_files <- list.files(file.path(project_root, "R"), pattern = "^ops-.*[.]R$",
                         full.names = TRUE)
  all_lines <- unlist(lapply(op_files, readLines))
  idx <- grep("[.]register_op[(]", all_lines, perl = TRUE)
  ops <- character(0)
  for (i in idx) {
    for (j in i:(min(i + 2L, length(all_lines)))) {
      m <- regmatches(all_lines[[j]], regexpr('"[^"]+"', all_lines[[j]]))
      if (length(m) > 0L) { ops <- c(ops, gsub('"', "", m)); break }
    }
  }
  unique(ops)
})
cat(sprintf("Known operators: %d\n", length(.known_ops)))

# ---- helpers ----------------------------------------------------------------

.extract_ops <- function(ct) {
  if (is.null(ct)) return(character(0))
  ops <- character(0)
  if (!is.null(ct$operator)) ops <- c(ops, ct$operator)
  for (key in c("all", "any")) {
    if (is.list(ct[[key]])) ops <- c(ops, unlist(lapply(ct[[key]], .extract_ops)))
  }
  if (!is.null(ct[["not"]])) ops <- c(ops, .extract_ops(ct[["not"]]))
  ops
}

.has_dollar_refs <- function(ct) {
  if (is.null(ct)) return(FALSE)
  txt <- yaml::as.yaml(ct)
  grepl("[$][a-zA-Z_]", txt, perl = TRUE)
}

.find_cg_yaml <- function(rule_id) {
  candidates <- c(
    file.path(cg_root, paste0("SDTMIG-", rule_id, ".yaml")),
    file.path(cg_root, paste0(rule_id, ".yaml"))
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0L) return(NA_character_)
  hit[[1L]]
}

.normalise_variable <- function(ct) {
  if (is.null(ct) || length(ct) == 0L) return(NA_character_)
  if (!is.null(ct[["name"]])) return(as.character(ct[["name"]]))
  for (key in c("all", "any")) {
    children <- ct[[key]]
    if (is.list(children)) {
      for (child in children) {
        v <- .normalise_variable(child)
        if (!is.na(v)) return(v)
      }
    }
  }
  if (!is.null(ct[["not"]])) return(.normalise_variable(ct[["not"]]))
  NA_character_
}

# ---- load catalog -----------------------------------------------------------

cat_df <- read.csv(catalog_csv, stringsAsFactors = FALSE)
cib_idx <- which(cat_df$overlap_type == "core-is-better" &
                   cat_df$bucket == "sdtm-ig-v2.0" &
                   cat_df$status == "narrative")
cib <- cat_df[cib_idx, ]
cat(sprintf("Candidate rules: %d\n", nrow(cib)))

# ---- main loop --------------------------------------------------------------

converted <- character(0)
skipped   <- character(0)
failed    <- character(0)

for (i in seq_len(nrow(cib))) {
  rule_id <- cib$rule_id[[i]]
  core_id <- cib$core_id[[i]]

  core_path <- file.path(core_root, paste0(core_id, ".yaml"))
  if (!file.exists(core_path)) {
    skipped <- c(skipped, sprintf("%s (CORE yaml not found: %s)", rule_id, core_id))
    next
  }

  core_yml <- tryCatch(yaml::read_yaml(core_path), error = function(e) NULL)
  if (is.null(core_yml)) {
    skipped <- c(skipped, sprintf("%s (CORE yaml parse failed)", rule_id))
    next
  }

  ct <- core_yml$Check

  # Eligibility checks
  if (!is.null(core_yml$Operations) && length(core_yml$Operations) > 0L) {
    skipped <- c(skipped, sprintf("%s (CORE has Operations: block)", rule_id))
    next
  }
  if (.has_dollar_refs(ct)) {
    skipped <- c(skipped, sprintf("%s (CORE check has $-refs)", rule_id))
    next
  }
  unknown_ops <- setdiff(.extract_ops(ct), .known_ops)
  if (length(unknown_ops) > 0L) {
    skipped <- c(skipped, sprintf("%s (unknown ops: %s)",
                                  rule_id, paste(unknown_ops, collapse = ", ")))
    next
  }
  if (is.null(ct) || length(ct) == 0L) {
    skipped <- c(skipped, sprintf("%s (CORE has empty Check:)", rule_id))
    next
  }

  cg_path <- .find_cg_yaml(rule_id)
  if (is.na(cg_path)) {
    failed <- c(failed, sprintf("%s (CG yaml not found)", rule_id))
    next
  }

  if (dry_run) {
    cat(sprintf("[dry] %s (%s) -> %s\n", rule_id, core_id, basename(cg_path)))
    cat("  check:\n")
    cat(gsub("^", "    ", yaml::as.yaml(ct)), "\n")
    converted <- c(converted, rule_id)
    next
  }

  tryCatch({
    cg_yml <- yaml::read_yaml(cg_path)
    cg_yml$check <- ct
    if (is.null(cg_yml$provenance)) cg_yml$provenance <- list()
    cg_yml$provenance$executability  <- "predicate"
    cg_yml$provenance$core_crosswalk <- core_id
    # Q17: keep variable: in sync with the primary check column
    norm_var <- .normalise_variable(ct)
    if (!is.na(norm_var)) cg_yml$variable <- norm_var
    yaml::write_yaml(cg_yml, cg_path)
    converted <- c(converted, rule_id)
  }, error = function(e) {
    failed <<- c(failed, sprintf("%s (%s)", rule_id, conditionMessage(e)))
  })
}

# ---- summary ----------------------------------------------------------------

cat(sprintf("\n===== port-core.R =====\n"))
cat(sprintf("  converted : %d\n", length(converted)))
cat(sprintf("  skipped   : %d\n", length(skipped)))
cat(sprintf("  failed    : %d\n", length(failed)))
if (length(failed) > 0L) {
  cat("\nFailed:\n")
  for (f in failed) cat("  -", f, "\n")
}
if (length(skipped) > 5L) {
  cat(sprintf("\nSkipped (first 5 of %d):\n", length(skipped)))
  for (s in head(skipped, 5)) cat("  -", s, "\n")
} else if (length(skipped) > 0L) {
  cat("\nSkipped:\n")
  for (s in skipped) cat("  -", s, "\n")
}

# ---- update catalog.csv -----------------------------------------------------

if (!dry_run && length(converted) > 0L) {
  ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  cat_df$status[cat_df$rule_id %in% converted]       <- "predicate"
  cat_df$executability[cat_df$rule_id %in% converted] <- "predicate"
  cat_df$converted_at[cat_df$rule_id %in% converted]  <- ts
  write.csv(cat_df, catalog_csv, row.names = FALSE)
  cat(sprintf("\nUpdated %s (%d rows marked predicate)\n",
              catalog_csv, length(converted)))
}
