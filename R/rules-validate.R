# -----------------------------------------------------------------------------
# rules-validate.R — validate() entry point
# -----------------------------------------------------------------------------
# Top-level: given a directory path OR a named list of data frames, load the
# rule corpus, scope each rule to matching datasets, walk its check_tree, and
# collect findings into a herald_result.

#' Validate CDISC clinical data against the bundled conformance rules
#'
#' @param path Directory path containing XPT/JSON datasets. Alternatively,
#'   pass `files = list(DM = df, AE = df, ...)` to skip disk reads.
#' @param files Named list of data frames, mutually exclusive with `path`.
#' @param spec Optional `herald_spec` (from `read_spec()`) for anchor +
#'   class resolution.
#' @param rules Optional subset of rule ids to run. `NULL` runs the full
#'   compiled catalog.
#' @param authorities Optional character vector of authorities to include
#'   (e.g. `c("CDISC", "FDA")`). `NULL` = all.
#' @param standards Optional character vector of standards to include
#'   (e.g. `c("SDTM-IG", "ADaM-IG")`). `NULL` = all.
#' @param quiet Suppress progress output. Default FALSE.
#'
#' @return A `herald_result` S3 object.
#'
#' @examples
#' \dontrun{
#' result <- validate("/path/to/sdtm/")
#' result <- validate(files = list(AE = my_ae_df))
#' print(result)
#' }
#'
#' @export
validate <- function(path = NULL,
                     files = NULL,
                     spec = NULL,
                     rules = NULL,
                     authorities = NULL,
                     standards = NULL,
                     quiet = FALSE) {
  t0 <- Sys.time()
  call      <- rlang::caller_env()
  files_exp <- rlang::enexpr(files)

  if (is.null(path) && is.null(files)) {
    cli::cli_abort(
      "Either {.arg path} or {.arg files} must be supplied.",
      call = call
    )
  }

  # ---- assemble dataset map ------------------------------------------------
  if (!is.null(files)) {
    files    <- .infer_file_names(files, files_exp, call)
    datasets <- .assemble_from_files(files, call)
  } else {
    datasets <- .assemble_from_path(path, call)
  }

  if (length(datasets) == 0L) {
    cli::cli_warn("No datasets found to validate.")
  }

  # ---- load rule corpus ----------------------------------------------------
  rules_rds <- .rules_path()
  if (!file.exists(rules_rds)) {
    cli::cli_abort(
      "Rule catalog {.path {rules_rds}} not found. Run tools/compile-rules.R.",
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
  ctx$datasets  <- datasets
  ctx$spec      <- spec
  ctx$crossrefs <- build_crossrefs(datasets, spec)

  all_findings <- list()
  rules_applied <- 0L

  for (i in seq_len(rules_total)) {
    rule <- as.list(catalog[i, , drop = FALSE])
    # Un-list-column the scope + check_tree (they come back as length-1 list)
    rule$scope      <- rule$scope[[1]]
    rule$check_tree <- rule$check_tree[[1]]
    ctx$current_rule_id <- rule$id

    target_ds <- scoped_datasets(rule, ctx)
    if (length(target_ds) == 0L) next

    rule_fired <- FALSE
    is_meta_rule <- .is_metadata_rule(rule$check_tree)
    for (ds_name in target_ds) {
      d <- datasets[[ds_name]]
      # Make dataset name available to the walker for --VAR wildcard expansion
      ctx$current_dataset <- ds_name
      ctx$current_domain  <- toupper(substr(ds_name, 1, 2))
      # Expand xx / y / zz placeholders against this dataset's columns.
      xp <- .expand_indexed(rule$check_tree, d)

      if (isTRUE(xp$indexed) && length(xp$instances) > 0L) {
        # Indexed rule: walk each concrete-index instance separately so
        # finding messages carry the resolved variable names (e.g.
        # "TRT01AN is present and TRT01A is not present") instead of the
        # template ("TRTxxAN is present and TRTxxA is not present").
        ph <- xp$placeholder
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
          inst_rule <- rule
          inst_rule$message <- .render_indexed_text(rule$message, ph, idx_val)
          var_inst <- .render_indexed_text(primary_variable(rule$check_tree),
                                           ph, idx_val)
          f <- emit_findings(inst_rule, ds_name, m, d, variable = var_inst)
          if (nrow(f) > 0L) {
            all_findings[[length(all_findings) + 1L]] <- f
          }
        }
        if (any_fired_this_ds) rule_fired <- TRUE
        next
      }

      # Non-indexed (or indexed with zero matches): single walk.
      mask <- walk_tree(xp$tree, d, ctx)
      if (length(mask) == 0L) next
      if (is_meta_rule && length(mask) > 1L && any(!is.na(mask) & mask)) {
        mask <- c(TRUE, rep(FALSE, length(mask) - 1L))
      }
      var <- primary_variable(rule$check_tree)
      f <- emit_findings(rule, ds_name, mask, d, variable = var)
      if (nrow(f) > 0L) {
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
    rule_catalog     = tibble::as_tibble(catalog[, c("id","authority","standard","severity","message")]),
    op_errors        = ctx$op_errors
  )
}

# --- internals --------------------------------------------------------------

# Names of ops whose result is a function of the dataset's *column list*
# rather than row values. When every leaf in a check_tree is one of these,
# the rule is "metadata-level" and its mask is uniform across rows: we should
# fire once per (rule x dataset), not once per row. Matches P21's concept of
# Target="Metadata" rules authored from CDISC text.
.METADATA_OPS <- c("exists", "not_exists")

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
    cli::cli_abort(
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

.assemble_from_files <- function(files, call) {
  if (!is.list(files) || is.null(names(files))) {
    cli::cli_abort(
      "{.arg files} must be a named list of data frames.",
      call = call
    )
  }
  bad <- !vapply(files, is.data.frame, logical(1))
  if (any(bad)) {
    cli::cli_abort(
      "All entries of {.arg files} must be data frames. Offenders: {.val {names(files)[bad]}}",
      call = call
    )
  }
  # Uppercase dataset names to match rule-scope convention
  stats::setNames(files, toupper(names(files)))
}

.assemble_from_path <- function(path, call) {
  if (!dir.exists(path)) {
    cli::cli_abort("{.arg path} {.path {path}} does not exist.", call = call)
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
