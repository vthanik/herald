# -----------------------------------------------------------------------------
# report.R -- herald_result -> HTML / XLSX / JSON
# -----------------------------------------------------------------------------
# Single public entry point `report()` dispatches on path extension or an
# explicit `format` arg. Low-level writers are exported for direct use in
# pipelines that already know which format they want.

#' Write a herald_result as an HTML, XLSX, or JSON report
#'
#' @description
#' Persists the result of [validate()] to disk in one of three
#' formats:
#'
#' * `"html"` -- a self-contained, offline-safe HTML report with
#'   Issues / Issue Details / Datasets / Rules tabs.
#' * `"xlsx"` -- a four-sheet workbook for SAS / Excel pipelines.
#' * `"json"` -- a canonical machine-readable JSON document suitable
#'   for CI diffing.
#'
#' @param x A `herald_result` object returned by [validate()].
#' @param path Output file path. The extension (`.html`, `.xlsx`,
#'   `.json`) is used to infer `format` when `format` is not supplied.
#' @param format Optional explicit format; one of `"html"`, `"xlsx"`,
#'   `"json"`. Defaults to the extension of `path`.
#' @param ... Passed to the underlying writer
#'   ([write_report_html()], [write_report_xlsx()],
#'   [write_report_json()]).
#'
#' @return `path`, invisibly.
#'
#' @examples
#' \dontrun{
#' r <- validate(files = list(AE = my_ae))
#' report(r, tempfile(fileext = ".json"))
#' report(r, tempfile(fileext = ".html"))
#' }
#'
#' @seealso [write_report_html()], [write_report_xlsx()],
#'   [write_report_json()].
#' @family report
#' @export
report <- function(x, path, format = NULL, ...) {
  call <- rlang::caller_env()
  check_report_inputs(x, path, call = call)
  fmt  <- resolve_report_format(path, format, call = call)
  switch(
    fmt,
    html = write_report_html(x, path, ...),
    xlsx = write_report_xlsx(x, path, ...),
    json = write_report_json(x, path, ...)
  )
  invisible(path)
}

#' Write a herald_result as canonical JSON
#'
#' @description
#' Serialises a `herald_result` to a UTF-8 JSON document with a stable
#' key order. Intended as the machine-readable artifact for CI
#' pipelines and diffing.
#'
#' @param x A `herald_result` object returned by [validate()].
#' @param path Output file path.
#' @param pretty Logical; pretty-print with two-space indent. Default
#'   `TRUE`.
#' @param ... Ignored.
#'
#' @return `path`, invisibly.
#' @family report
#' @export
write_report_json <- function(x, path, pretty = TRUE, ...) {
  call <- rlang::caller_env()
  check_report_inputs(x, path, call = call)
  require_pkg("jsonlite", "to write JSON reports", call = call)

  counts   <- summarise_counts(x$findings)
  ds_meta  <- dataset_meta_tbl(x$dataset_meta, x$findings)
  rules_df <- applied_rules(x$rule_catalog, x$findings)

  obj <- list(
    herald_version   = as.character(utils::packageVersion("herald")),
    timestamp        = iso_timestamp(x$timestamp %||% Sys.time()),
    duration_secs    = format_duration_secs(x$duration),
    profile          = if (is.na(x$profile %||% NA)) NULL else as.character(x$profile),
    config_hash      = if (is.na(x$config_hash %||% NA)) NULL else as.character(x$config_hash),
    rules_applied    = as.integer(x$rules_applied %||% 0L),
    rules_total      = as.integer(x$rules_total   %||% 0L),
    datasets_checked = as.character(x$datasets_checked %||% character()),
    counts = list(
      by_status   = as.list(counts$by_status),
      by_severity = as.list(counts$by_severity),
      by_dataset  = as.list(counts$by_dataset),
      by_rule     = as.list(counts$by_rule)
    ),
    findings     = .findings_as_list(x$findings),
    dataset_meta = .df_as_list(ds_meta),
    rule_catalog = .df_as_list(rules_df),
    op_errors    = op_errors_list(x$op_errors)
  )

  json <- jsonlite::toJSON(
    obj,
    auto_unbox = TRUE,
    null       = "null",
    na         = "null",
    pretty     = isTRUE(pretty),
    digits     = NA
  )
  writeLines(json, path, useBytes = TRUE)
  invisible(path)
}

# -- internals ---------------------------------------------------------------

.findings_as_list <- function(findings) {
  if (!is.data.frame(findings) || nrow(findings) == 0L) return(list())
  .df_as_list(findings)
}

#' Data-frame -> list-of-row-objects for jsonlite::toJSON.
#' @noRd
.df_as_list <- function(df) {
  if (!is.data.frame(df) || nrow(df) == 0L) return(list())
  n  <- nrow(df)
  nm <- names(df)
  out <- vector("list", n)
  for (i in seq_len(n)) {
    row <- lapply(nm, function(k) {
      v <- df[[k]][i]
      if (length(v) == 1L && is.na(v)) NULL else v
    })
    names(row) <- nm
    out[[i]] <- row
  }
  out
}
