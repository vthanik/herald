# -----------------------------------------------------------------------------
# report-html.R -- herald_result -> self-contained archival HTML report
# -----------------------------------------------------------------------------
# The template lives at `inst/report/template.html` (designed as a clinical
# SEC-10K x CDISC-appendix archival document). This module fills 8
# placeholders with pre-escaped HTML fragments assembled from the result.

#' Write a herald_result as a self-contained HTML report
#'
#' @param x A `herald_result` object returned by [validate()].
#' @param path Output file path (should end in `.html`).
#' @param title Optional document title. Defaults to
#'   `"Herald validation -- <timestamp>"`.
#' @param ... Ignored.
#' @return `path`, invisibly.
#' @family report
#' @export
write_report_html <- function(x, path, title = NULL, ...) {
  call <- rlang::caller_env()
  check_report_inputs(x, path, call = call)

  tmpl_path <- .report_template_path()
  if (!file.exists(tmpl_path)) {
    herald_error_report(
      "Report template not found at {.path {tmpl_path}}.",
      call = call
    )
  }
  tmpl <- paste(readLines(tmpl_path, warn = FALSE), collapse = "\n")

  ts      <- iso_timestamp(x$timestamp %||% Sys.time())
  version <- as.character(utils::packageVersion("herald"))
  if (is.null(title)) {
    title <- paste0("Herald validation ", substr(ts, 1, 10))
  }

  findings <- x$findings
  n_fired  <- sum(findings$status == "fired",    na.rm = TRUE)
  n_adv    <- sum(findings$status == "advisory", na.rm = TRUE)
  n_ds     <- length(x$datasets_checked %||% character())
  skipped  <- x$skipped_refs %||% list(datasets = list(),
                                        dictionaries = list())
  n_skipped_rules <- length(unique(unlist(c(
    lapply(skipped$datasets, `[[`, "rule_ids"),
    lapply(skipped$dictionaries, `[[`, "rule_ids")
  ))))
  counts   <- summarise_counts(findings)
  ds_tbl   <- dataset_meta_tbl(x$dataset_meta, findings)
  rules_df <- applied_rules(x$rule_catalog, findings)

  rendered <- .render_template(
    tmpl,
    list(
      "{{TITLE}}"         = htmlesc(title),
      "{{FOLIO_RIGHT}}"   = .html_folio_right(version, ts),
      "{{HEADER_META}}"   = .html_header_meta(version, ts, n_ds, n_fired, n_adv,
                                              x$rules_applied, x$rules_total,
                                              format_duration_secs(x$duration),
                                              n_skipped_rules),
      "{{TAB_ISSUES}}"    = paste0(
        .html_skipped_refs(skipped),
        .html_tab_issues(counts, n_fired, n_adv)
      ),
      "{{TAB_DETAILS}}"   = .html_tab_details(findings),
      "{{TAB_DATASETS}}"  = .html_tab_datasets(ds_tbl),
      "{{TAB_RULES}}"    = .html_tab_rules(rules_df),
      "{{COLOPHON_SIG}}" = paste0("HERALD &middot; v", htmlesc(version))
    )
  )

  writeLines(rendered, path, useBytes = TRUE)
  invisible(path)
}

# -- template plumbing -------------------------------------------------------

.report_template_path <- function() {
  p <- system.file("report", "template.html", package = "herald")
  if (nzchar(p)) return(p)
  # devtools::load_all() fallback: source tree
  here <- file.path("inst", "report", "template.html")
  if (file.exists(here)) here else p
}

.render_template <- function(tmpl, subs) {
  for (k in names(subs)) {
    tmpl <- gsub(k, subs[[k]], tmpl, fixed = TRUE)
  }
  tmpl
}

# -- header blocks -----------------------------------------------------------

.html_folio_right <- function(version, ts) {
  paste0(
    "HERALD&nbsp;v", htmlesc(version), "<br>",
    htmlesc(ts)
  )
}

.html_header_meta <- function(version, ts, n_ds, n_fired, n_adv,
                              rules_applied, rules_total, duration_secs,
                              n_skipped = 0L) {
  cell <- function(k, v, mono = FALSE) {
    cls <- if (isTRUE(mono)) "meta-v mono" else "meta-v"
    paste0(
      '<div class="meta-cell">',
        '<p class="meta-k">', htmlesc(k), '</p>',
        '<div class="', cls, '">', v, '</div>',
      '</div>'
    )
  }
  cells <- paste0(
    cell("Issued",            htmlesc(ts), mono = TRUE),
    cell("Engine",            paste0("v", htmlesc(version))),
    cell("Datasets",          .fmt_int(n_ds)),
    cell("Findings (fired)",  .fmt_int(n_fired)),
    cell("Advisories",        .fmt_int(n_adv))
  )
  if (as.integer(n_skipped %||% 0L) > 0L) {
    cells <- paste0(cells, cell("Skipped (ref data)", .fmt_int(n_skipped)))
  }
  paste0(
    '<div class="meta-grid">',
      cells,
    '</div>',
    '<p class="eyebrow" style="margin-top:14px;">',
      'Rules exercised ', .fmt_int(rules_applied %||% 0L),
      ' of ', .fmt_int(rules_total %||% 0L),
      ' &middot; run time ', htmlesc(format(duration_secs)), 's.',
    '</p>'
  )
}

