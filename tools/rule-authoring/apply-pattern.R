#!/usr/bin/env Rscript
# tools/rule-authoring/apply-pattern.R
# ----------------------------------------------------------------------------
# Apply a pattern template to a list of rule YAMLs, in place.
#
# Each pattern lives at tools/rule-authoring/patterns/<pattern>.md with a
# fenced `check_tree:` YAML block that describes the concrete check for rules
# matching the pattern. For patterns with slots (e.g. %Variable%, %Reference%),
# the mapping CSV at patterns/<pattern>.ids provides per-rule substitutions.
#
# Usage:
#   Rscript tools/rule-authoring/apply-pattern.R \
#       --pattern <name> \
#       --ids     <csv>          # 1-column CSV of rule_ids, or multi-col for slots
#       [--dry-run]              # print without writing
#
# The CSV header row determines slot names. First column is always `rule_id`;
# any additional columns become substitutions applied to the template.
#
# Idempotent: rules already at executability=predicate are skipped.

suppressPackageStartupMessages({
  library(yaml)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag) {
  idx <- which(args == flag)
  if (length(idx) == 0L) return(NULL)
  args[[idx + 1L]]
}
dry_run <- "--dry-run" %in% args
pat_name <- get_arg("--pattern")
ids_csv  <- get_arg("--ids")
if (is.null(pat_name) || is.null(ids_csv)) {
  cat("Usage: apply-pattern.R --pattern <name> --ids <csv> [--dry-run]\n",
      file = stderr())
  quit(status = 1L)
}

project_root   <- getwd()
handauth_root  <- file.path(project_root, "tools", "handauthored", "cdisc")
authoring_root <- file.path(project_root, "tools", "rule-authoring")
pattern_md     <- file.path(authoring_root, "patterns", paste0(pat_name, ".md"))
progress_csv   <- file.path(authoring_root, "catalog.csv")

stopifnot(file.exists(pattern_md), file.exists(ids_csv))

# ---- parse pattern template ------------------------------------------------
# Look for a block:
#   ```yaml check_tree
#   ...
#   ```
# after a "## herald check_tree template" heading. Parse the YAML inside.

.read_template <- function(path) {
  lines <- readLines(path)
  in_block <- FALSE
  block_type <- NULL
  buf <- list()
  cur <- character()
  for (ln in lines) {
    if (grepl("^```yaml(\\s+(check_tree|fixture_spec|p21_primitive))?\\s*$", ln)) {
      in_block <- TRUE
      block_type <- sub("^```yaml\\s*", "", ln)
      if (!nzchar(block_type)) block_type <- "unknown"
      cur <- character()
      next
    }
    if (in_block && grepl("^```\\s*$", ln)) {
      buf[[block_type]] <- paste(cur, collapse = "\n")
      in_block <- FALSE
      block_type <- NULL
      next
    }
    if (in_block) cur <- c(cur, ln)
  }
  if (is.null(buf$check_tree)) {
    stop(sprintf("pattern %s is missing a ```yaml check_tree block", path))
  }
  buf
}

tmpl <- .read_template(pattern_md)
cat(sprintf("loaded pattern %s (blocks: %s)\n",
            pat_name, paste(names(tmpl), collapse = ",")))

# ---- load ids + slots ------------------------------------------------------

ids <- read.csv(ids_csv, stringsAsFactors = FALSE)
stopifnot("rule_id" %in% names(ids))
cat(sprintf("  applying to %d rules\n", nrow(ids)))

# ---- locate each YAML ------------------------------------------------------

.find_yaml <- function(rule_id) {
  # Try adam-v5.0/ADaM-<id>.yaml, sdtm-ig-v2.0/SDTMIG-<id>.yaml, and a few others.
  candidates <- c(
    file.path(handauth_root, "adam-v5.0",     paste0("ADaM-",   rule_id, ".yaml")),
    file.path(handauth_root, "sdtm-ig-v2.0",  paste0("SDTMIG-", rule_id, ".yaml")),
    file.path(handauth_root, "sdtm-ig-v2.0",  paste0(rule_id,   ".yaml")),
    file.path(handauth_root, "adam-v5.0",     paste0(rule_id,   ".yaml"))
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0L) return(NA_character_)
  hit[[1L]]
}

# ---- render template with slots --------------------------------------------
# The check_tree block may contain %Slot% placeholders; each non-rule_id column
# of `ids` becomes a slot value. Slot names are case-insensitive on the left.

.render <- function(tmpl_text, slots) {
  out <- tmpl_text
  for (nm in names(slots)) {
    pat <- paste0("%", nm, "%")
    out <- gsub(pat, as.character(slots[[nm]]), out, fixed = TRUE)
  }
  out
}

# ---- normalise the variable: field (Q17) ------------------------------------
# Extracts the first `name` leaf from a rendered check_tree and returns it as
# the canonical variable name. Falls back to NA_character_ when no leaf has a
# `name` slot (e.g. pure metadata rules). Result is used to overwrite the
# prose `variable:` field so it matches what emit_findings actually reports.
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

# ---- write the check block into a YAML file --------------------------------
# Preserves everything except the top-level `check:` block, the
# `provenance.executability` field, and (Q17) the `variable:` field.

.rewrite_yaml <- function(path, new_check_yaml) {
  y <- yaml::read_yaml(path)
  ct <- yaml::yaml.load(new_check_yaml)
  y$check <- ct
  if (is.null(y$provenance)) y$provenance <- list()
  y$provenance$executability <- "predicate"
  # Q17: overwrite variable: with the primary column name from the check_tree.
  norm_var <- .normalise_variable(ct)
  if (!is.na(norm_var)) y$variable <- norm_var
  # Round-trip; keep strings block-folded when possible.
  yaml::write_yaml(y, path)
}

# ---- main loop -------------------------------------------------------------

rendered_ct <- tmpl$check_tree
slot_cols <- setdiff(names(ids), "rule_id")
skipped <- character()
converted <- character()
failed <- character()

for (i in seq_len(nrow(ids))) {
  rid  <- as.character(ids$rule_id[[i]])
  slots <- if (length(slot_cols) > 0L) as.list(ids[i, slot_cols, drop = FALSE])
            else list()
  check_yaml <- .render(rendered_ct, slots)

  path <- .find_yaml(rid)
  if (is.na(path)) {
    failed <- c(failed, sprintf("%s (yaml not found)", rid))
    next
  }
  prev <- yaml::read_yaml(path)
  if (identical(prev$provenance$executability %||% "", "predicate")) {
    skipped <- c(skipped, rid)
    next
  }
  if (dry_run) {
    cat(sprintf("[dry] %s (%s) -> %s\n",
                rid, pat_name, basename(path)))
    cat("  ", gsub("\n", "\n  ", check_yaml), "\n", sep = "")
  } else {
    tryCatch({
      .rewrite_yaml(path, check_yaml)
      converted <- c(converted, rid)
    }, error = function(e) {
      failed <<- c(failed, sprintf("%s (%s)", rid, conditionMessage(e)))
    })
  }
}

`%||%` <- function(a, b) if (is.null(a) || all(is.na(a))) b else a

cat(sprintf("\npattern: %s\n", pat_name))
cat(sprintf("  converted: %d\n", length(converted)))
cat(sprintf("  skipped (already predicate): %d\n", length(skipped)))
cat(sprintf("  failed: %d\n", length(failed)))
if (length(failed) > 0L) {
  cat("\nFailed details:\n")
  for (f in failed) cat("  -", f, "\n")
}

# ---- update progress.csv ---------------------------------------------------

if (!dry_run && length(converted) > 0L && file.exists(progress_csv)) {
  prog <- read.csv(progress_csv, stringsAsFactors = FALSE)
  prog$pattern[prog$rule_id %in% converted] <- pat_name
  prog$status [prog$rule_id %in% converted] <- "predicate"
  prog$converted_at[prog$rule_id %in% converted] <-
    format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")

  # preview: first leaf rendered from template
  tmpl_preview <- gsub("\\s+", " ", trimws(rendered_ct))
  for (i in which(prog$rule_id %in% converted)) {
    rid <- prog$rule_id[[i]]
    slots <- if (length(slot_cols) > 0L) {
      as.list(ids[ids$rule_id == rid, slot_cols, drop = FALSE][1L, ])
    } else list()
    prog$check_tree_preview[[i]] <- .render(tmpl_preview, slots)
  }

  write.csv(prog, progress_csv, row.names = FALSE)
  cat(sprintf("\nupdated %s (%d rows marked predicate)\n",
              progress_csv, length(converted)))
}
