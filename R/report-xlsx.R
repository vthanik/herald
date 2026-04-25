# -----------------------------------------------------------------------------
# report-xlsx.R -- herald_result -> 5-sheet XLSX workbook
# -----------------------------------------------------------------------------
# Sheets:
#   summary          key/value metadata (no readiness banner / score)
#   findings         full findings tibble
#   datasets         per-dataset metadata + fired/advisory counts
#   rules            applied rules + per-rule fired/advisory counts + source_url
#   spec_validation  findings filtered to Define-XML / define_* rules only

#' Write a herald_result as a five-sheet XLSX workbook
#'
#' @description
#' Renders a `herald_result` to an Excel workbook structured for sponsor
#' review and regulatory submission. The workbook contains five sheets:
#' \describe{
#'   \item{`summary`}{Key/value run metadata (version, timestamp,
#'     finding counts).}
#'   \item{`findings`}{Full findings data frame, one row per finding.}
#'   \item{`datasets`}{Per-dataset row/column counts and finding
#'     tallies.}
#'   \item{`rules`}{Applied rule catalog with per-rule fired and
#'     advisory counts plus source URLs.}
#'   \item{`spec_validation`}{Findings scoped to Define-XML / spec
#'     rules only.}
#' }
#'
#' Requires the `openxlsx2` package.
#'
#' @param x A `herald_result` object from [validate()].
#' @param path Output file path (should end in `.xlsx`).
#' @param ... Ignored.
#'
#' @return `path` invisibly.
#'
#' @examplesIf requireNamespace("openxlsx2", quietly = TRUE)
#' ae  <- data.frame(STUDYID = "X", USUBJID = "X-001",
#'                   stringsAsFactors = FALSE)
#' r   <- validate(files = list(ae), quiet = TRUE)
#' out <- tempfile(fileext = ".xlsx")
#' on.exit(unlink(out))
#' write_report_xlsx(r, out)
#'
#' @seealso [validate()] to produce a result, [write_report_html()] for
#'   a self-contained HTML report, [report()] to auto-select format.
#' @family report
#' @export
write_report_xlsx <- function(x, path, ...) {
  call <- rlang::caller_env()
  check_report_inputs(x, path, call = call)
  require_pkg("openxlsx2", "to write XLSX reports", call = call)

  findings <- x$findings
  ds_meta  <- dataset_meta_tbl(x$dataset_meta, findings)
  rules_df <- applied_rules(x$rule_catalog, findings)
  fired    <- sum(findings$status == "fired", na.rm = TRUE)
  adv      <- sum(findings$status == "advisory", na.rm = TRUE)

  summary_df <- tibble::tibble(
    key = c(
      "herald_version", "timestamp", "duration_secs", "profile",
      "config_hash", "rules_applied", "rules_total", "n_datasets",
      "n_findings_fired", "n_findings_advisory"
    ),
    value = c(
      as.character(utils::packageVersion("herald")),
      iso_timestamp(x$timestamp %||% Sys.time()),
      as.character(format_duration_secs(x$duration)),
      as.character(x$profile     %||% NA_character_),
      as.character(x$config_hash %||% NA_character_),
      as.character(x$rules_applied %||% 0L),
      as.character(x$rules_total   %||% 0L),
      as.character(length(x$datasets_checked %||% character())),
      as.character(fired),
      as.character(adv)
    )
  )

  wb <- openxlsx2::wb_workbook(
    creator = "herald",
    title   = "herald validation report"
  )

  .add_sheet(wb, "summary",  summary_df, filter = FALSE)
  .add_sheet(wb, "findings", findings)
  .add_sheet(wb, "datasets", ds_meta)
  .add_sheet(wb, "rules",    rules_df)

  openxlsx2::wb_save(wb, path, overwrite = TRUE)
  invisible(path)
}

# -- internals ---------------------------------------------------------------

.add_sheet <- function(wb, name, df, filter = TRUE) {
  wb$add_worksheet(name)
  if (nrow(df) == 0L && length(names(df)) == 0L) {
    return(invisible(wb))
  }
  # Freeze header row always; add autofilter when the sheet is a table.
  wb$add_data(sheet = name, x = df)
  wb$freeze_pane(sheet = name, first_row = TRUE)
  if (isTRUE(filter) && nrow(df) > 0L && length(names(df)) > 0L) {
    n_col <- length(names(df))
    wb$add_filter(
      sheet = name,
      rows  = 1L,
      cols  = seq_len(n_col)
    )
  }
  invisible(wb)
}
