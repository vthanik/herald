# =============================================================================
# tools/advisory.R -- maintainer work-queue helpers
# =============================================================================
#
# NOT shipped in the installed package (tools/ is in .Rbuildignore). These
# are helpers the herald maintainer uses to iterate on the narrative-rule
# authoring backlog. They are NOT intended for end-users.
#
# Usage (from the herald repo root):
#
#   source("tools/advisory.R")
#   r  <- validate("/sdtm/", spec = spec, quiet = TRUE)
#   wq <- advisory_report(r)
#   write_advisory_report(r, "my-advisories", format = "both")
#   cat(author_stub("CORE-000001"))
#   author_stub(r, dir = "tools/handauthored/drafts/")
#
# Assumes the herald package is loaded (via devtools::load_all() or
# library(herald)) before sourcing this file.

# --- advisory_report ---------------------------------------------------------

#' Programmer work-queue tibble from a herald_result
#' @keywords internal
advisory_report <- function(x) {
  stopifnot(inherits(x, "herald_result"))
  adv <- x$findings[x$findings$status == "advisory", , drop = FALSE]
  if (nrow(adv) == 0L) return(tibble::tibble())

  rule_ids <- unique(adv$rule_id)
  catalog  <- x$rule_catalog
  cat_rows <- catalog[catalog$id %in% rule_ids, , drop = FALSE]

  rules_rds    <- system.file("rules", "rules.rds", package = "herald")
  full_catalog <- if (nzchar(rules_rds)) readRDS(rules_rds) else NULL

  datasets_per_rule <- tapply(
    adv$dataset, adv$rule_id,
    function(v) paste(sort(unique(v)), collapse = ", ")
  )

  classify <- function(id) {
    if (is.null(full_catalog)) return("stalled")
    idx <- which(full_catalog$id == id)
    if (length(idx) == 0L) return("stalled")
    tree <- full_catalog$check_tree[[idx[1]]]
    if (!is.null(tree$narrative)) return("narrative")
    "stalled"
  }

  out <- tibble::tibble(
    kind      = vapply(rule_ids, classify, character(1)),
    id        = rule_ids,
    authority = vapply(rule_ids, function(r) cat_rows$authority[cat_rows$id == r][1], character(1)),
    standard  = vapply(rule_ids, function(r) cat_rows$standard[cat_rows$id == r][1],  character(1)),
    severity  = vapply(rule_ids, function(r) cat_rows$severity[cat_rows$id == r][1],  character(1)),
    message   = vapply(rule_ids, function(r) cat_rows$message[cat_rows$id == r][1],   character(1)),
    datasets_touched = as.character(datasets_per_rule[rule_ids])
  )

  out$note <- ifelse(
    out$kind == "narrative",
    "author check_tree from message + cited guidance",
    "operator tree returned NA; verify column availability or spec"
  )

  out[order(out$kind, out$authority, out$standard, out$id), ]
}

# --- write_advisory_report ---------------------------------------------------

#' Dump the advisory work-queue to CSV / markdown
#' @keywords internal
write_advisory_report <- function(result, path, format = c("md", "csv", "both")) {
  stopifnot(inherits(result, "herald_result"))
  format <- match.arg(format)

  wq <- advisory_report(result)
  if (nrow(wq) == 0L) {
    cli::cli_inform("No advisories to report.")
    return(invisible(character(0)))
  }

  stem  <- tools::file_path_sans_ext(path)
  paths <- character()

  if (format %in% c("md", "both")) {
    md_path <- paste0(stem, ".md")
    .write_advisory_md(wq, result, md_path)
    paths <- c(paths, md_path)
  }
  if (format %in% c("csv", "both")) {
    csv_path <- paste0(stem, ".csv")
    utils::write.csv(wq, csv_path, row.names = FALSE, na = "")
    paths <- c(paths, csv_path)
  }

  cli::cli_alert_success("Advisory report: {.path {paths}}")
  invisible(paths)
}

