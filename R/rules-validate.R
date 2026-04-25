# -----------------------------------------------------------------------------
# rules-validate.R — validate() entry point
# -----------------------------------------------------------------------------
# Top-level: given a directory path OR a named list of data frames, load the
# rule corpus, scope each rule to matching datasets, walk its check_tree, and
# collect findings into a herald_result.

#' Validate CDISC clinical data against the conformance rule catalog
#'
#' @description
#' The primary entry point for CDISC conformance checking. Runs SDTM-IG,
#' ADaM-IG, and SEND-IG rules from the compiled catalog against a set of
#' clinical datasets and returns a `herald_result` carrying every finding,
#' the full rule catalog snapshot, and dataset metadata.
#'
#' Supply datasets as a directory path (XPT or Dataset-JSON files on disk)
#' or directly as a named list of data frames. For best results, stamp
#' CDISC attributes first with [apply_spec()].
#'
#' @param path Directory path containing `.xpt` or `.json` datasets.
#'   Mutually exclusive with `files`.
#' @param files Named list of data frames (e.g.
#'   `list(DM = dm, AE = ae)`). Mutually exclusive with `path`.
#' @param spec Optional `herald_spec` from [as_herald_spec()] or
#'   [read_define_xml()]. Used for class resolution and anchor variables.
#' @param rules Character vector of rule IDs to run (e.g.
#'   `c("CG0001", "ADaM-005")`). `NULL` (default) runs the full catalog.
#' @param authorities Character vector of authorities to include
#'   (e.g. `c("CDISC", "FDA")`). `NULL` (default) includes all.
#' @param standards Character vector of standards to include
#'   (e.g. `c("SDTM-IG", "ADaM-IG")`). `NULL` (default) includes all.
#' @param dictionaries Named list of `herald_dict_provider` objects
#'   from [ct_provider()], [srs_provider()], [meddra_provider()], etc.
#'   Per-run overrides to the session registry set by
#'   [register_dictionary()].
#' @param study_metadata Named list of sponsor-supplied study
#'   characteristics. Recognised key: `collected_domains` -- character
#'   vector of CDISC domain codes collected in this study (e.g.
#'   `c("MB", "PC")`). Rules that require this key return `NA` advisory
#'   when it is absent.
#' @param define A `herald_define` object from [read_define_xml()].
#'   Activates Define-XML dependent rules (e.g. CG0019, CG0400) that
#'   otherwise return `NA` advisory.
#' @param severity_map Named character vector (or named list for
#'   domain-scoped overrides) remapping rule severities at run time.
#'   Match priority (first wins):
#'   \enumerate{
#'     \item Exact rule ID: `c("CG0085" = "Reject")`.
#'     \item Regex on rule ID: `c("^ADaM-7[0-9]{2}$" = "High")`.
#'     \item Severity category: `c("Medium" = "High")`.
#'   }
#'   For domain-scoped overrides use a named list as the value:
#'   `list("CG0085" = list(ADSL = "Reject", BDS = "High",
#'   default = "Medium"))`. Findings include a `severity_override`
#'   column when an override is applied.
#' @param quiet Logical. Suppress progress output. Default `FALSE`.
#'
#' @return A `herald_result` S3 object with fields:
#'   \describe{
#'     \item{`findings`}{Data frame -- one row per (rule, dataset, record)
#'       finding. Columns: `rule_id`, `dataset`, `row`, `variable`,
#'       `value`, `status` (`"fired"` or `"advisory"`), `severity`,
#'       `message`, `severity_override`.}
#'     \item{`rule_catalog`}{Data frame snapshot of every rule applied,
#'       with `id`, `title`, `authority`, `standard`, `severity`,
#'       `source_url`, and per-rule `fired_n` / `advisory_n` counts.}
#'     \item{`dataset_meta`}{Named list -- one entry per dataset with
#'       row/column counts, detected class, and per-dataset finding
#'       tallies.}
#'     \item{`datasets_checked`}{Character vector of dataset names
#'       that were evaluated.}
#'     \item{`skipped_refs`}{List of cross-dataset references that
#'       could not be resolved (missing datasets).}
#'     \item{`timestamp`}{`POSIXct` of when `validate()` was called.}
#'     \item{`duration`}{`difftime` of total elapsed time.}
#'     \item{`profile`}{Character -- `"sdtm"`, `"adam"`, `"send"`, or
#'       `"unknown"` -- autodetected from dataset names.}
#'   }
#'
#' @examples
#' # Minimal in-memory run
#' ae <- data.frame(
#'   STUDYID = "PILOT01", DOMAIN = "AE", USUBJID = "PILOT01-001-001",
#'   AETERM  = "HEADACHE", AEDECOD = "Headache",
#'   stringsAsFactors = FALSE
#' )
#' result <- validate(files = list(AE = ae), quiet = TRUE)
#' result
#'
#' # Inspect findings
#' result$findings[result$findings$status == "fired", ]
#'
#' # From disk -- apply_spec first for full attribute coverage
#' dm   <- readRDS(system.file("extdata", "dm.rds",        package = "herald"))
#' spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
#' dm   <- apply_spec(dm, spec)
#' result2 <- validate(files = list(DM = dm), quiet = TRUE)
#' result2
#'
#' @seealso [apply_spec()] to stamp CDISC attributes before validation,
#'   [write_report_html()] / [write_report_xlsx()] to render results,
#'   [rule_catalog()] to browse the available rules.
#' @family validate
#' @export
validate <- function(path = NULL,
                     files = NULL,
                     spec = NULL,
                     rules = NULL,
                     authorities = NULL,
                     standards = NULL,
                     dictionaries = NULL,
                     study_metadata = NULL,
                     define = NULL,
                     severity_map = NULL,
                     quiet = FALSE) {
  t0 <- Sys.time()
  call      <- rlang::caller_env()
  files_exp <- rlang::enexpr(files)

  if (is.null(path) && is.null(files)) {
    herald_error(
      "Either {.arg path} or {.arg files} must be supplied.",
      class = "herald_error_input",
      call = call
    )
  }

  # ---- spec pre-flight gate -----------------------------------------------
  # If a herald_spec is supplied, validate it before doing any dataset work.
  # A bad spec aborts here with a viewer-opened HTML report.
  if (!is.null(spec) && is_herald_spec(spec)) {
    validate_spec(spec, view = !isTRUE(quiet))
  }

  # ---- assemble dataset map ------------------------------------------------
  if (!is.null(files)) {
    files    <- .infer_file_names(files, files_exp, call)
    # Lift out any Define-XML entry (path or herald_define object) from files.
    define   <- define %||% .extract_define_from_files(files, call)
    files    <- .drop_define_entries(files)
    datasets <- .assemble_from_files(files, call)
  } else {
    datasets <- .assemble_from_path(path, call)
  }

  # Inject Define-XML virtual datasets when a herald_define is available.
  # Builders produce flat data.frames keyed by virtual names such as
  # "Define_Dataset_Metadata" that DEFINE rules reference in their scope.
  if (!is.null(define) && inherits(define, "herald_define")) {
    define_frames <- .build_define_datasets(define)
    for (nm in names(define_frames)) {
      if (!nm %in% names(datasets)) datasets[[nm]] <- define_frames[[nm]]
    }
  }

  if (length(datasets) == 0L) {
    cli::cli_warn("No datasets found to validate.")
  }

  # ---- load rule corpus ----------------------------------------------------
  rules_rds <- .rules_path()
  if (!file.exists(rules_rds)) {
    herald_error(
      "Rule catalog {.path {rules_rds}} not found. Run tools/compile-rules.R.",
      class = "herald_error_input",
      call = call
    )
  }
  catalog <- readRDS(rules_rds)

  if (!is.null(authorities)) {
    catalog <- catalog[catalog$authority %in% authorities, , drop = FALSE]
  }
  if (!is.null(standards)) {
    catalog <- catalog[catalog$standard %in% standards, , drop = FALSE]
  }
  if (!is.null(rules)) {
    catalog <- catalog[catalog$id %in% rules, , drop = FALSE]
  }

  rules_total <- nrow(catalog)
  if (!quiet) {
    cli::cli_inform(c(
      "v" = "Loaded {rules_total} rules; validating {length(datasets)} dataset{?s}."
    ))
  }

  # ---- ctx + per-rule execution -------------------------------------------
  ctx <- new_herald_ctx()
  ctx$datasets       <- datasets
  ctx$spec           <- spec
  ctx$study_metadata <- study_metadata
  ctx$define         <- define
  ctx$crossrefs      <- build_crossrefs(datasets, spec)
  # Per-run CT cache. op_value_in_codelist lazy-loads on first use.
  ctx$ct           <- list()
  # Dictionary registry (Dictionary Provider Protocol). Populated
  # from the global session registry + the explicit `dictionaries=`
  # arg. Missing-ref tracker feeds result$skipped_refs at the end.
  .populate_dict_registry(ctx, dictionaries, call)
  .init_missing_refs(ctx)
  # Pre-scan every dataset for duplicate USUBJID rows. Cross-dataset ops
  # use this cache to surface "ref has duplicate USUBJID" as a first-class
  # finding instead of silently first-matching (plan Q10).
  ctx$dup_subjects <- .dup_subjects_scan(datasets)

  all_findings <- list()
  rules_applied <- 0L

  for (i in seq_len(rules_total)) {
    rule <- as.list(catalog[i, , drop = FALSE])
    # Un-list-column the scope + check_tree (they come back as length-1 list)
    rule$scope      <- rule$scope[[1]]
    rule$check_tree <- rule$check_tree[[1]]
    ctx$current_rule_id <- rule$id

    # Submission-level rules (scope.submission: true) bypass per-dataset
    # iteration. One evaluation per validate() against a stub, firing a
    # single submission-level finding on violation.
    if (.is_submission_scope(rule)) {
      stub <- .submission_stub_df()
      ctx$current_dataset <- .SUBMISSION_DATASET
      ctx$current_domain  <- ""
      mask <- walk_tree(rule$check_tree, stub, ctx)
      if (length(mask) > 0L && any(!is.na(mask) & mask)) {
        rule_emit <- .sev_override(rule, severity_map, NULL)
        f <- emit_submission_finding(rule_emit$rule)
        if (nrow(f) > 0L) {
          if (rule_emit$changed) f$severity_override <- rule_emit$orig
          all_findings[[length(all_findings) + 1L]] <- f
          rules_applied <- rules_applied + 1L
        }
      }
      next
    }

    target_ds <- scoped_datasets(rule, ctx)
    if (length(target_ds) == 0L) next

    rule_fired <- FALSE
    is_meta_rule <- .is_metadata_rule(rule$check_tree)
    for (ds_name in target_ds) {
      d <- datasets[[ds_name]]
      # Make dataset name available to the walker for --VAR wildcard expansion
      ctx$current_dataset <- ds_name
      ctx$current_domain  <- toupper(substr(ds_name, 1, 2))
      rule_emit <- .sev_override(rule, severity_map, .ds_class(ds_name, ctx))
      # Run Operations: pre-compute phase (stamp $id columns; cache in ctx).
      ctx$op_results <- list()
      d <- .apply_operations(rule$operations, d, datasets, ctx)
      # Expand xx / y / zz placeholders against this dataset's columns.
      xp <- .expand_indexed(rule$check_tree, d)

      if (isTRUE(xp$indexed) && length(xp$instances) > 0L) {
        # Indexed rule: walk each concrete-index instance separately so
        # finding messages carry the resolved variable names (e.g.
        # "TRT01AN is present and TRT01A is not present") instead of the
        # template ("TRTxxAN is present and TRTxxA is not present"). For
        # multi-placeholder rules (`expand: xx,y`), render the message
        # by applying each (placeholder -> value) pair from the tuple.
        any_fired_this_ds <- FALSE
        for (idx_val in names(xp$instances)) {
          inst_ct <- xp$instances[[idx_val]]
          m <- walk_tree(inst_ct, d, ctx)
          if (length(m) == 0L) next
          if (is_meta_rule && length(m) > 1L && any(!is.na(m) & m)) {
            m <- c(TRUE, rep(FALSE, length(m) - 1L))
          }
          if (!any(!is.na(m) & m)) next
          any_fired_this_ds <- TRUE
          tuple <- xp$tuples[[idx_val]]
          msg <- rule$message
          var_inst <- primary_variable(rule$check_tree)
          for (p in names(tuple)) {
            v <- tuple[[p]]
            if (is.na(v) || !nzchar(as.character(v))) next
            msg <- .render_indexed_text(msg, p, v)
            var_inst <- .render_indexed_text(var_inst, p, v)
          }
          inst_rule <- rule_emit$rule
          inst_rule$message <- msg
          f <- emit_findings(inst_rule, ds_name, m, d, variable = var_inst)
          if (nrow(f) > 0L) {
            if (rule_emit$changed) f$severity_override <- rule_emit$orig
            all_findings[[length(all_findings) + 1L]] <- f
          }
        }
        if (any_fired_this_ds) rule_fired <- TRUE
        next
      }

      # Non-indexed (or indexed with zero matches): single walk.
      mask <- walk_tree(xp$tree, d, ctx)
      # Metadata-only rule against a 0-row dataset: P21 still evaluates
      # dataset-level rules on empty sources (BlockValidator.java:321-343
      # calls validateDataset() unconditionally). Re-evaluate the tree
      # against a 1-row placeholder that preserves the column list, then
      # trim to a single fire/non-fire answer.
      if (is_meta_rule && length(mask) == 0L) {
        ph <- as.data.frame(lapply(d, function(x) x[NA_integer_][1]),
                            stringsAsFactors = FALSE, check.names = FALSE)
        # lapply with NA_integer_ gives 1 row of NAs preserving column types.
        if (nrow(ph) == 0L) ph <- as.data.frame(
          stats::setNames(rep(list(NA), length(names(d))), names(d)),
          stringsAsFactors = FALSE, check.names = FALSE
        )
        mask <- walk_tree(xp$tree, ph, ctx)
      }
      if (length(mask) == 0L) next
      if (is_meta_rule && length(mask) > 1L && any(!is.na(mask) & mask)) {
        mask <- c(TRUE, rep(FALSE, length(mask) - 1L))
      }
      var <- primary_variable(rule$check_tree)
      f <- emit_findings(rule_emit$rule, ds_name, mask, d, variable = var)
      if (nrow(f) > 0L) {
        if (rule_emit$changed) f$severity_override <- rule_emit$orig
        all_findings[[length(all_findings) + 1L]] <- f
        rule_fired <- TRUE
      } else if (any(!is.na(mask) & mask)) {
        rule_fired <- TRUE
      }
    }
    if (rule_fired) rules_applied <- rules_applied + 1L
  }

  findings_tbl <- if (length(all_findings) > 0L) {
    do.call(rbind, all_findings)
  } else {
    empty_findings()
  }

  # Collapse advisories to at most one per rule. Narrative or NA-mask rules
  # otherwise emit one advisory per (rule x dataset) which inflates counts
  # on multi-dataset corpora (22 SDTM + narrative -> 22x duplication).
  findings_tbl <- .collapse_advisories(findings_tbl)

  # ---- metadata about datasets --------------------------------------------
  dataset_meta <- lapply(names(datasets), function(nm) {
    d <- datasets[[nm]]
    list(
      rows   = nrow(d),
      cols   = ncol(d),
      label  = attr(d, "label") %||% NA_character_,
      class  = .ds_class(nm, ctx)
    )
  })
  names(dataset_meta) <- names(datasets)

  duration <- Sys.time() - t0

  new_herald_result(
    findings         = findings_tbl,
    rules_applied    = rules_applied,
    rules_total      = rules_total,
    datasets_checked = names(datasets),
    duration         = duration,
    profile          = NA_character_,
    config_hash      = NA_character_,
    dataset_meta     = dataset_meta,
    rule_catalog     = tibble::as_tibble(catalog[, intersect(
      c("id", "authority", "standard", "severity", "message", "source_url"),
      names(catalog)
    )]),
    op_errors        = ctx$op_errors,
    skipped_refs     = .finalize_skipped_refs(ctx)
  )
}

