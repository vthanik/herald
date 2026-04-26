# --------------------------------------------------------------------------
# spec-validate.R -- pre-flight spec validator
# --------------------------------------------------------------------------
# validate_spec(spec) runs the 103 herald-spec rules from spec_rules.rds
# against virtual datasets derived from the herald_spec slots.
#
# If any issues are found:
#   1. write_spec_report_html() writes a standalone HTML report
#   2. htmltools::html_print() opens it in the Positron/RStudio viewer
#   3. herald_error() aborts with a summary
#
# The caller (validate(), write_define_xml()) calls this before doing any
# real work.  validate_spec() returns invisibly when the spec is clean.

#' Validate a herald_spec for Define-XML completeness
#'
#' @description
#' Runs the built-in spec-validation rules (standard: `herald-spec`) against
#' the slots of `spec`.  If any issues are found a detailed HTML report is
#' written to `report`, opened in the IDE viewer, and an error is raised.
#'
#' @param spec A `herald_spec` object from [as_herald_spec()] or
#'   [herald_spec()].
#' @param report File path for the HTML report.  Defaults to a temporary file.
#'   Ignored when there are no issues.
#' @param view Logical.  If `TRUE` (default) and issues are found, the report
#'   is opened in the IDE viewer pane before aborting.
#' @return Invisibly, when the spec is clean.  Otherwise an error of class
#'   `herald_error_validation` is raised.
#'
#' @examples
#' # ---- Valid spec -- returns invisibly (no issues found) ---------------
#' spec_ok <- as_herald_spec(
#'   ds_spec = data.frame(
#'     dataset = "DM",
#'     label   = "Demographics",
#'     stringsAsFactors = FALSE
#'   )
#' )
#' invisible(validate_spec(spec_ok))   # returns NULL invisibly
#'
#' # ---- Suppress the viewer for automated pipelines ---------------------
#' invisible(validate_spec(spec_ok, view = FALSE))
#'
#' # ---- Send the HTML report to a known path (not a tempfile) -----------
#' report_path <- tempfile(fileext = ".html")
#' on.exit(unlink(report_path))
#' invisible(validate_spec(spec_ok, report = report_path, view = FALSE))
#' file.exists(report_path)   # FALSE -- file is only written when issues exist
#'
#' # ---- Invalid spec triggers an error (catch it for demonstration) -----
#' spec_bad <- as_herald_spec(
#'   ds_spec = data.frame(dataset = "DM", stringsAsFactors = FALSE)
#' )
#' tryCatch(
#'   validate_spec(spec_bad, view = FALSE),
#'   herald_error_validation = function(e) conditionMessage(e)
#' )
#'
#' @family spec
#' @export
validate_spec <- function(spec, report = NULL, view = TRUE) {
  call <- rlang::caller_env()
  check_herald_spec(spec, call = call)

  rules <- .spec_rules()
  datasets <- .spec_datasets(spec)

  ctx <- new.env(parent = emptyenv())
  ctx$datasets <- datasets
  ctx$spec <- spec
  ctx$crossrefs <- list()
  ctx$missing_refs <- list(datasets = list(), dictionaries = list())
  ctx$op_errors <- list()

  all_findings <- list()

  for (i in seq_len(nrow(rules))) {
    rule <- as.list(rules[i, , drop = FALSE])
    rule$scope <- rule$scope[[1]]
    rule$check_tree <- rule$check_tree[[1]]
    rule$operations <- rule$operations[[1]]

    target_ds <- .spec_scoped_datasets(rule, datasets)
    if (length(target_ds) == 0L) {
      next
    }

    # Use the human-readable description as the finding message so users
    # see "Dataset label (Description) is required for regulatory submissions."
    # rather than the short code "DATASET_LABEL_REQUIRED".
    desc <- rule$description %||% rule$message
    if (!is.null(desc) && nzchar(desc)) {
      rule$message <- desc
    }

    for (ds_name in target_ds) {
      d <- datasets[[ds_name]]
      ctx$current_dataset <- ds_name

      mask <- tryCatch(
        walk_tree(rule$check_tree, d, ctx),
        error = function(e) rep(NA, nrow(d))
      )
      if (length(mask) == 0L) {
        next
      }

      primary_var <- .leaf_name(rule$check_tree)
      f <- emit_findings(rule, ds_name, mask, d, variable = primary_var)
      if (nrow(f) > 0L) all_findings[[length(all_findings) + 1L]] <- f
    }
  }

  findings <- if (length(all_findings) > 0L) {
    do.call(rbind, all_findings)
  } else {
    empty_findings()
  }

  n_issues <- sum(findings$status == "fired", na.rm = TRUE)

  if (n_issues == 0L) {
    return(invisible(NULL))
  }

  # Write + view + abort -------------------------------------------------
  out_path <- report %||% tempfile(fileext = ".html")
  write_spec_report_html(findings, out_path)

  if (isTRUE(view)) {
    viewer <- getOption("viewer")
    if (is.function(viewer)) {
      viewer(out_path)
    } else if (requireNamespace("htmltools", quietly = TRUE)) {
      tryCatch(
        htmltools::html_print(htmltools::HTML(paste(
          readLines(out_path, warn = FALSE),
          collapse = "\n"
        ))),
        error = function(e) utils::browseURL(out_path)
      )
    } else {
      utils::browseURL(out_path)
    }
  }

  herald_error(
    c(
      "Spec has {n_issues} issue{?s} that must be fixed before validation.",
      "i" = "Report opened in viewer: {.path {out_path}}",
      "i" = "Fix the spec and re-run {.fn validate}."
    ),
    class = "herald_error_validation",
    call = call
  )
}

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

