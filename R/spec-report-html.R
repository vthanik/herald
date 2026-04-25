# --------------------------------------------------------------------------
# spec-report-html.R -- spec validation findings -> self-contained HTML
# --------------------------------------------------------------------------
# Standalone report for validate_spec() pre-flight findings.
# NOT part of the conformance report (write_report_html).
# Designed for narrow IDE preview panes (Positron/RStudio viewer).

#' Write spec validation findings as a self-contained HTML report
#'
#' @description
#' Produces a standalone, self-contained HTML file listing spec issues.
#' Opened automatically by [validate_spec()] before aborting so the
#' programmer can see and fix issues.
#'
#' @param findings Findings tibble (output of the spec engine, same schema
#'   as `empty_findings()`).
#' @param path Output file path.
#' @return `path`, invisibly.
#' @noRd
write_spec_report_html <- function(findings, path) {
  tmpl <- .spec_report_template()

  n_fired <- sum(findings$status == "fired",    na.rm = TRUE)
  n_adv   <- sum(findings$status == "advisory", na.rm = TRUE)

  subs <- list(
    "{{TITLE}}"         = htmlesc(paste0("Spec Issues -- ", Sys.Date())),
    "{{TIMESTAMP}}"     = htmlesc(iso_timestamp(Sys.time())),
    "{{N_FIRED}}"       = htmlesc(.fmt_int(n_fired)),
    "{{N_ADVISORY}}"    = htmlesc(.fmt_int(n_adv)),
    "{{FINDINGS_ROWS}}" = .spec_findings_rows(findings)
  )

  html <- .render_template(tmpl, subs)
  writeLines(html, path, useBytes = TRUE)
  invisible(path)
}

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

.spec_report_template <- function() {
  p <- system.file("report", "spec-template.html", package = "herald")
  if (nzchar(p) && file.exists(p)) return(paste(readLines(p, warn = FALSE), collapse = "\n"))
  here <- file.path("inst", "report", "spec-template.html")
  if (file.exists(here)) return(paste(readLines(here, warn = FALSE), collapse = "\n"))
  stop("spec-template.html not found")
}

.spec_findings_rows <- function(findings) {
  if (!is.data.frame(findings) || nrow(findings) == 0L) {
    return('<tr><td colspan="5" class="empty-msg">No issues found.</td></tr>')
  }

  fired <- findings[!is.na(findings$status) & findings$status == "fired", , drop = FALSE]
  if (nrow(fired) == 0L) {
    return('<tr><td colspan="5" class="empty-msg">No fired issues.</td></tr>')
  }

  sev_class <- function(s) {
    switch(tolower(as.character(s %||% "")),
      error   = "sev-reject",
      reject  = "sev-reject",
      high    = "sev-high",
      warning = "sev-high",
      medium  = "sev-medium",
      "sev-low"
    )
  }

  rows <- vapply(seq_len(nrow(fired)), function(i) {
    r   <- fired[i, , drop = FALSE]
    sev <- as.character(r$severity %||% "")
    ds  <- as.character(r$dataset  %||% "")
    vr  <- as.character(r$variable %||% "")
    rw  <- as.character(r$row      %||% "")
    val <- as.character(r$value    %||% "")
    msg <- as.character(r$message  %||% "")

    loc <- if (nzchar(ds)) {
      parts <- ds
      if (nzchar(vr)) parts <- paste0(parts, " / ", vr)
      if (nzchar(rw)) parts <- paste0(parts, " row ", rw)
      parts
    } else ""

    paste0(
      '<tr>',
        '<td><span class="sev-badge ', sev_class(sev), '">',
          htmlesc(toupper(sev)), '</span></td>',
        '<td class="mono">', htmlesc(as.character(r$rule_id %||% "")), '</td>',
        '<td>', htmlesc(loc), '</td>',
        '<td class="val-cell">', htmlesc(val), '</td>',
        '<td>', htmlesc(msg), '</td>',
      '</tr>'
    )
  }, character(1L))

  paste(rows, collapse = "\n")
}