.write_advisory_md <- function(wq, result, path) {
  lines <- character()
  add <- function(...) lines <<- c(lines, paste0(...))

  add("# herald -- advisory work queue")
  add("")
  add("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
  add("")
  add("Rules scanned: ", result$rules_total)
  add("Rules applied: ", result$rules_applied)
  add("Datasets: ", paste(result$datasets_checked, collapse = ", "))
  add("")
  add("**", nrow(wq), " advisory rules** await programmer attention:")
  add("")
  add("- `narrative` (**", sum(wq$kind == "narrative"),
      "**): CDISC XLSX rules with only rule text; need predicate authoring")
  add("- `stalled` (**", sum(wq$kind == "stalled"),
      "**): operator tree returned NA for every row; usually a missing column or spec gap")
  add("")

  add("## Narrative rules -- author these predicates")
  add("")
  for (std in sort(unique(wq$standard[wq$kind == "narrative"]))) {
    add("### ", std); add("")
    sub <- wq[wq$kind == "narrative" & wq$standard == std, , drop = FALSE]
    for (i in seq_len(nrow(sub))) {
      add("- **", sub$id[i], "** (", sub$authority[i], " / ", sub$severity[i], ")  ")
      add("  _datasets_: ", sub$datasets_touched[i], "  ")
      add("  _rule_: ", sub$message[i])
    }
    add("")
  }

  add("## Stalled rules -- investigate")
  add("")
  for (std in sort(unique(wq$standard[wq$kind == "stalled"]))) {
    add("### ", std); add("")
    sub <- wq[wq$kind == "stalled" & wq$standard == std, , drop = FALSE]
    for (i in seq_len(nrow(sub))) {
      add("- **", sub$id[i], "** (", sub$authority[i], " / ", sub$severity[i], ")  ")
      add("  _datasets_: ", sub$datasets_touched[i], "  ")
      add("  _rule_: ", sub$message[i])
    }
    add("")
  }

  writeLines(lines, path, useBytes = TRUE)
}

# --- author_stub -------------------------------------------------------------

#' Emit a ready-to-fill R-DSL rule() template
#' @keywords internal
author_stub <- function(x, dir = NULL, include_stalled = FALSE) {
  if (inherits(x, "herald_result")) {
    return(.author_stub_batch(x, dir, include_stalled))
  }
  if (is.character(x) && length(x) == 1L) {
    return(.author_stub_single(x))
  }
  cli::cli_abort(c(
    "Unsupported {.arg x}.",
    "i" = "Pass a herald_result for batch or a single rule_id (chr) for one stub."
  ))
}

.rule_from_catalog <- function(rule_id) {
  rules_rds <- system.file("rules", "rules.rds", package = "herald")
  if (!nzchar(rules_rds)) cli::cli_abort("rules.rds not found on the package path.")
  catalog <- readRDS(rules_rds)
  idx <- which(catalog$id == rule_id)
  if (length(idx) == 0L) {
    cli::cli_abort("Rule {.val {rule_id}} not in the compiled catalog.")
  }
  as.list(catalog[idx[1], , drop = FALSE])
}

.author_stub_single <- function(rule_id) {
  r <- .rule_from_catalog(rule_id)
  scope   <- r$scope[[1]]
  domains <- scope$domains %||% character(0)
  classes <- scope$classes %||% character(0)
  tree    <- r$check_tree[[1]]
  narr    <- tree$narrative %||% ""
  cond    <- tree$condition %||% tree$condition_failure %||% tree$condition_success %||% ""

  r_vec <- function(v) {
    if (length(v) == 1L) dQuote(as.character(v), q = FALSE)
    else paste0("c(", paste(dQuote(as.character(v), q = FALSE), collapse = ", "), ")")
  }

  lines <- c(
    "# --------------------------------------------------------------------",
    sprintf("# %s    (%s / %s)", r$id, r$authority, r$standard),
    sprintf("# severity: %s", r$severity),
    sprintf("# source:   %s  %s", r$source_document %||% "", r$source_url %||% ""),
    "# --------------------------------------------------------------------",
    "#",
    "# Rule text (narrative):",
    paste0("#   ", strsplit(narr, "\n", fixed = TRUE)[[1]]),
    if (nzchar(cond))
      c("#", "# Condition:", paste0("#   ", strsplit(cond, "\n", fixed = TRUE)[[1]]))
    else NULL,
    "",
    "rule(",
    sprintf("  id         = \"%s\",", r$id),
    sprintf("  authority  = \"%s\",", r$authority),
    sprintf("  standard   = \"%s\",", r$standard),
    sprintf("  severity   = \"%s\",", r$severity),
    if (length(domains) > 0L) sprintf("  domains    = %s,", r_vec(domains))
    else "  domains    = \"ALL\",",
    if (length(classes) > 0L) sprintf("  classes    = %s,", r_vec(classes)) else NULL,
    "",
    "  # TODO: translate the rule text above into an operator tree.",
    "  # See R/ops-*.R for available operators, or tools/rule-dsl.R for helpers.",
    "  # Example:",
    "  #   check = all_(",
    "  #     non_empty(USUBJID),",
    "  #     equal_to(IECAT, \"INCLUSION\")",
    "  #   ),",
    "  check      = NULL,   # <-- fill this in",
    "",
    sprintf("  message    = %s,", dQuote(trimws(r$message %||% ""), q = FALSE)),
    sprintf("  source_url = \"%s\",", r$source_url %||% "herald-own"),
    sprintf("  source_document = %s,", dQuote(trimws(r$source_document %||% ""), q = FALSE)),
    sprintf("  license    = \"%s\"", r$license %||% "MIT"),
    ")",
    ""
  )
  paste(lines, collapse = "\n")
}

.author_stub_batch <- function(result, dir, include_stalled) {
  if (is.null(dir)) cli::cli_abort("Batch mode requires {.arg dir}.")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)

  wq <- advisory_report(result)
  if (!include_stalled) wq <- wq[wq$kind == "narrative", , drop = FALSE]
  if (nrow(wq) == 0L) {
    cli::cli_inform("No advisories to scaffold.")
    return(invisible(character(0)))
  }

  paths <- character()
  for (i in seq_len(nrow(wq))) {
    rid     <- wq$id[i]
    safe    <- gsub("[^A-Za-z0-9_-]", "_", rid)
    sub_dir <- file.path(dir, tolower(wq$standard[i]))
    dir.create(sub_dir, showWarnings = FALSE, recursive = TRUE)
    p <- file.path(sub_dir, sprintf("%s.R", safe))
    writeLines(.author_stub_single(rid), p, useBytes = TRUE)
    paths <- c(paths, p)
  }
  cli::cli_alert_success("Scaffolded {length(paths)} stub{?s} under {.path {dir}}")
  invisible(paths)
}

# Exported invisibly to the caller's env for convenience when sourced
invisible(
  list(
    advisory_report       = advisory_report,
    write_advisory_report = write_advisory_report,
    author_stub           = author_stub
  )
)