#' Load spec_rules.rds (lazy, cached per session)
#' @noRd
.spec_rules <- function() {
  path <- system.file(
    "rules",
    "spec_rules.rds",
    package = "herald",
    mustWork = FALSE
  )
  if (!nzchar(path) || !file.exists(path)) {
    herald_error(
      c(
        "spec_rules.rds not found.",
        "i" = "Run {.code Rscript tools/compile-rules.R} to rebuild it."
      ),
      class = "herald_error_file"
    )
  }
  readRDS(path)
}

#' Build named list of virtual datasets from spec slots
#' @noRd
.spec_datasets <- function(spec) {
  ensure_df <- function(x, min_cols = character()) {
    if (!is.data.frame(x) || nrow(x) == 0L) {
      if (length(min_cols) > 0L) {
        df <- as.data.frame(
          lapply(stats::setNames(min_cols, min_cols), function(.) character()),
          stringsAsFactors = FALSE
        )
        return(df)
      }
      return(data.frame())
    }
    x
  }

  list(
    Define_Dataset_Metadata = ensure_df(spec$ds_spec, "dataset"),
    Define_Variable_Metadata = ensure_df(
      spec$var_spec,
      c("dataset", "variable")
    ),
    Define_Study_Metadata = ensure_df(spec$study, "attribute"),
    Define_ValueLevel_Metadata = ensure_df(spec$value_spec),
    Define_Codelist_Metadata = ensure_df(spec$codelist),
    Define_ARM_Metadata = ensure_df(spec$arm_displays),
    Define_ARM_Result_Metadata = ensure_df(spec$arm_results)
  )
}

#' Which virtual datasets should a spec rule run against?
#'
#' If scope$datasets is specified: use those (intersected with available).
#' Otherwise: find virtual datasets that contain ALL check_tree field names
#' (skipping virtual computed names starting with "__").
#' @noRd
.spec_scoped_datasets <- function(rule, datasets) {
  explicit <- as.character(unlist(rule$scope$datasets %||% character()))
  explicit <- explicit[nzchar(explicit) & !is.na(explicit)]

  if (length(explicit) > 0L) {
    return(intersect(explicit, names(datasets)))
  }

  required <- .check_tree_field_names(rule$check_tree)
  if (length(required) == 0L) {
    return(names(datasets))
  }

  keep <- vapply(
    datasets,
    function(d) {
      if (!is.data.frame(d) || nrow(d) == 0L) {
        return(FALSE)
      }
      all(required %in% names(d))
    },
    logical(1L)
  )

  names(datasets)[keep]
}

#' Extract non-virtual field names referenced in a check_tree
#' @noRd
.check_tree_field_names <- function(ct) {
  out <- character()
  walk <- function(x) {
    if (is.list(x)) {
      v <- x[["name"]]
      if (
        is.character(v) && length(v) == 1L && nzchar(v) && !startsWith(v, "__")
      ) {
        out <<- c(out, v)
      }
      lapply(x, walk)
    }
  }
  walk(ct)
  unique(out)
}

#' Extract the primary variable name from the outermost check_tree leaf
#' @noRd
.leaf_name <- function(ct) {
  if (is.null(ct)) {
    return(NA_character_)
  }
  first_leaf <- function(x) {
    if (!is.list(x)) {
      return(NA_character_)
    }
    if (!is.null(x$name) && !is.null(x$operator)) {
      return(x$name)
    }
    for (child in x) {
      v <- first_leaf(child)
      if (!is.na(v)) return(v)
    }
    NA_character_
  }
  first_leaf(ct)
}