# --- internals --------------------------------------------------------------

# Names of ops whose result is a function of the dataset's *column list*
# rather than row values. When every leaf in a check_tree is one of these,
# the rule is "metadata-level" and its mask is uniform across rows: we should
# fire once per (rule x dataset), not once per row. Matches P21's concept of
# Target="Metadata" rules authored from CDISC text.
.METADATA_OPS <- c("exists", "not_exists", "label_by_suffix_missing",
                   "any_var_name_exceeds_length",
                   "any_var_label_exceeds_length",
                   "attr_mismatch", "shared_attr_mismatch",
                   "dataset_label_not",
                   "treatment_var_absent_across_datasets",
                   "no_var_with_suffix")

# Walk a check_tree and return TRUE when every leaf operator is in
# .METADATA_OPS. Narrative / empty / r_expression trees are not metadata-
# level (different handling elsewhere).
.is_metadata_rule <- function(node) {
  if (!is.list(node) || length(node) == 0L) return(FALSE)
  if (!is.null(node[["narrative"]])) return(FALSE)
  if (!is.null(node[["r_expression"]])) return(FALSE)
  if (!is.null(node[["operator"]])) {
    return(isTRUE(node[["operator"]] %in% .METADATA_OPS))
  }
  if (!is.null(node[["not"]])) return(.is_metadata_rule(node[["not"]]))
  children <- c(node[["all"]], node[["any"]])
  if (length(children) == 0L) return(FALSE)
  all(vapply(children, .is_metadata_rule, logical(1L)))
}

