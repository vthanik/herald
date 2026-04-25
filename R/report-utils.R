# -----------------------------------------------------------------------------
# report-utils.R -- shared helpers used by all three report renderers
# -----------------------------------------------------------------------------
# summarise_counts() is the single source of truth for the numbers that
# appear in the HTML, XLSX, and JSON outputs -- so the three files always
# agree on totals.

#' Local NA-coalesce (NA -> replacement). Internal to report helpers.
#' @noRd
`%|NA|%` <- function(x, y) {
  x[is.na(x)] <- y
  x
}

#' Tabulate a character column as a sorted named integer vector.
#' @noRd
tally_col <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0L) {
    return(stats::setNames(integer(), character()))
  }
  tab <- table(x)
  vals <- as.integer(tab)
  names(vals) <- names(tab)
  vals[order(-vals, names(vals))]
}

#' Tally findings by status / severity / dataset / rule
#' @param findings herald_result$findings tibble
#' @return named list of named integer vectors
#' @noRd
summarise_counts <- function(findings) {
  cols <- c("status", "severity", "dataset", "rule_id")
  empty <- stats::setNames(integer(), character())
  out <- lapply(cols, function(col) {
    if (!col %in% names(findings) || nrow(findings) == 0L) {
      empty
    } else {
      tally_col(findings[[col]])
    }
  })
  stats::setNames(out, c("by_status", "by_severity", "by_dataset", "by_rule"))
}

#' Join per-rule fired/advisory counts onto the applied rule catalog
#' @param rule_catalog a tibble with at least `id`
#' @param findings herald_result$findings tibble
#' @return tibble with added integer columns `fired_n` and `advisory_n`
#' @noRd
applied_rules <- function(rule_catalog, findings) {
  if (!is.data.frame(rule_catalog) || nrow(rule_catalog) == 0L) {
    return(tibble::tibble(
      id = character(),
      authority = character(),
      standard = character(),
      severity = character(),
      message = character(),
      fired_n = integer(),
      advisory_n = integer()
    ))
  }
  f_tab <- tally_col(findings$rule_id[findings$status == "fired"])
  a_tab <- tally_col(findings$rule_id[findings$status == "advisory"])

  rc <- tibble::as_tibble(rule_catalog)
  rc$fired_n <- as.integer(f_tab[rc$id] %|NA|% 0L)
  rc$advisory_n <- as.integer(a_tab[rc$id] %|NA|% 0L)
  rc
}

#' Format a `difftime` as numeric seconds rounded to 2 dp
#' @noRd
format_duration_secs <- function(d) {
  if (is.null(d)) {
    return(0)
  }
  secs <- tryCatch(
    as.numeric(d, units = "secs"),
    error = function(e) suppressWarnings(as.numeric(d))
  )
  round(secs, 2)
}

#' Format a POSIXct as ISO-8601 UTC ("Z") timestamp
#' @noRd
iso_timestamp <- function(t = Sys.time()) {
  strftime(t, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

#' Flatten dataset_meta (named list of lists) into a tibble,
#' joining per-dataset fired/advisory counts.
#' @noRd
dataset_meta_tbl <- function(dataset_meta, findings) {
  if (length(dataset_meta) == 0L) {
    return(tibble::tibble(
      name = character(),
      rows = integer(),
      cols = integer(),
      class = character(),
      label = character(),
      fired_n = integer(),
      advisory_n = integer()
    ))
  }

  pull <- function(key, coercer, empty) {
    vapply(
      dataset_meta,
      function(m) {
        v <- m[[key]]
        if (is.null(v) || length(v) == 0L) empty else coercer(v)[[1L]]
      },
      coercer(empty)
    )
  }

  nms <- names(dataset_meta)
  f_tab <- tally_col(findings$dataset[findings$status == "fired"])
  a_tab <- tally_col(findings$dataset[findings$status == "advisory"])

  tibble::tibble(
    name = nms,
    rows = pull("rows", as.integer, NA_integer_),
    cols = pull("cols", as.integer, NA_integer_),
    class = pull("class", as.character, NA_character_),
    label = pull("label", as.character, NA_character_),
    fired_n = as.integer(f_tab[nms] %|NA|% 0L),
    advisory_n = as.integer(a_tab[nms] %|NA|% 0L)
  )
}

#' Normalise an op_errors list for serialisation
#' @noRd
op_errors_list <- function(op_errors) {
  if (length(op_errors) == 0L) {
    return(list())
  }
  lapply(op_errors, function(e) {
    list(
      rule_id = as.character(e$rule_id %||% NA_character_),
      operator = as.character(e$operator %||% NA_character_),
      dataset = as.character(e$dataset %||% NA_character_),
      message = as.character(e$message %||% NA_character_)
    )
  })
}

#' Infer the report format from an explicit arg or the file extension.
#' @noRd
resolve_report_format <- function(path, format, call = rlang::caller_env()) {
  if (!is.null(format)) {
    format <- tolower(as.character(format)[[1L]])
  } else {
    ext <- tolower(tools::file_ext(path))
    if (!nzchar(ext)) {
      herald_error_report(
        c(
          "Could not infer report format from {.path {path}}.",
          "i" = "Pass {.arg format} explicitly (\"html\", \"xlsx\", or \"json\")."
        ),
        call = call
      )
    }
    format <- ext
  }
  if (!format %in% c("html", "xlsx", "json")) {
    herald_error_report(
      "Unknown report format {.val {format}}. Expected \"html\", \"xlsx\", or \"json\".",
      call = call
    )
  }
  format
}

#' Guardrails shared by the three writers.
#' @noRd
check_report_inputs <- function(x, path, call = rlang::caller_env()) {
  if (!inherits(x, "herald_result")) {
    herald_error_report(
      "{.arg x} must be a {.cls herald_result}, not {.cls {class(x)[[1L]]}}.",
      call = call
    )
  }
  check_scalar_chr(path, call = call)
  parent <- dirname(path)
  if (!dir.exists(parent)) {
    herald_error_file(
      "Directory {.path {parent}} does not exist.",
      path = parent,
      call = call
    )
  }
  invisible(TRUE)
}