# -- Skipped reference data banner (Q33) -------------------------------------
# Renders one actionable row per missing (kind, name), listing every
# rule that couldn't evaluate because the reference is absent.
# Emitted at the top of the Issues tab so reviewers see it first
# and have a direct instruction to fix the gap.

.html_skipped_refs <- function(skipped) {
  if (!is.list(skipped)) return("")
  ds_entries   <- skipped$datasets     %||% list()
  dict_entries <- skipped$dictionaries %||% list()
  if (length(ds_entries) == 0L && length(dict_entries) == 0L) return("")

  entry_row <- function(nm, e, kind_label) {
    rule_list <- paste(vapply(e$rule_ids %||% character(),
                              htmlesc, character(1)),
                       collapse = ", ")
    paste0(
      '<li class="sev-row">',
        '<span class="sev-label">', htmlesc(kind_label), ': ',
          htmlesc(nm), '</span>',
        '<span class="sev-count">',
          .fmt_int(length(e$rule_ids %||% character())),
          ' rule', if (length(e$rule_ids %||% character()) == 1L) '' else 's',
        '</span>',
        '<div class="skipped-hint" style="grid-column: 1 / -1;',
            'margin-top:6px; font-family: var(--sans); font-size: 12px;',
            'color: var(--ink-soft);">',
          htmlesc(e$hint %||% ""),
          '<br>',
          '<span style="font-family: var(--mono); font-size: 11px;',
              'color: var(--muted);">', rule_list, '</span>',
        '</div>',
      '</li>'
    )
  }

  rows <- character()
  for (nm in names(ds_entries))  rows <- c(rows,
    entry_row(nm, ds_entries[[nm]], "Dataset"))
  for (nm in names(dict_entries)) rows <- c(rows,
    entry_row(nm, dict_entries[[nm]], "Dictionary"))

  paste0(
    '<section style="margin-bottom:28px;">',
      '<h2 class="section-head">Missing reference data</h2>',
      '<p class="eyebrow" style="margin-bottom:12px;">',
        'The rules below could not evaluate. Provide the named ',
        'source and rerun to unlock them.',
      '</p>',
      '<ul class="sev-list">', paste(rows, collapse = ""), '</ul>',
    '</section>'
  )
}

# -- Issues tab --------------------------------------------------------------

.html_tab_issues <- function(counts, n_fired, n_adv) {
  if (n_fired == 0L && n_adv == 0L) {
    return(paste0(
      '<p class="empty">No findings emitted. Either the rule catalog found ',
      'nothing to flag, or no rules matched the supplied datasets.</p>'
    ))
  }
  sev_order <- c("Reject", "High", "Medium", "Low")
  sev_tab   <- counts$by_severity
  sev_rows  <- vapply(sev_order, function(s) {
    n <- as.integer(sev_tab[s] %|NA|% 0L)
    paste0(
      '<li class="sev-row sev-', tolower(s), '">',
        '<span class="sev-mark" aria-hidden="true"></span>',
        '<span class="sev-label">', htmlesc(s), '</span>',
        '<span class="sev-count">', .fmt_int(n), '</span>',
      '</li>'
    )
  }, character(1))

  # Top 10 rules by fired count (already sorted by summarise_counts)
  top <- counts$by_rule
  top <- utils::head(top, 10L)
  top_rows <- if (length(top) == 0L) {
    '<li><span class="rid">&mdash;</span><span class="cnt">0</span></li>'
  } else {
    vapply(seq_along(top), function(i) {
      paste0(
        '<li>',
          '<span class="rid">', htmlesc(names(top)[i]), '</span>',
          '<span class="cnt">', .fmt_int(top[[i]]), '</span>',
        '</li>'
      )
    }, character(1))
  }

  paste0(
    '<div class="two-col">',
      '<section>',
        '<h2 class="section-head">By severity</h2>',
        '<ul class="sev-list">', paste(sev_rows, collapse = ""), '</ul>',
      '</section>',
      '<section>',
        '<h2 class="section-head">Most-cited rules</h2>',
        '<ol class="top-rules">', paste(top_rows, collapse = ""), '</ol>',
      '</section>',
    '</div>'
  )
}

# -- Issue Details -----------------------------------------------------------