#' One-row placeholder for submission-level rule evaluation. Dataset-
#' level ops (not_exists, exists, dataset_label_not, ...) return a
#' single-element mask which the walker consumes cleanly.
#' @noRd
.submission_stub_df <- function() {
  data.frame(.herald_submission = NA, stringsAsFactors = FALSE)
}

#' Scan every dataset once for duplicated USUBJID values and cache the
#' result on `ctx`. Returns a named list parallel to `datasets`: each
#' element is either a (possibly empty) character vector of duplicated
#' USUBJID values, or NA_character_ when the dataset has no USUBJID column.
#' @noRd
.dup_subjects_scan <- function(datasets) {
  out <- vector("list", length(datasets))
  names(out) <- names(datasets)
  for (nm in names(datasets)) {
    d <- datasets[[nm]]
    if (!is.data.frame(d)) {
      out[[nm]] <- NA_character_
      next
    }
    j <- match("USUBJID", toupper(names(d)))
    if (is.na(j)) {
      out[[nm]] <- NA_character_
      next
    }
    vals <- as.character(d[[j]])
    vals <- vals[!is.na(vals) & nzchar(vals)]
    dup  <- unique(vals[duplicated(vals)])
    out[[nm]] <- dup
  }
  out
}

#' De-duplicate advisory findings: emit at most one advisory per rule_id.
#'
#' Fired findings pass through unchanged (they are row-level violations with
#' distinct row numbers). Advisory findings come from narrative-only rules
#' or NA-mask rules; one-per-dataset inflation is rarely useful, so we
#' collapse to one advisory per rule_id. The retained advisory uses the
#' first dataset encountered; downstream consumers should not rely on the
#' dataset field of an advisory row being exhaustive.
#' @noRd
.collapse_advisories <- function(findings) {
  if (nrow(findings) == 0L) return(findings)
  fired <- findings[findings$status != "advisory", , drop = FALSE]
  adv   <- findings[findings$status == "advisory", , drop = FALSE]
  if (nrow(adv) > 1L) {
    adv <- adv[!duplicated(adv$rule_id), , drop = FALSE]
  }
  if (nrow(fired) == 0L) return(adv)
  if (nrow(adv)   == 0L) return(fired)
  rbind(fired, adv)
}

