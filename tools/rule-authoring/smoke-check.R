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
  doms <- doms_raw[nzchar(doms_raw) & doms_raw != "ALL" & nchar(doms_raw) >= 2L &
                   nchar(doms_raw) <= 8L & !grepl("^SUPP", doms_raw)]
  doms <- setdiff(doms, exclude)
  if (length(doms) > 0L) {
    ds  <- doms[[1L]]
    # Prefer the rule's declared scope.classes over infer_class's guess.
    # The rule author pinned both the domain and its class; honour that
    # pairing even when herald's taxonomy would classify the domain
    # differently (e.g. CG0201 targets RELREC with classes=SPC, even
    # though RELREC normally classifies as RELATIONSHIP). Only fall back
    # to infer_class when the rule didn't declare a class.
    declared <- as.character(unlist(scope$classes %||% character()))
    declared <- declared[nzchar(declared) & toupper(declared) != "ALL"]
    if (length(declared) > 0L) {
      cls <- .normalise_cls(declared[[1L]])
    } else {
      cls <- herald:::infer_class(ds)
    }
    return(list(dataset = ds, class = cls, via = "domain",
                topic_col = .topic_col_for(cls, ds)))
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

# Run a rule against pre-built data.frames (with column-level attr()s, e.g.
# labels) and an optional spec list. Bypasses the JSON fixture loader path,
# which promotes columns-of-vectors and discards attributes.
.run_rule_raw <- function(rule_id, datasets, spec_list) {
  spec <- if (is.null(spec_list) || length(spec_list) == 0L) NULL else {
    cm <- spec_list$class_map
    structure(
      list(ds_spec = data.frame(
        dataset = toupper(names(cm)),
        class   = vapply(cm, function(x) as.character(x)[[1L]], character(1L)),
        stringsAsFactors = FALSE
      )),
      class = c("herald_spec", "list")
    )
  }
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
  probe_map <- c(xx = "01", y = "1", zz = "01", w = "1", stem = "ATOX")
  if (is.list(ct) && !is.null(ct$expand)) {
    # Parse expand into one or more placeholders (scalar "xx", list, or
    # comma/pipe separated "xx,y"). Substitute each with a probe value
    # so the synth dataset carries the right instantiated column names.
    raw <- as.character(unlist(ct$expand))
    if (length(raw) == 1L && grepl("[,;| ]", raw)) {
      raw <- trimws(strsplit(raw, "[,;| ]+", perl = TRUE)[[1L]])
    }
    phs <- raw[nzchar(raw) & raw %in% names(probe_map)]
    if (length(phs) > 0L) {
      ct <- ct; ct$expand <- NULL
      .sub <- function(node, ph, v) {
        if (!is.list(node) || length(node) == 0L) return(node)
        if (!is.null(node$name)) node$name <- gsub(ph, v, as.character(node$name), fixed = TRUE)
        for (k in c("all","any")) if (!is.null(node[[k]])) node[[k]] <- lapply(node[[k]], .sub, ph = ph, v = v)
        if (!is.null(node$not)) node$not <- .sub(node$not, ph, v)
        node
      }
      # Substitute longest placeholders first so `xx` inside a name
      # isn't clobbered by a later one-char `y` substitution.
      phs <- phs[order(-nchar(phs))]
      for (p in phs) ct <- .sub(ct, p, probe_map[[p]])
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
        spec <- if (pick$via %in% c("class","domain") && !is.na(pick$class) && nzchar(pick$class))
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
      spec    <- if (pick$via %in% c("class","domain") && !is.na(pick$class) && nzchar(pick$class)) {
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

  # Special-case synth for value-conditional-literal-assert pattern:
  # {all: [is_contained_by(cond_var, [set]), not_equal_to(target, 'LIT')]}
  # Positive row 1: cond in set, target != LIT (fires). Row 2: cond not in
  # set (blocks). Negative: both rows compliant (cond in set, target == LIT).
  if (length(lv) == 2L &&
      ops[[1L]] == "is_contained_by" &&
      ops[[2L]] == "not_equal_to" &&
      !isFALSE(lv[[2L]]$value_is_literal)) {
    cond_var <- as.character(lv[[1L]]$name)
    cond_set <- as.character(unlist(lv[[1L]]$value))
    target   <- as.character(lv[[2L]]$name)
    lit      <- as.character(lv[[2L]]$value)
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via %in% c("class","domain") &&
                     !is.na(pick$class) && nzchar(pick$class))
        list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
    } else {
      ds_name <- "DS"; spec <- NULL
    }
    set_val <- cond_set[[1L]]
    out_of_set <- "ZZZ_NOT_IN_SET"
    mk <- function(fire) {
      cols_list <- list(USUBJID = c("S1", "S2"))
      if (isTRUE(fire)) {
        cols_list[[cond_var]] <- c(set_val, out_of_set)
        cols_list[[target]]   <- c("OTHER_VALUE_NOT_LIT", lit)
      } else {
        cols_list[[cond_var]] <- c(set_val, set_val)
        cols_list[[target]]   <- c(lit, lit)
      }
      list(
        rule_id      = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets     = stats::setNames(list(cols_list), ds_name),
        expected     = list(fires = fire,
                            rows = if (isTRUE(fire)) 1L else integer()),
        notes        = "synth value-conditional-literal-assert",
        authored     = "pattern-fixture-synth@1",
        spec         = spec, `_path` = NA_character_
      )
    }
    return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
  }

  # Special-case synth for value-compare-subject-ordinal pattern:
  # {all: [non_empty(row_var), <ordinal_op>_by_key(row_var, ref_ds, ref_col, key=USUBJID)]}
  # Positive: row date violates the ordinal relation. Negative: compliant.
  if (length(lv) == 2L &&
      ops[[1L]] == "non_empty" &&
      ops[[2L]] %in% c("less_than_by_key","less_than_or_equal_by_key",
                       "greater_than_by_key","greater_than_or_equal_by_key")) {
    row_var <- as.character(lv[[1L]]$name)
    ref_ds  <- toupper(as.character(lv[[2L]]$reference_dataset %||% "DM"))
    ref_col <- as.character(lv[[2L]]$reference_column %||% "")
    cmp_op  <- ops[[2L]]
    if (nzchar(ref_col)) {
      scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
      pick  <- pick_dataset_for_scope(scope)
      rule_std <- toupper(as.character(rule$standard %||% ""))
      if (!is.na(pick$dataset) && pick$dataset != ref_ds) {
        ds_name <- pick$dataset
        spec    <- if (pick$via %in% c("class","domain") &&
                       !is.na(pick$class) && nzchar(pick$class))
          list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
      } else {
        ds_name <- "DS"; spec <- NULL
      }
      dom2 <- substring(toupper(as.character(ds_name)), 1, 2)
      exp <- function(x) if (startsWith(x, "--")) paste0(dom2, sub("^--", "", x)) else x
      row_var_r <- exp(row_var)
      mk <- function(fire) {
        if (cmp_op %in% c("less_than_by_key","less_than_or_equal_by_key")) {
          pos_row_val <- "2023-01-01"; neg_row_val <- "2025-01-01"
          ref_val     <- "2024-01-01"
        } else {
          pos_row_val <- "2025-01-01"; neg_row_val <- "2023-01-01"
          ref_val     <- "2024-01-01"
        }
        main_cols <- list(USUBJID = c("S1","S2"))
        main_cols[[row_var_r]] <- if (isTRUE(fire)) c(pos_row_val, pos_row_val)
                                  else              c(neg_row_val, neg_row_val)
        ref_cols  <- list(USUBJID = c("S1","S2"))
        ref_cols[[ref_col]] <- c(ref_val, ref_val)
        datasets <- list(main = main_cols, ref = ref_cols)
        names(datasets) <- c(ds_name, ref_ds)
        list(
          rule_id      = as.character(rule$id),
          fixture_type = if (isTRUE(fire)) "positive" else "negative",
          datasets     = datasets,
          expected     = list(fires = fire,
                              rows = if (isTRUE(fire)) c(1L,2L) else integer()),
          notes        = "synth value-compare-subject-ordinal",
          authored     = "pattern-fixture-synth@1",
          spec         = spec, `_path` = NA_character_
        )
      }
      return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
    }
  }

  # Special-case synth for value-study-day pattern:
  # single-leaf study_day_mismatch op.
  if (length(lv) == 1L && ops[[1L]] == "study_day_mismatch") {
    sdy_var    <- as.character(lv[[1L]]$name)
    ref_ds     <- toupper(as.character(lv[[1L]]$reference_dataset %||% "DM"))
    ref_col    <- as.character(lv[[1L]]$reference_column %||% "RFSTDTC")
    target_dtc <- as.character(lv[[1L]]$target_date_column %||% "")
    if (nzchar(target_dtc)) {
      scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
      pick  <- pick_dataset_for_scope(scope)
      rule_std <- toupper(as.character(rule$standard %||% ""))
      if (!is.na(pick$dataset) && pick$dataset != ref_ds) {
        ds_name <- pick$dataset
        spec    <- if (pick$via %in% c("class","domain") &&
                       !is.na(pick$class) && nzchar(pick$class))
          list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
      } else {
        ds_name <- "AE"; spec <- NULL
      }
      dom2 <- substring(toupper(as.character(ds_name)), 1, 2)
      exp <- function(x) if (startsWith(x, "--")) paste0(dom2, sub("^--", "", x)) else x
      sdy_r <- exp(sdy_var); target_r <- exp(target_dtc)
      mk <- function(fire) {
        anchor <- "2024-01-10"; target <- "2024-01-11"
        correct_day <- 2L
        stored_day <- if (isTRUE(fire)) 99L else correct_day
        main_cols <- list(USUBJID = c("S1","S2"))
        main_cols[[target_r]] <- c(target, target)
        main_cols[[sdy_r]]    <- c(stored_day, stored_day)
        ref_cols <- list(USUBJID = c("S1","S2"))
        ref_cols[[ref_col]] <- c(anchor, anchor)
        datasets <- list(main = main_cols, ref = ref_cols)
        names(datasets) <- c(ds_name, ref_ds)
        list(
          rule_id      = as.character(rule$id),
          fixture_type = if (isTRUE(fire)) "positive" else "negative",
          datasets     = datasets,
          expected     = list(fires = fire,
                              rows = if (isTRUE(fire)) c(1L,2L) else integer()),
          notes        = "synth value-study-day",
          authored     = "pattern-fixture-synth@1",
          spec         = spec, `_path` = NA_character_
        )
      }
      return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
    }
  }

  # Special-case synth for value-conditional-null-crossref pattern:
  # {all: [non_empty(target), ref_col_empty(USUBJID, DM.RFCOL)]}.
  # Positive: main dataset row has target populated AND its USUBJID has
  # no matching populated RFCOL in DM (fires). Negative: DM has populated
  # RFCOL for the subject (no fire).
  if (length(lv) == 2L &&
      ops[[1L]] == "non_empty" &&
      ops[[2L]] == "ref_col_empty") {
    target <- as.character(lv[[1L]]$name)
    # Parse ref arg -- prefer the structured form (reference_dataset /
    # reference_column) since the dotted string would be eagerly resolved
    # by substitute_crossrefs.
    rv <- lv[[2L]]$value
    ref_ds  <- NA_character_; ref_col <- NA_character_
    if (is.list(rv)) {
      ref_ds  <- toupper(as.character(rv$reference_dataset %||% ""))
      ref_col <- as.character(rv$reference_column %||% rv$column %||% "")
    } else if (is.character(rv) && length(rv) == 1L &&
               grepl("^[A-Z][A-Z0-9]*\\.[A-Z][A-Z0-9_]*$", rv)) {
      parts   <- strsplit(rv, ".", fixed = TRUE)[[1L]]
      ref_ds  <- parts[[1L]]
      ref_col <- parts[[2L]]
    }
    if (!is.na(ref_ds) && nzchar(ref_ds) && nzchar(ref_col)) {
      scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
      pick  <- pick_dataset_for_scope(scope)
      rule_std <- toupper(as.character(rule$standard %||% ""))
      if (!is.na(pick$dataset) && pick$dataset != ref_ds) {
        ds_name <- pick$dataset
        spec    <- if (pick$via %in% c("class","domain") &&
                       !is.na(pick$class) && nzchar(pick$class))
          list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
      } else {
        ds_name <- "AE"; spec <- NULL
      }
      dom2 <- substring(toupper(as.character(ds_name)), 1, 2)
      exp <- function(x) if (startsWith(x, "--")) paste0(dom2, sub("^--", "", x)) else x
      target_r <- exp(target)
      mk <- function(fire) {
        main_cols <- list(
          USUBJID = c("S1", "S2")
        )
        main_cols[[target_r]] <- c("VAL", "VAL")
        # DM: Subject S1 has RFCOL populated (negative); Subject S2 has
        # RFCOL null (positive fires for S2's row in main).
        if (isTRUE(fire)) {
          ref_cols <- list(
            USUBJID = c("S1", "S2"),
            X       = c("POP", "")
          )
          names(ref_cols)[2] <- ref_col
        } else {
          ref_cols <- list(
            USUBJID = c("S1", "S2"),
            X       = c("POP", "POP")
          )
          names(ref_cols)[2] <- ref_col
        }
        datasets <- list(main = main_cols, ref = ref_cols)
        names(datasets) <- c(ds_name, ref_ds)
        list(
          rule_id      = as.character(rule$id),
          fixture_type = if (isTRUE(fire)) "positive" else "negative",
          datasets     = datasets,
          expected     = list(fires = fire,
                              rows = if (isTRUE(fire)) c(1L,2L) else integer()),
          notes        = "synth value-conditional-null-crossref",
          authored     = "pattern-fixture-synth@1",
          spec         = spec, `_path` = NA_character_
        )
      }
      return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
    }
  }

  # Special-case synth for value-conditional-populated-required pattern:
  # {all: [non_empty(cond), empty(target)]} -- fires when cond populated
  # AND target empty (target was required because cond was populated).
  if (length(lv) == 2L &&
      ops[[1L]] == "non_empty" &&
      ops[[2L]] == "empty") {
    cond_var <- as.character(lv[[1L]]$name)
    target   <- as.character(lv[[2L]]$name)
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via %in% c("class","domain") &&
                     !is.na(pick$class) && nzchar(pick$class))
        list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
    } else if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"; spec <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else {
      ds_name <- "AE"; spec <- NULL
    }
    dom2 <- substring(toupper(as.character(ds_name)), 1, 2)
    exp <- function(x) if (startsWith(x, "--")) paste0(dom2, sub("^--", "", x)) else x
    cond_var_r <- exp(cond_var); target_r <- exp(target)
    mk <- function(fire) {
      cols_list <- list(USUBJID = c("S1", "S2"))
      cols_list[[cond_var_r]] <- c("X", "X")
      cols_list[[target_r]]   <- if (isTRUE(fire)) c("", "") else c("VAL", "VAL")
      list(
        rule_id      = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets     = stats::setNames(list(cols_list), ds_name),
        expected     = list(fires = fire,
                            rows = if (isTRUE(fire)) c(1L,2L) else integer()),
        notes        = "synth value-conditional-populated-required",
        authored     = "pattern-fixture-synth@1",
        spec         = spec, `_path` = NA_character_
      )
    }
    return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
  }

  # Special-case synth for value-conditional-empty-noteq-lit pattern:
  # {all: [empty(cond_var), equal_to(target, 'LIT')]} -- fires when cond
  # is empty AND target IS the forbidden literal. Positive row 1: cond
  # empty + target == LIT (fires). Negative: cond empty + target != LIT.
  if (length(lv) == 2L &&
      ops[[1L]] == "empty" &&
      ops[[2L]] == "equal_to" &&
      !isFALSE(lv[[2L]]$value_is_literal)) {
    cond_var <- as.character(lv[[1L]]$name)
    target   <- as.character(lv[[2L]]$name)
    lit      <- as.character(lv[[2L]]$value)
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via %in% c("class","domain") &&
                     !is.na(pick$class) && nzchar(pick$class))
        list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
    } else if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"; spec <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else {
      ds_name <- "TA"; spec <- NULL
    }
    dom2 <- substring(toupper(as.character(ds_name)), 1, 2)
    exp <- function(x) if (startsWith(x, "--")) paste0(dom2, sub("^--", "", x)) else x
    cond_var_r <- exp(cond_var); target_r <- exp(target)
    mk <- function(fire) {
      cols_list <- list(USUBJID = c("S1", "S2"))
      cols_list[[cond_var_r]] <- c("", "")
      cols_list[[target_r]]   <- if (isTRUE(fire)) c(lit, lit) else c("OTHER", "OTHER")
      list(
        rule_id      = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets     = stats::setNames(list(cols_list), ds_name),
        expected     = list(fires = fire,
                            rows = if (isTRUE(fire)) c(1L,2L) else integer()),
        notes        = "synth value-conditional-empty-noteq-lit",
        authored     = "pattern-fixture-synth@1",
        spec         = spec, `_path` = NA_character_
      )
    }
    return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
  }

  # Special-case synth for value-conditional-populated-eq-lit pattern:
  # {all: [non_empty(cond_var), not_equal_to(target, 'LIT')]}.
  # Positive row 1: cond populated + target != LIT (violation). Row 2:
  # cond empty (guard blocks). Negative: cond populated on both rows, but
  # target equals LIT (compliant).
  if (length(lv) == 2L &&
      ops[[1L]] == "non_empty" &&
      ops[[2L]] == "not_equal_to" &&
      !isFALSE(lv[[2L]]$value_is_literal)) {
    cond_var <- as.character(lv[[1L]]$name)
    target   <- as.character(lv[[2L]]$name)
    lit      <- as.character(lv[[2L]]$value)
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via %in% c("class","domain") &&
                     !is.na(pick$class) && nzchar(pick$class))
        list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
    } else if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"; spec <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else {
      ds_name <- "DM"; spec <- NULL
    }
    dom2 <- substring(toupper(as.character(ds_name)), 1, 2)
    exp <- function(x) if (startsWith(x, "--")) paste0(dom2, sub("^--", "", x)) else x
    cond_var_r <- exp(cond_var); target_r <- exp(target)
    mk <- function(fire) {
      cols_list <- list(USUBJID = c("S1", "S2"))
      if (isTRUE(fire)) {
        cols_list[[cond_var_r]] <- c("X", "")
        cols_list[[target_r]]   <- c("OTHER", lit)
      } else {
        cols_list[[cond_var_r]] <- c("X", "X")
        cols_list[[target_r]]   <- c(lit, lit)
      }
      list(
        rule_id      = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets     = stats::setNames(list(cols_list), ds_name),
        expected     = list(fires = fire,
                            rows = if (isTRUE(fire)) 1L else integer()),
        notes        = "synth value-conditional-populated-eq-lit",
        authored     = "pattern-fixture-synth@1",
        spec         = spec, `_path` = NA_character_
      )
    }
    return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
  }

  # Special-case synth for value-conditional-null-eq pattern:
  # {all: [equal_to(cond_var, LIT), non_empty(target_var)]} where
  # value_is_literal is TRUE (or not set, defaulting to literal).
  # Positive: row 1 has cond_var == LIT and target populated (fires).
  # Negative: row 1 has cond_var == LIT and target empty (no fire).
  if (length(lv) == 2L &&
      ops[[1L]] == "equal_to" &&
      ops[[2L]] == "non_empty" &&
      !isFALSE(lv[[1L]]$value_is_literal)) {
    cond_var <- as.character(lv[[1L]]$name)
    cond_lit <- as.character(lv[[1L]]$value)
    target   <- as.character(lv[[2L]]$name)
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via %in% c("class", "domain") &&
                     !is.na(pick$class) && nzchar(pick$class))
        list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
    } else {
      ds_name <- "DS"; spec <- NULL
    }
    topic_col <- if (!is.na(pick$topic_col)) pick$topic_col else NA_character_
    # Expand --VAR wildcards against the picked dataset's 2-char prefix
    # so synthetic columns match the names the walker will look up.
    dom2 <- substring(toupper(as.character(ds_name)), 1, 2)
    exp <- function(x) if (startsWith(x, "--")) paste0(dom2, sub("^--", "", x)) else x
    cond_var_r <- exp(cond_var); target_r <- exp(target)
    mk <- function(fire) {
      cols_list <- list(USUBJID = c("S1", "S2"))
      cols_list[[cond_var_r]] <- c(cond_lit, cond_lit)
      cols_list[[target_r]]   <- if (isTRUE(fire)) c("VAL", "VAL") else c("", "")
      if (!is.na(topic_col) && !topic_col %in% names(cols_list)) {
        cols_list[[topic_col]] <- c("T", "T")
      }
      list(
        rule_id      = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets     = stats::setNames(list(cols_list), ds_name),
        expected     = list(fires = fire,
                            rows = if (isTRUE(fire)) 1L else integer()),
        notes        = "synth value-conditional-null-eq",
        authored     = "pattern-fixture-synth@1",
        spec         = spec, `_path` = NA_character_
      )
    }
    return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
  }

  # Special-case synth for value-conditional-regex-match pattern:
  # {all: [empty(cond1), empty(cond2), matches_regex(target, pattern)]}.
  # Positive: 2-row fixture; row 1 has both conds null + target matches
  # pattern (fires); row 2 has cond1 populated (guard blocks). Negative:
  # both conds null but target does NOT match pattern.
  if (length(lv) == 3L &&
      ops[[1L]] == "empty" &&
      ops[[2L]] == "empty" &&
      ops[[3L]] == "matches_regex") {
    cond1    <- as.character(lv[[1L]]$name)
    cond2    <- as.character(lv[[2L]]$name)
    target   <- as.character(lv[[3L]]$name)
    pattern  <- as.character(lv[[3L]]$value)
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via %in% c("class","domain") &&
                     !is.na(pick$class) && nzchar(pick$class))
        list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
    } else if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"; spec <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else {
      ds_name <- "RELREC"; spec <- NULL
    }
    # Pick a value that matches the regex (positive) and one that doesn't
    # (negative). `.*SEQ` -> "AESEQ" matches, "AETERM" does not.
    matching_val <- if (grepl("SEQ", pattern)) "AESEQ" else "MATCH"
    nonmatching_val <- if (grepl("SEQ", pattern)) "AETERM" else "NOMATCH"
    mk <- function(fire) {
      cols_list <- list(USUBJID = c("", ""))
      if (cond1 != "USUBJID") cols_list[[cond1]] <- c("", "")
      if (cond2 != "USUBJID" && cond2 != cond1) cols_list[[cond2]] <- c("", "")
      if (isTRUE(fire)) {
        # Row 1: both null + target matches pattern
        cols_list[[target]] <- c(matching_val, matching_val)
        # Row 2: populate cond1 to block the guard
        cols_list[[cond1]][2L] <- "X_POPULATED"
      } else {
        # Both rows have both conds null but target does NOT match pattern
        cols_list[[target]] <- c(nonmatching_val, nonmatching_val)
      }
      list(
        rule_id      = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets     = stats::setNames(list(cols_list), ds_name),
        expected     = list(fires = fire,
                            rows = if (isTRUE(fire)) 1L else integer()),
        notes        = "synth value-conditional-regex-match",
        authored     = "pattern-fixture-synth@1",
        spec         = spec, `_path` = NA_character_
      )
    }
    return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
  }

  # Special-case synth for value-not-equal-column pattern: single-leaf
  # equal_to(var_a, var_b, value_is_literal=false). Fires when A == B.
  # Positive: one row has A == B. Negative: all rows have A != B.
  if (length(lv) == 1L && ops[[1L]] == "equal_to" &&
      isFALSE(lv[[1L]]$value_is_literal)) {
    var_a <- as.character(lv[[1L]]$name)
    var_b <- as.character(lv[[1L]]$value)
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via %in% c("class","domain") &&
                     !is.na(pick$class) && nzchar(pick$class))
        list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
    } else if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"; spec <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else {
      ds_name <- "AE"; spec <- NULL
    }
    # Expand --VAR if the rule uses wildcards.
    dom2 <- substring(toupper(as.character(ds_name)), 1, 2)
    exp <- function(x) if (startsWith(x, "--")) paste0(dom2, sub("^--", "", x)) else x
    var_a_r <- exp(var_a); var_b_r <- exp(var_b)
    topic_col <- if (!is.na(pick$topic_col)) pick$topic_col else NA_character_
    mk <- function(fire) {
      a_vals <- c("EQUAL", "EQUAL2")
      b_vals <- if (isTRUE(fire)) c("EQUAL", "DIFFERENT") else c("DIFF_A", "DIFF_B")
      cols_list <- list(USUBJID = c("S1", "S2"))
      cols_list[[var_a_r]] <- a_vals
      if (var_b_r != var_a_r) cols_list[[var_b_r]] <- b_vals
      if (!is.na(topic_col) && !topic_col %in% names(cols_list)) {
        cols_list[[topic_col]] <- c("T", "T")
      }
      list(
        rule_id      = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets     = stats::setNames(list(cols_list), ds_name),
        expected     = list(fires = fire,
                            rows = if (isTRUE(fire)) 1L else integer()),
        notes        = "synth value-not-equal-column",
        authored     = "pattern-fixture-synth@1",
        spec         = spec, `_path` = NA_character_
      )
    }
    return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
  }

  # Special-case synth for value-conditional-not-equal-column pattern:
  # {all: [non_empty(cond_var), equal_to(var_a, var_b, cols)]}. Fires when
  # cond populated AND var_a == var_b. Positive row 1 has cond populated
  # AND a == b; row 2 has cond empty (blocks). Negative has cond populated
  # but a != b.
  if (length(lv) == 2L &&
      ops[[1L]] == "non_empty" &&
      ops[[2L]] == "equal_to" &&
      isFALSE(lv[[2L]]$value_is_literal)) {
    cond_var <- as.character(lv[[1L]]$name)
    var_a    <- as.character(lv[[2L]]$name)
    var_b    <- as.character(lv[[2L]]$value)
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via %in% c("class","domain") &&
                     !is.na(pick$class) && nzchar(pick$class))
        list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
    } else if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"; spec <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else {
      ds_name <- "AE"; spec <- NULL
    }
    dom2 <- substring(toupper(as.character(ds_name)), 1, 2)
    exp <- function(x) if (startsWith(x, "--")) paste0(dom2, sub("^--", "", x)) else x
    cond_var_r <- exp(cond_var); var_a_r <- exp(var_a); var_b_r <- exp(var_b)
    mk <- function(fire) {
      cols_list <- list(USUBJID = c("S1", "S2"))
      if (isTRUE(fire)) {
        # Row 1: cond populated + A==B (violation); Row 2: cond empty
        # (guard blocks).
        cond_vals <- c("X", "")
        a_vals    <- c("SAME", "B1")
        b_vals    <- c("SAME", "B2")
      } else {
        # cond populated on both rows, A != B -> no fire.
        cond_vals <- c("X", "X")
        a_vals    <- c("A1", "A2")
        b_vals    <- c("B1", "B2")
      }
      cols_list[[cond_var_r]] <- cond_vals
      if (var_a_r != cond_var_r) cols_list[[var_a_r]] <- a_vals
      else cols_list[[cond_var_r]] <- a_vals  # cond_var aliases var_a
      if (var_b_r != var_a_r && var_b_r != cond_var_r) cols_list[[var_b_r]] <- b_vals
      list(
        rule_id      = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets     = stats::setNames(list(cols_list), ds_name),
        expected     = list(fires = fire,
                            rows = if (isTRUE(fire)) 1L else integer()),
        notes        = "synth value-conditional-not-equal-column",
        authored     = "pattern-fixture-synth@1",
        spec         = spec, `_path` = NA_character_
      )
    }
    return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
  }

  # Special-case synth for value-equal-column pattern: single-leaf
  # not_equal_to(var_a, var_b, value_is_literal=false). Positive has a !=
  # b on every row, negative has a == b.
  if (length(lv) == 1L && ops[[1L]] == "not_equal_to" &&
      isFALSE(lv[[1L]]$value_is_literal)) {
    var_a <- as.character(lv[[1L]]$name)
    var_b <- as.character(lv[[1L]]$value)
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via %in% c("class","domain") && !is.na(pick$class) && nzchar(pick$class))
        list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
    } else if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"; spec <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else {
      ds_name <- "IE"; spec <- NULL
    }
    topic_col <- if (!is.na(pick$topic_col)) pick$topic_col else NA_character_
    mk <- function(fire) {
      a_vals <- c("VAL_A", "VAL_A2")
      b_vals <- if (isTRUE(fire)) c("VAL_B", "VAL_B2") else a_vals
      cols_list <- list(USUBJID = c("S1", "S2"))
      cols_list[[var_a]] <- a_vals
      if (var_b != var_a) cols_list[[var_b]] <- b_vals
      if (!is.na(topic_col) && !topic_col %in% names(cols_list)) {
        cols_list[[topic_col]] <- c("T", "T")
      }
      list(
        rule_id      = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets     = stats::setNames(list(cols_list), ds_name),
        expected     = list(fires = fire,
                            rows = if (isTRUE(fire)) 1L else integer()),
        notes        = "synth value-equal-column",
        authored     = "pattern-fixture-synth@1",
        spec         = spec, `_path` = NA_character_
      )
    }
    return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
  }

  # Special-case synth for value-conditional-equal-column pattern:
  # {all: [is_contained_by(cond_var, set), not_equal_to(var_a, var_b, cols)]}.
  # Build a 2-row dataset where row 1 has cond_var in the set AND var_a !=
  # var_b (violation fires), row 2 has cond_var NOT in the set (guard blocks
  # -> no fire). Negative dataset has both rows with cond_var in set but var_a
  # == var_b (no violation).
  if (length(lv) == 2L &&
      ops[[1L]] == "is_contained_by" &&
      ops[[2L]] == "not_equal_to") {
    cond_var    <- as.character(lv[[1L]]$name)
    cond_set    <- as.character(unlist(lv[[1L]]$value))
    var_a       <- as.character(lv[[2L]]$name)
    var_b       <- as.character(lv[[2L]]$value)
    # When value_is_literal is false the second leaf compares two columns.
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via %in% c("class","domain") && !is.na(pick$class) && nzchar(pick$class))
        list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
    } else if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"; spec <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else {
      ds_name <- "DM"; spec <- NULL
    }
    set_val <- cond_set[[1L]]
    mk <- function(fire) {
      # Build column assignments. When cond_var aliases var_a (very common
      # pattern: "ACTARM in (...) and ACTARM = ARM"), the same column has to
      # satisfy both roles, so its value is sourced from cond rather than
      # a_vals. Positive fires: row 1 has cond_var in set AND var_a != var_b;
      # row 2 has cond_var NOT in set (guard blocks). Negative: both rows
      # match cond but var_a == var_b.
      cols_list <- list(USUBJID = c("S1", "S2"))
      if (isTRUE(fire)) {
        cond   <- c(set_val, "NOT_IN_SET_XYZ")
        b_vals <- c("DIFFERS_FROM_A", "NEG_B")
        if (cond_var == var_a) {
          a_vals <- cond
        } else {
          a_vals <- c("A_VAL_1", "A_VAL_2")
        }
      } else {
        cond   <- c(set_val, set_val)
        a_vals <- if (cond_var == var_a) cond else c("SAME", "SAME")
        # Negative means no violation: var_b must EQUAL var_a elementwise.
        b_vals <- a_vals
      }
      cols_list[[cond_var]] <- cond
      cols_list[[var_a]]    <- a_vals
      if (var_b != var_a && var_b != cond_var) cols_list[[var_b]] <- b_vals
      list(
        rule_id      = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets     = stats::setNames(list(cols_list), ds_name),
        expected     = list(fires = fire,
                            rows = if (isTRUE(fire)) 1L else integer()),
        notes        = "synth value-conditional-equal-column",
        authored     = "pattern-fixture-synth@1",
        spec         = spec, `_path` = NA_character_
      )
    }
    return(list(pos = mk(TRUE), neg = mk(FALSE), synth = TRUE))
  }

  # Special-case synth for longer_than (value-length-le pattern): build a
  # minimal dataset with one record whose `name` cell exceeds `value` bytes
  # (positive fires) and one where the cell is exactly `value` bytes long
  # (negative doesn't fire).
  if (length(lv) == 1L && ops[[1L]] == "longer_than") {
    nm   <- as.character(lv[[1L]]$name)
    lim  <- suppressWarnings(as.integer(lv[[1L]]$value))
    if (is.na(lim) || lim <= 0L) lim <- 1L
    scope <- tryCatch(rule$scope[[1L]], error = function(e) NULL)
    pick  <- pick_dataset_for_scope(scope)
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (!is.na(pick$dataset)) {
      ds_name <- pick$dataset
      spec    <- if (pick$via %in% c("class","domain") && !is.na(pick$class) && nzchar(pick$class))
        list(class_map = stats::setNames(list(pick$class), ds_name)) else NULL
    } else if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"; spec <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else {
      ds_name <- "DM"; spec <- NULL
    }
    mk <- function(cell_len, fire) {
      cell <- strrep("A", cell_len)
      list(
        rule_id = as.character(rule$id),
        fixture_type = if (isTRUE(fire)) "positive" else "negative",
        datasets = stats::setNames(
          list(stats::setNames(list(cell), nm)),
          ds_name),
        expected = list(fires = fire,
                        rows = if (isTRUE(fire)) 1L else integer()),
        notes = sprintf("synth length (limit=%d)", lim),
        authored = "pattern-fixture-synth@1",
        spec = spec, `_path` = NA_character_
      )
    }
    return(list(pos = mk(lim + 1L, TRUE),
                neg = mk(lim,       FALSE),
                synth = TRUE))
  }

  # Special-case synth for label_by_suffix_missing (metadata-label-contains
  # pattern): build a single ADaM BDS-like dataset with one column whose name
  # ends in `suffix`. Apply the label attribute directly via attr() so the op
  # can read it. Positive: label lacks `value`; negative: label includes it.
  if (length(lv) == 1L && ops[[1L]] == "label_by_suffix_missing") {
    suf <- as.character(lv[[1L]]$suffix %||% "")
    val <- as.character(lv[[1L]]$value  %||% "")
    ds_name <- "ADLB"
    spec    <- list(class_map = list(ADLB = "BASIC DATA STRUCTURE"))
    col_nm  <- paste0("A", toupper(suf))
    mk_df <- function(label_text) {
      df <- data.frame(
        USUBJID = c("S1", "S2"),
        PARAMCD = c("X",  "X"),
        AVAL    = c(1,    2),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      df[[col_nm]] <- c("", "")
      attr(df[[col_nm]], "label") <- label_text
      df
    }
    pos_ds <- stats::setNames(list(mk_df("Analysis")), ds_name)
    neg_ds <- stats::setNames(list(mk_df(paste("Analysis", val))), ds_name)
    return(list(pos_ds = pos_ds, neg_ds = neg_ds, spec = spec,
                raw = TRUE, synth = TRUE))
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
    spec    <- if (pick$via %in% c("class","domain") && !is.na(pick$class) && nzchar(pick$class)) {
      list(class_map = stats::setNames(list(pick$class), ds_name))
    } else NULL
  } else {
    # Scope didn't yield a dataset (e.g. scope.classes="ALL" with no
    # domains). Default to a standard-appropriate dataset so herald's
    # ADaM/SDTM symmetry filter doesn't false-reject. For SDTM-IG rules
    # with unconstrained scope, the shared pattern fixture may be an
    # ADaM-class dataset (ADVS), which would block `--VAR` wildcard
    # expansion (ADaM datasets skip -- expansion in
    # rules-walk.R:.domain_prefix_candidates). Fall back to a plain
    # SDTM domain (AE) so -- resolves cleanly.
    rule_std <- toupper(as.character(rule$standard %||% ""))
    if (grepl("ADAM", rule_std)) {
      ds_name <- "ADSL"
      spec    <- list(class_map = list(ADSL = "SUBJECT LEVEL ANALYSIS DATASET"))
    } else if (grepl("SDTM|SEND", rule_std)) {
      ds_name <- "AE"
      spec    <- NULL
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
          if (isTRUE(synth$raw)) {
            # Synth produced pre-built data.frames (e.g. with
            # attr()-applied column labels) — bypass JSON fixture path.
            r_pos <- .run_rule_raw(rid, synth$pos_ds, synth$spec)
            r_neg <- .run_rule_raw(rid, synth$neg_ds, synth$spec)
          } else {
            r_pos <- .run_rule(rid, synth$pos)
            r_neg <- .run_rule(rid, synth$neg)
          }
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