.html_tab_details <- function(findings) {
  if (!is.data.frame(findings) || nrow(findings) == 0L) {
    return('<tr><td colspan="8" class="empty">No findings to report.</td></tr>')
  }
  max_rows <- 2000L
  trimmed  <- nrow(findings) > max_rows
  rows <- if (trimmed) findings[seq_len(max_rows), , drop = FALSE] else findings

  sev_class <- paste0("sev-", tolower(rows$severity %|NA|% "low"))
  out <- character(nrow(rows))
  for (i in seq_len(nrow(rows))) {
    out[i] <- paste0(
      '<tr class="', sev_class[i], '">',
        '<td class="mono">', htmlesc(.na_blank(rows$rule_id[i])),  '</td>',
        '<td class="sev-cell">', htmlesc(.na_blank(rows$severity[i])), '</td>',
        '<td>',       htmlesc(.na_blank(rows$status[i])),   '</td>',
        '<td class="mono">', htmlesc(.na_blank(rows$dataset[i])),  '</td>',
        '<td class="mono">', htmlesc(.na_blank(rows$variable[i])), '</td>',
        '<td class="num">',  .fmt_row(rows$row[i]),                '</td>',
        '<td class="mono">', htmlesc(.na_blank(rows$value[i])),    '</td>',
        '<td class="wide">', htmlesc(.na_blank(rows$message[i])),  '</td>',
      '</tr>'
    )
  }
  if (trimmed) {
    out <- c(out, paste0(
      '<tr><td colspan="8" class="empty">',
      .fmt_int(nrow(findings) - max_rows),
      ' additional findings omitted from this HTML view. ',
      'Open the JSON or XLSX report for the full list.',
      '</td></tr>'
    ))
  }
  paste(out, collapse = "\n")
}

# -- Datasets tab ------------------------------------------------------------

.html_tab_datasets <- function(ds_tbl) {
  if (nrow(ds_tbl) == 0L) {
    return('<tr><td colspan="7" class="empty">No datasets examined.</td></tr>')
  }
  out <- character(nrow(ds_tbl))
  for (i in seq_len(nrow(ds_tbl))) {
    out[i] <- paste0(
      '<tr>',
        '<td class="mono ink">', htmlesc(.na_blank(ds_tbl$name[i])),  '</td>',
        '<td>',       htmlesc(.na_blank(ds_tbl$class[i])), '</td>',
        '<td class="num">', .fmt_int(ds_tbl$rows[i]),      '</td>',
        '<td class="num">', .fmt_int(ds_tbl$cols[i]),      '</td>',
        '<td class="wide">', htmlesc(.na_blank(ds_tbl$label[i])),  '</td>',
        '<td class="num">', .fmt_int(ds_tbl$fired_n[i]),    '</td>',
        '<td class="num">', .fmt_int(ds_tbl$advisory_n[i]), '</td>',
      '</tr>'
    )
  }
  paste(out, collapse = "\n")
}

# -- Rules tab ---------------------------------------------------------------

.html_tab_rules <- function(rules_df) {
  if (nrow(rules_df) == 0L) {
    return('<tr><td colspan="8" class="empty">No rules in the applied catalog.</td></tr>')
  }
  sev_class <- paste0("sev-", tolower(rules_df$severity %|NA|% "low"))
  has_url <- "source_url" %in% names(rules_df)
  out <- character(nrow(rules_df))
  for (i in seq_len(nrow(rules_df))) {
    src_cell <- if (has_url) .source_link(rules_df$source_url[i]) else "&mdash;"
    out[i] <- paste0(
      '<tr class="', sev_class[i], '">',
        '<td class="mono ink">', htmlesc(.na_blank(rules_df$id[i])), '</td>',
        '<td class="sev-cell">', htmlesc(.na_blank(rules_df$severity[i])),  '</td>',
        '<td>',       htmlesc(.na_blank(rules_df$authority[i])), '</td>',
        '<td>',       htmlesc(.na_blank(rules_df$standard[i])),  '</td>',
        '<td class="num">', .fmt_int(rules_df$fired_n[i]),        '</td>',
        '<td class="num">', .fmt_int(rules_df$advisory_n[i]),     '</td>',
        '<td>',       src_cell, '</td>',
        '<td class="wide">', htmlesc(.na_blank(rules_df$message[i])), '</td>',
      '</tr>'
    )
  }
  paste(out, collapse = "\n")
}

# -- small formatters --------------------------------------------------------

.na_blank <- function(x) {
  if (length(x) == 0L) return("")
  x <- as.character(x)
  ifelse(is.na(x), "", x)
}
.fmt_int <- function(n) {
  if (length(n) == 0L || is.na(n)) return("0")
  formatC(as.integer(n), big.mark = ",", format = "d")
}
.fmt_row <- function(n) {
  if (length(n) == 0L || is.na(n)) return("&mdash;")
  formatC(as.integer(n), big.mark = ",", format = "d")
}
.source_link <- function(url) {
  if (is.null(url) || length(url) == 0L || is.na(url) || !nzchar(url)) {
    return("&mdash;")
  }
  u <- htmlesc(as.character(url))
  paste0('<a href="', u, '" target="_blank" rel="noopener">source</a>')
}