# --- severity_map helpers ----------------------------------------------------

#' Apply severity_map to a single rule, returning a list with the (possibly
#' mutated) rule, the original severity, and a flag indicating change.
#' @noRd
.sev_override <- function(rule, severity_map, ds_class) {
  orig <- rule[["severity"]] %||% "Medium"
  if (is.null(severity_map) || length(severity_map) == 0L) {
    return(list(rule = rule, orig = orig, changed = FALSE))
  }
  new_sev <- .apply_sev_map(rule[["id"]] %||% "", orig, severity_map, ds_class)
  changed <- !identical(new_sev, orig)
  if (changed) rule[["severity"]] <- new_sev
  list(rule = rule, orig = orig, changed = changed)
}

#' Three-tier severity lookup: exact rule_id -> regex -> category.
#' @noRd
.apply_sev_map <- function(rule_id, orig_sev, severity_map, ds_class) {
  nm <- names(severity_map)
  if (is.null(nm)) return(orig_sev)

  # tier 1: exact rule_id
  i <- match(rule_id, nm, nomatch = 0L)
  if (i > 0L) return(.resolve_sev_entry(severity_map[[i]], ds_class, orig_sev))

  # tier 2: regex match against rule_id
  for (j in seq_along(nm)) {
    pat <- nm[[j]]
    if (!nzchar(pat)) next
    hit <- tryCatch(grepl(pat, rule_id, perl = TRUE), error = function(e) FALSE)
    if (isTRUE(hit)) return(.resolve_sev_entry(severity_map[[j]], ds_class, orig_sev))
  }

  # tier 3: severity category
  i <- match(orig_sev, nm, nomatch = 0L)
  if (i > 0L) return(.resolve_sev_entry(severity_map[[i]], ds_class, orig_sev))

  orig_sev
}

