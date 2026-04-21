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

# Class-detection cascades through the package's infer_class() and its
# prototype table (R/class-detect.R). Wrapper scopes the package helpers
# so the synth fixture picks a sensible dataset name + class_map spec.

.topic_col_for <- function(cls, ds_name) {
  topic <- switch(toupper(as.character(cls %||% "")),
                  "EVENTS"         = "--TERM",
                  "INTERVENTIONS"  = "--TRT",
                  "FINDINGS"       = "--TESTCD",
                  "FINDINGS ABOUT" = "--OBJ",
                  "RELATIONSHIP"   = "QNAM",
                  NA_character_)
  if (is.na(topic)) return(NA_character_)
  if (startsWith(topic, "--")) {
    return(paste0(substring(toupper(as.character(ds_name)), 1, 2),
                  sub("^--", "", topic)))
  }
  topic
}

pick_dataset_for_scope <- function(scope) {
  exclude <- toupper(as.character(unlist(scope$exclude_domains %||% character())))
  exclude <- exclude[nzchar(exclude)]

  doms_raw <- toupper(as.character(unlist(scope$domains %||% character())))
  # "SUPP--" is a scope template meaning "any SUPP dataset"; synth with a
  # concrete SUPPAE and tag class = RELATIONSHIP so the rule matches.
  if (any(doms_raw == "SUPP--")) {
    return(list(dataset = "SUPPAE", class = "RELATIONSHIP", via = "domain",
                topic_col = "QNAM"))
  }
  doms <- doms_raw[nzchar(doms_raw) & doms_raw != "ALL" & nchar(doms_raw) >= 2L &
                   nchar(doms_raw) <= 8L & !grepl("^SUPP", doms_raw)]
  doms <- setdiff(doms, exclude)
  if (length(doms) > 0L) {
    ds  <- doms[[1L]]
    cls <- herald:::infer_class(ds)
    return(list(dataset = ds, class = cls, via = "domain",
                topic_col = .topic_col_for(cls, ds)))
  }
  .normalise_cls <- function(cls) {
    switch(toupper(cls),
           EVT   = "EVENTS",       INT = "INTERVENTIONS",
           FND   = "FINDINGS",     FAB = "FINDINGS ABOUT",
           SPC   = "SPECIAL PURPOSE", TDM = "TRIAL DESIGN",
           REL   = "RELATIONSHIP",
           ADSL  = "SUBJECT LEVEL ANALYSIS DATASET",
           BDS   = "BASIC DATA STRUCTURE",
           OCCDS = "OCCURRENCE DATA STRUCTURE",
           toupper(cls))
  }
  classes <- as.character(unlist(scope$classes %||% character()))
  classes <- classes[nzchar(classes) & toupper(classes) != "ALL"]
  # Iterate classes in order, picking the first member-dataset that isn't in
  # exclude_domains.
  for (cls in classes) {
    long <- .normalise_cls(cls)
    cand <- names(herald:::.DATASET_CLASS)[
      unname(herald:::.DATASET_CLASS) == long
    ]
    cand <- setdiff(cand, exclude)
    if (length(cand) > 0L) {
      ds <- sort(cand)[[1L]]
      return(list(dataset = ds, class = long, via = "class",
                  topic_col = .topic_col_for(long, ds)))
    }
  }
  list(dataset = NA_character_, class = NA_character_,
       topic_col = NA_character_, via = "none")
}

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

  # Special-case synth for is_not_contained_by with a dotted reference
  # (cross-lookup pattern): build a 2-dataset fixture with a main
  # dataset containing the row-level column and a reference dataset
  # containing the lookup column.
  if (length(lv) == 1L && ops[[1L]] == "is_not_contained_by") {
    var_a <- as.character(lv[[1L]]$name)
    ref   <- as.character(lv[[1L]]$value %||% "")
    if (grepl("^[A-Z][A-Z0-9]{1,7}\\.[A-Z][A-Z0-9_]*$", ref)) {
      parts   <- strsplit(ref, ".", fixed = TRUE)[[1L]]
      ref_dom <- parts[[1L]]
      ref_col <- parts[[2L]]
      scope   <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
      pick    <- pick_dataset_for_scope(scope)
      rule_std <- toupper(as.character(rule$standard %||% ""))
      if (!is.na(pick$dataset)) {
        ds_name <- pick$dataset
        spec <- if (pick$via == "class" && !is.na(pick$class))
          list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
      } else if (grepl("ADAM", rule_std)) {
        ds_name <- "ADSL"; spec <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
      } else {
        ds_name <- "AE"; spec <- NULL
      }
      if (identical(ds_name, ref_dom)) ds_name <- if (ds_name == "AE") "MH" else "AE"
      mk_pair <- function(main_val, ref_val, fire) list(
        rule_id = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets = stats::setNames(
          list(stats::setNames(list(main_val), var_a),
               stats::setNames(list(ref_val),  ref_col)),
          c(ds_name, ref_dom)
        ),
        expected = list(fires = fire,
                        rows = if (isTRUE(fire)) 1L else integer()),
        notes = sprintf("synth cross-lookup: %s <- %s", var_a, ref),
        authored = "pattern-fixture-synth@1",
        spec = spec, `_path` = NA_character_
      )
      return(list(
        pos = mk_pair("TARGET_X", "OTHER_Y", TRUE),
        neg = mk_pair("SAME_VAL", "SAME_VAL", FALSE),
        synth = TRUE
      ))
    }
  }

  # Special-case synth for is_(not_)unique_relationship: build a 2-row
  # dataset where var_b is the same on both rows but var_a differs
  # (positive: fires) / matches (negative: doesn't fire).
  if (length(lv) == 1L && ops[[1L]] == "is_not_unique_relationship") {
    var_b <- as.character(lv[[1L]]$name)
    val   <- lv[[1L]]$value
    var_a <- if (is.list(val)) as.character(val$related_name)
             else              as.character(val)
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via == "class" && !is.na(pick$class)) {
        list(class_map = stats::setNames(list(pick$class), ds_name))
      } else NULL
    } else if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"; spec <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else {
      ds_name <- names(default_fx$pos$datasets)[[1L]]; spec <- default_fx$pos$spec
    }
    pos_cols <- stats::setNames(
      list(c("S1","S2"), c("K1","K1"), c("A","B")),
      c("USUBJID", var_b, var_a)
    )
    neg_cols <- stats::setNames(
      list(c("S1","S2"), c("K1","K1"), c("A","A")),
      c("USUBJID", var_b, var_a)
    )
    mk <- function(cols, fire) list(
      rule_id = as.character(rule$id),
      fixture_type = if (isTRUE(fire)) "positive" else "negative",
      datasets = stats::setNames(list(cols), ds_name),
      expected = list(fires = fire,
                      rows = if (isTRUE(fire)) c(1L, 2L) else integer()),
      notes = "synth for is_not_unique_relationship",
      authored = "pattern-fixture-synth@1",
      spec = spec, `_path` = NA_character_
    )
    return(list(pos = mk(pos_cols, TRUE), neg = mk(neg_cols, FALSE),
                synth = TRUE))
  }

  synth_ops <- c("exists", "not_exists", "empty", "non_empty",
                 "is_missing", "is_present")
  if (length(lv) == 0L || !all(ops %in% synth_ops)) {
    return(list(pos = default_fx$pos, neg = default_fx$neg, synth = FALSE))
  }
  names_req <- vapply(lv, function(l) as.character(l$name %||% ""), character(1L))
  # Classify each leaf: exists / not_exists operate on the column list
  # (metadata); empty / non_empty / is_missing / is_present operate on
  # row values and require the column to be PRESENT regardless of the
  # operator's truth sense.
  is_metadata_op <- ops %in% c("exists", "not_exists")
  # "column wanted present" (i.e. include in pos_cols)
  wants_pres <- ops %in% c("exists", "empty", "non_empty",
                            "is_missing", "is_present")
  # "value wanted empty" (for the positive-fire row content)
  want_null_pos <- ops %in% c("empty", "is_missing")
  want_val_pos  <- ops %in% c("non_empty", "is_present")

  # Pre-expand --VAR names against the dataset prefix we're about to pick, so
  # the synthetic dataset has columns named like the engine will look them up
  # at walk time (e.g. AEREASND when ds_name=AE, not literal --REASND).

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
    # Scope didn't yield a dataset (e.g. scope.classes="ALL" with no
    # domains). Default to a standard-appropriate dataset so herald's
    # ADaM/SDTM symmetry filter doesn't false-reject.
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"
      spec    <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else {
      ds_name <- names(default_fx$pos$datasets)[[1L]]
      spec    <- default_fx$pos$spec
    }
  }

  # Expand --VAR in requested names against the picked dataset's 2-char
  # prefix (matches the engine's own .expand_wildcard_args).
  dom2 <- substring(toupper(as.character(ds_name)), 1, 2)
  names_req <- vapply(names_req, function(nm) {
    if (startsWith(nm, "--")) paste0(dom2, sub("^--", "", nm)) else nm
  }, character(1L), USE.NAMES = FALSE)

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

  # Cell values for the positive (fire) case:
  #   - columns wanted present AND value must be empty (empty op): ""
  #   - columns wanted present AND value must be populated (non_empty): "X"
  #   - columns wanted present, metadata-only (exists): ""
  pos_val_for <- function(i) {
    if (want_null_pos[[i]]) ""
    else if (want_val_pos[[i]]) "X"
    else ""
  }
  # Cell values for the negative (no-fire) case: invert the content.
  neg_val_for <- function(i) {
    if (want_null_pos[[i]]) "X"
    else if (want_val_pos[[i]]) ""
    else ""
  }
  pres_idx <- which(wants_pres)

  # Positive: columns wanted present (with the right content), columns
  # wanted absent (not_exists) left out. Skip the auto-injected USUBJID
  # when the rule itself targets USUBJID (e.g. ADaM-89 not_exists(USUBJID)).
  usubjid_is_target <- "USUBJID" %in% names_req
  pos_cell <- vapply(pres_idx, pos_val_for, character(1L))
  base_cols <- if (usubjid_is_target) list(`_placeholder_` = "x")
                else                   list(USUBJID = "S1")
  pos_cols <- c(
    base_cols,
    topic_extra,
    stats::setNames(as.list(pos_cell), names_req[pres_idx])
  )
  # Negative: metadata ops get their dual (exists -> absent, not_exists ->
  # present); row ops keep their column present but with inverted cell
  # content (so non_empty fires FALSE because value is empty, etc.).
  neg_meta_absent_idx <- which(is_metadata_op & wants_pres)       # exists: omit
  neg_meta_present_idx <- which(is_metadata_op & !wants_pres)     # not_exists: include
  neg_row_idx          <- which(!is_metadata_op)                   # empty/non_empty: include w/ inverted content
  neg_cell <- c(
    rep("", length(neg_meta_present_idx)),
    vapply(neg_row_idx, neg_val_for, character(1L))
  )
  neg_names <- c(names_req[neg_meta_present_idx], names_req[neg_row_idx])
  neg_cols <- c(
    base_cols,
    topic_extra,
    stats::setNames(as.list(neg_cell), neg_names)
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
    # No shared pattern fixture on disk. We can still smoke-check via
    # per-rule synthesis using each rule's own check_tree -- synthesize a
    # minimal default envelope so .synth_rule_fixture has the ds_name
    # + spec skeleton to work from.
    cat("  (no shared fixture; using per-rule synth only)\n")
    fx <- list(
      pos = list(
        rule_id = paste0("__pattern-", pat, "__"),
        fixture_type = "positive",
        datasets = list(AE = list(USUBJID = "S1")),   # arbitrary; synth overrides
        expected = list(fires = TRUE, rows = 1L),
        spec = NULL,
        `_path` = NA_character_
      ),
      neg = list(
        rule_id = paste0("__pattern-", pat, "__"),
        fixture_type = "negative",
        datasets = list(AE = list(USUBJID = "S1")),
        expected = list(fires = FALSE, rows = integer()),
        spec = NULL,
        `_path` = NA_character_
      )
    )
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
