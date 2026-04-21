#!/usr/bin/env Rscript
# tools/rule-authoring/smoke-check.R
# ----------------------------------------------------------------------------
# Run herald::validate() on converted rules against their pattern fixture and
# assert:
#   * positive fixture fires >= 1 time for that rule
#   * negative fixture does not fire for that rule
#
# Usage:
#   Rscript tools/rule-authoring/smoke-check.R --pattern <name>
#   Rscript tools/rule-authoring/smoke-check.R --all
#
# Fixtures live at:
#   tools/rule-authoring/fixtures/<pattern>/{pos.json,neg.json}
#
# No testthat. No full suite. Prints per-rule pass/fail and a summary.

suppressPackageStartupMessages({
  library(jsonlite)
  devtools::load_all(quiet = TRUE)
})

# Class -> representative dataset map derived from P21's def:Class taxonomy.
# Loaded into this script's env; used by .synth_rule_fixture.
local({
  cargs <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", grep("^--file=", cargs, value = TRUE))
  here <- if (length(f) > 0L) dirname(normalizePath(f[[1L]])) else "tools/rule-authoring"
  source(file.path(here, "class-map.R"), local = FALSE)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag) {
  idx <- which(args == flag)
  if (length(idx) == 0L) return(NULL)
  args[[idx + 1L]]
}
pat_name <- get_arg("--pattern")
run_all  <- "--all" %in% args

project_root   <- getwd()
authoring_root <- file.path(project_root, "tools", "rule-authoring")
progress_csv   <- file.path(authoring_root, "progress.csv")
fixtures_root  <- file.path(authoring_root, "fixtures")

stopifnot(file.exists(progress_csv))
prog <- read.csv(progress_csv, stringsAsFactors = FALSE)

if (run_all) {
  patterns <- unique(prog$pattern[!is.na(prog$pattern)])
} else if (!is.null(pat_name)) {
  patterns <- pat_name
} else {
  cat("Usage: smoke-check.R --pattern <name> | --all\n", file = stderr())
  quit(status = 1L)
}

# ---- fixture loading (reuses R/fixture-runner.R helpers) -------------------

.load_pattern_fixtures <- function(pat) {
  pos <- file.path(fixtures_root, pat, "pos.json")
  neg <- file.path(fixtures_root, pat, "neg.json")
  if (!file.exists(pos) || !file.exists(neg)) {
    return(NULL)
  }
  list(
    pos = herald:::.read_fixture(pos),
    neg = herald:::.read_fixture(neg)
  )
}

# ---- run a single rule against a fixture -----------------------------------

.run_rule <- function(rule_id, fx) {
  datasets <- herald:::.fixture_datasets(fx)
  spec     <- herald:::.fixture_spec(fx)
  res <- tryCatch(
    herald::validate(files = datasets, spec = spec, rules = rule_id,
                     quiet = TRUE),
    error = function(e) { message("  error for ", rule_id, ": ",
                                   conditionMessage(e)); NULL }
  )
  if (is.null(res)) return(list(fired = NA, advisory = NA, error = TRUE))
  list(
    fired    = nrow(res$findings[res$findings$status == "fired", ]),
    advisory = nrow(res$findings[res$findings$status == "advisory", ]),
    error    = FALSE
  )
}

# Synthesize a per-rule fixture from the rule's own check_tree for patterns
# whose shared fixture collides (e.g. presence-pair where VAR_A of one rule
# is VAR_B of another). Falls back to the shared fixture when synth isn't
# possible.
#
# Currently supports existence-only trees (exists / not_exists) -- builds a
# minimal BDS dataset where exists-columns are present and not_exists-columns
# are absent (positive) or present (negative).
.extract_leaves_flat <- function(node, acc = list()) {
  if (!is.list(node) || length(node) == 0L) return(acc)
  if (!is.null(node$operator)) return(c(acc, list(node)))
  for (k in c("all","any")) {
    ch <- node[[k]]
    if (!is.null(ch)) for (c in ch) acc <- .extract_leaves_flat(c, acc)
  }
  if (!is.null(node$not)) acc <- .extract_leaves_flat(node$not, acc)
  acc
}

.synth_rule_fixture <- function(rule, default_fx) {
  ct <- rule$check_tree[[1L]]
  # If the rule declares an `expand:` placeholder (xx/y/zz), substitute a
  # concrete probe value so the synth dataset carries the right
  # instantiated column names.
  probe_value <- NULL
  if (is.list(ct) && !is.null(ct$expand)) {
    probe_value <- switch(as.character(ct$expand)[[1L]],
                          xx = "01", y = "1", zz = "01", NULL)
    if (!is.null(probe_value)) {
      ct <- ct; ct$expand <- NULL
      # Replace the placeholder in every leaf's name with the probe.
      .sub <- function(node, ph, v) {
        if (!is.list(node) || length(node) == 0L) return(node)
        if (!is.null(node$name)) node$name <- gsub(ph, v, as.character(node$name), fixed = TRUE)
        for (k in c("all","any")) if (!is.null(node[[k]])) node[[k]] <- lapply(node[[k]], .sub, ph = ph, v = v)
        if (!is.null(node$not)) node$not <- .sub(node$not, ph, v)
        node
      }
      ct <- .sub(ct, as.character(rule$check_tree[[1L]]$expand)[[1L]], probe_value)
    }
  }
  lv <- .extract_leaves_flat(ct)
  ops <- vapply(lv, function(l) l$operator %||% "", character(1L))
  if (length(lv) == 0L || !all(ops %in% c("exists","not_exists"))) {
    return(list(pos = default_fx$pos, neg = default_fx$neg, synth = FALSE))
  }
  names_req <- vapply(lv, function(l) as.character(l$name %||% ""), character(1L))
  wants_pres <- ops == "exists"

  # Resolve the rule's scope into a concrete dataset name + class using the
  # P21-derived class taxonomy in class-map.R. Covers all ADaM and SDTM
  # classes (SUBJECT LEVEL ANALYSIS DATASET, BASIC DATA STRUCTURE, OCCURRENCE
  # DATA STRUCTURE, ADAM OTHER, EVENTS, INTERVENTIONS, FINDINGS,
  # FINDINGS ABOUT, SPECIAL PURPOSE, TRIAL DESIGN, RELATIONSHIP). Explicit
  # scope.domains takes precedence over class fallback.
  scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
  pick  <- pick_dataset_for_scope(scope)

  if (!is.na(pick$dataset)) {
    ds_name <- pick$dataset
    spec    <- if (pick$via == "class" && !is.na(pick$class)) {
      list(class_map = stats::setNames(list(pick$class), ds_name))
    } else NULL
  } else {
    ds_name <- names(default_fx$pos$datasets)[[1L]]
    spec    <- default_fx$pos$spec
  }

  # If the scope resolved via class, include the class's topic variable
  # column in the synth fixture so the dataset is structurally valid for
  # that class (P21's val:Prototype KeyVariables convention: --TERM for
  # EVENTS, --TRT for INTERVENTIONS, --TESTCD for FINDINGS, etc.).
  topic_col <- if (!is.na(pick$topic_col)) pick$topic_col else NA_character_

  # Include the class's topic variable column in both fixtures so the
  # dataset looks like a valid member of its class at runtime.
  topic_extra <- if (!is.na(topic_col) && !topic_col %in% names_req) {
    stats::setNames(list(""), topic_col)
  } else list()

  pos_cols <- c(
    list(USUBJID = "S1"),
    topic_extra,
    stats::setNames(rep(list(""), sum(wants_pres)), names_req[wants_pres])
  )
  neg_cols <- c(
    list(USUBJID = "S1"),
    topic_extra,
    stats::setNames(rep(list(""), length(names_req)), names_req)
  )

  mk_fx <- function(cols, fire) {
    list(
      rule_id      = as.character(rule$id),
      fixture_type = if (isTRUE(fire)) "positive" else "negative",
      datasets     = stats::setNames(list(cols), ds_name),
      expected     = list(fires = fire,
                          rows  = if (isTRUE(fire)) 1L else integer()),
      notes        = "synth-from-check_tree",
      authored     = "pattern-fixture-synth@1",
      spec         = spec,
      `_path`      = NA_character_
    )
  }
  list(pos = mk_fx(pos_cols, TRUE), neg = mk_fx(neg_cols, FALSE), synth = TRUE)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---- main ------------------------------------------------------------------

all_rows <- list()

for (pat in patterns) {
  cat(sprintf("\n=== smoke-checking pattern: %s ===\n", pat))
  fx <- .load_pattern_fixtures(pat)
  if (is.null(fx)) {
    cat("  [skip] no fixtures at ",
        file.path(fixtures_root, pat), "\n", sep = "")
    next
  }
  rids <- prog$rule_id[!is.na(prog$pattern) & prog$pattern == pat &
                       prog$status == "predicate"]
  cat(sprintf("  rules to check: %d\n", length(rids)))
  cat_catalog <- readRDS(system.file("rules", "rules.rds", package = "herald"))
  pass <- 0L; fail <- 0L
  for (rid in rids) {
    # First try the shared fixture.
    r_pos <- .run_rule(rid, fx$pos)
    r_neg <- .run_rule(rid, fx$neg)
    ok <- !isTRUE(r_pos$error) && !isTRUE(r_neg$error) &&
          r_pos$fired >= 1L && r_neg$fired == 0L
    used_synth <- FALSE

    # If the shared fixture didn't work (typically because another rule in
    # the same pattern needs conflicting columns), fall back to synthesising
    # a per-rule fixture from the rule's own check_tree.
    if (!ok) {
      rule_row <- cat_catalog[cat_catalog$id == rid, , drop = FALSE]
      if (nrow(rule_row) > 0L) {
        synth <- .synth_rule_fixture(rule_row, fx)
        if (isTRUE(synth$synth)) {
          r_pos <- .run_rule(rid, synth$pos)
          r_neg <- .run_rule(rid, synth$neg)
          ok <- !isTRUE(r_pos$error) && !isTRUE(r_neg$error) &&
                r_pos$fired >= 1L && r_neg$fired == 0L
          used_synth <- TRUE
        }
      }
    }

    if (ok) {
      pass <- pass + 1L
    } else {
      fail <- fail + 1L
      reason <- if (isTRUE(r_pos$error) || isTRUE(r_neg$error)) "error"
                else if (r_pos$fired < 1L) "positive did not fire"
                else if (r_neg$fired > 0L) "negative fired"
                else "unknown"
      cat(sprintf("  FAIL %s -- %s (pos.fired=%s, neg.fired=%s, synth=%s)\n",
                  rid, reason, r_pos$fired, r_neg$fired, used_synth))
    }
    all_rows[[length(all_rows) + 1L]] <- data.frame(
      pattern   = pat, rule_id = rid,
      pos_fired = as.integer(r_pos$fired),
      neg_fired = as.integer(r_neg$fired),
      fixture   = if (used_synth) "synth" else "shared",
      status    = if (ok) "pass" else "fail",
      stringsAsFactors = FALSE
    )
  }
  cat(sprintf("  pattern %s: %d pass, %d fail\n", pat, pass, fail))
}

if (length(all_rows) > 0L) {
  summary_df <- do.call(rbind, all_rows)
  out <- file.path(authoring_root, "smoke-latest.csv")
  write.csv(summary_df, out, row.names = FALSE)
  cat(sprintf("\nsummary:\n  total: %d\n  pass : %d\n  fail : %d\n",
              nrow(summary_df),
              sum(summary_df$status == "pass"),
              sum(summary_df$status == "fail")))
  cat(sprintf("wrote %s\n", out))
}