#' Resolve a severity_map entry that may be a scalar string or a domain-keyed
#' list (`list(ADSL = "Reject", BDS = "High", default = "Medium")`).
#' @noRd
.resolve_sev_entry <- function(entry, ds_class, orig_sev) {
  if (is.character(entry) && length(entry) == 1L) return(entry)
  if (is.list(entry)) {
    if (!is.null(ds_class) && nzchar(ds_class) && !is.null(entry[[ds_class]])) {
      return(as.character(entry[[ds_class]]))
    }
    if (!is.null(entry[["default"]])) return(as.character(entry[["default"]]))
  }
  orig_sev
}

.rules_path <- function() {
  # During devtools::load_all(), system.file returns the source inst/ path.
  p <- system.file("rules", "rules.rds", package = "herald")
  if (!nzchar(p)) {
    # Fall back for dev tree without install
    here <- file.path("inst", "rules", "rules.rds")
    if (file.exists(here)) return(here)
  }
  p
}

#' When `files` is a `list(...)` call, recover bare-symbol names for entries
#' that the user didn't label explicitly. `files = list(dm, ae)` becomes
#' `list(DM = dm, AE = ae)` without the user having to type the keys.
#'
#' If the user's list mixes bare symbols with unresolvable entries (inline
#' expressions or literals), emit a helpful error. If NO entry is a
#' recoverable symbol, leave `files` alone and let downstream validation
#' produce its usual "must be a named list of data frames" error.
#' @noRd
.infer_file_names <- function(files, files_exp, call) {
  if (!is.list(files)) return(files)
  have_names <- names(files) %||% rep("", length(files))

  if (!is.call(files_exp) || length(files_exp) <= 1L ||
      !identical(files_exp[[1L]], quote(list))) {
    return(files)
  }

  entries <- as.list(files_exp)[-1L]
  if (length(entries) != length(files)) return(files)

  entry_nms <- names(entries) %||% rep("", length(entries))
  is_sym <- vapply(entries, is.symbol, logical(1L))

  # If none of the entries look like bare symbols, nothing to infer --
  # leave `files` as given and let downstream validation handle it.
  recoverable <- is_sym & !nzchar(have_names) & !nzchar(entry_nms)
  if (!any(recoverable)) return(files)

  for (i in which(recoverable)) {
    have_names[[i]] <- as.character(entries[[i]])
  }

  # Now: if anything is STILL nameless, the user mixed symbols with inline
  # expressions -- flag that.
  if (any(!nzchar(have_names))) {
    bad <- which(!nzchar(have_names))[[1L]]
    herald_error_validation(
      c(
        "Every element of {.arg files} must be named or a bare variable.",
        "i" = "Entry at position {bad} is an inline expression; pass a named entry or assign it to a variable first."
      ),
      call = call
    )
  }
  names(files) <- have_names
  files
}

