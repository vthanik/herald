# -----------------------------------------------------------------------------
# val-result.R — herald_result S3 + print/format
# -----------------------------------------------------------------------------
# validate() returns a herald_result. Users access fields via $. HTML/XLSX/JSON
# renderers consume this object.
#
# 4-state banner logic (from plan):
#   "Submission Ready"  rules_applied > 0 && reject == 0 && high == 0
#   "Issues Found"      reject + high > 0
#   "Spec Checks Only"  rules_applied == 0 (no conformance rules ran)
#   "Incomplete"        rules_applied < rules_total * 0.9

#' Construct a herald_result
#' @param findings tibble from emit_findings()
#' @param rules_applied integer count of rules that fired or emitted advisory
#' @param rules_total integer count of rules loaded for this profile
#' @param datasets_checked character vector of dataset names
#' @param duration difftime object, elapsed time of the validate() call
#' @param profile character(1), config profile id (or NA)
#' @param config_hash character(1), sha256 of the resolved profile
#' @param dataset_meta named list of dataset metadata (rows, cols, label, class)
#' @param rule_catalog tibble of the rules that were run (id, severity, etc.)
#' @param op_errors list of operator errors collected during the run
#' @param skipped_refs list of missing reference-data buckets (datasets +
#'   dictionaries) each carrying `rule_ids` and an actionable `hint`.
#'   Populated from `ctx$missing_refs` by `.finalize_skipped_refs()`.
#' @noRd
new_herald_result <- function(
  findings         = empty_findings(),
  rules_applied    = 0L,
  rules_total      = 0L,
  datasets_checked = character(),
  duration         = as.difftime(0, units = "secs"),
  profile          = NA_character_,
  config_hash      = NA_character_,
  dataset_meta     = list(),
  rule_catalog     = tibble::tibble(),
  op_errors        = list(),
  skipped_refs     = list(datasets = list(), dictionaries = list())
) {
  structure(
    list(
      findings         = findings,
      rules_applied    = as.integer(rules_applied),
      rules_total      = as.integer(rules_total),
      datasets_checked = datasets_checked,
      duration         = duration,
      timestamp        = Sys.time(),
      profile          = profile,
      config_hash      = config_hash,
      dataset_meta     = dataset_meta,
      rule_catalog     = rule_catalog,
      op_errors        = op_errors,
      skipped_refs     = skipped_refs
    ),
    class = c("herald_result", "list")
  )
}

#' Compute the readiness banner state
#' @noRd
readiness_state <- function(r) {
  rules_applied <- r$rules_applied
  rules_total   <- r$rules_total
  if (rules_total == 0L) return("Spec Checks Only")
  if (rules_applied < rules_total * 0.9) return("Incomplete")

  sev <- r$findings$severity[r$findings$status == "fired"]
  n_reject <- sum(sev == "Reject", na.rm = TRUE)
  n_high   <- sum(sev == "High",   na.rm = TRUE)
  if (n_reject + n_high > 0L) return("Issues Found")
  "Submission Ready"
}

#' Print a herald_result
#' @param x A `herald_result` object.
#' @param ... Ignored.
#' @return `x` invisibly.
#' @export
print.herald_result <- function(x, ...) {
  state <- readiness_state(x)
  col   <- switch(state,
    "Submission Ready"   = "green",
    "Issues Found"       = "red",
    "Spec Checks Only"   = "grey",
    "Incomplete"         = "yellow"
  )
  banner <- switch(state,
    "Submission Ready"   = cli::col_green(state),
    "Issues Found"       = cli::col_red(state),
    "Spec Checks Only"   = cli::col_grey(state),
    "Incomplete"         = cli::col_yellow(state)
  )

  cli::cli_rule(left = paste0("herald validation -- ", banner))
  cli::cli_text("{.strong Rules:} {x$rules_applied}/{x$rules_total} applied")
  cli::cli_text("{.strong Datasets checked:} {length(x$datasets_checked)}")

  # Finding counts by severity
  if (nrow(x$findings) > 0L) {
    fired <- x$findings[x$findings$status == "fired", , drop = FALSE]
    adv   <- x$findings[x$findings$status == "advisory", , drop = FALSE]
    cli::cli_text("{.strong Findings:} {nrow(fired)} fired, {nrow(adv)} advisory")
    if (nrow(fired) > 0L) {
      counts <- sort(table(fired$severity), decreasing = TRUE)
      for (s in names(counts)) {
        cli::cli_text("  {.field {s}}: {counts[[s]]}")
      }
    }
  } else {
    cli::cli_text("{.strong Findings:} 0")
  }

  cli::cli_text("{.strong Duration:} {format(x$duration)}")
  if (!is.na(x$profile) && nzchar(x$profile)) {
    cli::cli_text("{.strong Profile:} {x$profile}")
  }
  if (length(x$op_errors) > 0L) {
    cli::cli_alert_warning("{length(x$op_errors)} operator error{?s} during run")
  }
  invisible(x)
}

#' Summarise a herald_result
#' @param object A `herald_result` object.
#' @param ... Ignored.
#' @return A named list with `state`, `rules_applied`, `rules_total`,
#'   `datasets_checked`, `n_findings_fired`, `n_findings_advisory`,
#'   `severity_counts`, `duration`, and `timestamp`.
#' @export
summary.herald_result <- function(object, ...) {
  list(
    state            = readiness_state(object),
    rules_applied    = object$rules_applied,
    rules_total      = object$rules_total,
    datasets_checked = object$datasets_checked,
    n_findings_fired    = sum(object$findings$status == "fired"),
    n_findings_advisory = sum(object$findings$status == "advisory"),
    severity_counts  = table(object$findings$severity[object$findings$status == "fired"]),
    duration         = object$duration,
    timestamp        = object$timestamp
  )
}