.extract_define_from_files <- function(files, call) {
  if (!is.list(files)) return(NULL)
  for (nm in names(files)) {
    v <- files[[nm]]
    if (inherits(v, "herald_define")) return(v)
    if (is.character(v) && length(v) == 1L && grepl("[.]xml$", v, ignore.case = TRUE)) {
      return(tryCatch(read_define_xml(v, call = call), error = function(e) NULL))
    }
  }
  NULL
}

.drop_define_entries <- function(files) {
  if (!is.list(files)) return(files)
  keep <- vapply(files, function(v) {
    !inherits(v, "herald_define") &&
      !(is.character(v) && length(v) == 1L && grepl("[.]xml$", v, ignore.case = TRUE))
  }, logical(1L))
  files[keep]
}

.assemble_from_files <- function(files, call) {
  if (!is.list(files)) {
    herald_error_validation(
      "{.arg files} must be a named list of data frames.",
      call = call
    )
  }
  if (length(files) == 0L) return(list())
  if (is.null(names(files))) {
    herald_error_validation(
      "{.arg files} must be a named list of data frames.",
      call = call
    )
  }
  bad <- !vapply(files, is.data.frame, logical(1))
  if (any(bad)) {
    herald_error_validation(
      "All entries of {.arg files} must be data frames. Offenders: {.val {names(files)[bad]}}",
      call = call
    )
  }
  # Uppercase dataset names to match rule-scope convention
  stats::setNames(files, toupper(names(files)))
}

.assemble_from_path <- function(path, call) {
  if (!dir.exists(path)) {
    herald_error_validation("{.arg path} {.path {path}} does not exist.", call = call)
  }
  xpt_files  <- list.files(path, pattern = "\\.xpt$", full.names = TRUE,
                           ignore.case = TRUE)
  json_files <- list.files(path, pattern = "\\.json$", full.names = TRUE,
                           ignore.case = TRUE)

  datasets <- list()
  for (f in xpt_files) {
    nm <- toupper(tools::file_path_sans_ext(basename(f)))
    datasets[[nm]] <- tryCatch(read_xpt(f),
                               error = function(e) {
                                 cli::cli_warn("Failed to read {.path {f}}: {conditionMessage(e)}")
                                 NULL
                               })
  }
  for (f in json_files) {
    nm <- toupper(tools::file_path_sans_ext(basename(f)))
    if (is.null(datasets[[nm]])) {
      datasets[[nm]] <- tryCatch(read_json(f),
                                 error = function(e) {
                                   cli::cli_warn("Failed to read {.path {f}}: {conditionMessage(e)}")
                                   NULL
                                 })
    }
  }
  datasets[!vapply(datasets, is.null, logical(1))]
}
