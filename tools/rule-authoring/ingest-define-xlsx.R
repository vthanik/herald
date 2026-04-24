#!/usr/bin/env Rscript
# tools/rule-authoring/ingest-define-xlsx.R
# ---------------------------------------------------------------------------
# Ingest CDISC Define-XML v2.1 Conformance Rules from the official xlsx into
# tools/handauthored/cdisc/define-xml-v2.1/DEFINE-NNN.yaml files.
#
# Source:
#   ~/Downloads/Define-XML_v2.1_Conformance_Rules.xlsx  (225 rules)
#
# Output schema (herald lowercase YAML):
#   id: DEFINE-001
#   authority: CDISC
#   standard: Define-XML
#   standard_versions: ["2.0", "2.1"]
#   severity: Medium
#   scope: {}
#   check:
#     narrative: <Plain Text Rule>
#   outcome:
#     message: <Rule Message>
#     severity: Medium
#   provenance:
#     source_document: CDISC Define-XML v2.1 Conformance Rules
#     executability: narrative
#     define_rule_id: <integer id from xlsx>
#     applicable_versions: <Applicable Versions>
#     source_type: <Source Type>
#     xpaths: <XPaths>
#     element: <Element>
#     attribute: <Attribute>
#     license: CC-BY-4.0
#
# Idempotent: existing DEFINE-*.yaml files are overwritten if the xlsx
# content changed. Run from the package root.

suppressPackageStartupMessages({
  library(yaml)
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("readxl is required: install.packages('readxl')")
  }
})

args   <- commandArgs(trailingOnly = TRUE)
xlsx   <- if (length(args) >= 1L) args[[1L]] else
            file.path(path.expand("~"), "Downloads",
                      "Define-XML_v2.1_Conformance_Rules.xlsx")

project_root <- getwd()
if (!dir.exists(file.path(project_root, "tools", "handauthored"))) {
  stop("Run from the package root")
}
out_dir <- file.path(project_root, "tools", "handauthored", "cdisc", "define-xml-v2.1")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(xlsx)) {
  stop("xlsx not found: ", xlsx,
       "\nPass path as first argument: Rscript ingest-define-xlsx.R /path/to/file.xlsx")
}

cat("Reading", xlsx, "\n")
df <- readxl::read_xlsx(xlsx)
cat("Rows:", nrow(df), " | Cols:", ncol(df), "\n")

# ---- column normalisation ---------------------------------------------------

.col <- function(df, ...) {
  nms <- c(...)
  for (nm in nms) {
    hits <- grep(nm, names(df), ignore.case = TRUE, value = TRUE)
    if (length(hits) > 0L) return(as.character(df[[hits[[1L]]]]))
  }
  rep(NA_character_, nrow(df))
}

rule_ids     <- suppressWarnings(as.integer(.col(df, "Rule Identifier")))
plain_texts  <- .col(df, "Plain Text Rule")
messages     <- .col(df, "Rule Message")
versions     <- .col(df, "Applicable Versions")
source_types <- .col(df, "Source Type")
xpaths       <- .col(df, "XPaths")
elements     <- .col(df, "Element")
attributes   <- .col(df, "Attribute")

.version_list <- function(v) {
  if (is.na(v) || !nzchar(v)) return(list("2.0", "2.1"))
  v <- tolower(v)
  if (grepl("2\\.0.*2\\.1|both", v)) return(list("2.0", "2.1"))
  if (grepl("2\\.1", v)) return(list("2.1"))
  if (grepl("2\\.0", v)) return(list("2.0"))
  list("2.0", "2.1")
}

.na_null <- function(x) if (is.na(x) || !nzchar(x)) NULL else trimws(x)

# ---- write YAMLs ------------------------------------------------------------

written <- 0L; skipped <- 0L; failed <- 0L

for (i in seq_len(nrow(df))) {
  rid <- rule_ids[[i]]
  if (is.na(rid)) { skipped <- skipped + 1L; next }

  yaml_id  <- sprintf("DEFINE-%03d", rid)
  out_path <- file.path(out_dir, paste0(yaml_id, ".yaml"))

  plain <- .na_null(plain_texts[[i]])
  msg   <- .na_null(messages[[i]])

  prov <- list(
    source_document     = "CDISC Define-XML v2.1 Conformance Rules",
    executability       = "narrative",
    define_rule_id      = rid,
    license             = "CC-BY-4.0"
  )
  apv <- .na_null(versions[[i]])
  if (!is.null(apv)) prov$applicable_versions <- apv
  st  <- .na_null(source_types[[i]])
  if (!is.null(st)) prov$source_type <- st
  xp  <- .na_null(xpaths[[i]])
  if (!is.null(xp)) prov$xpaths <- xp
  el  <- .na_null(elements[[i]])
  if (!is.null(el)) prov$element <- el
  att <- .na_null(attributes[[i]])
  if (!is.null(att)) prov$attribute <- att

  yml <- list(
    id                = yaml_id,
    authority         = "CDISC",
    standard          = "Define-XML",
    standard_versions = .version_list(versions[[i]]),
    severity          = "Medium",
    scope             = list(classes = list(), domains = list()),
    check             = list(narrative = if (!is.null(plain)) plain else "(see provenance)"),
    outcome           = list(
      message  = if (!is.null(msg)) msg else yaml_id,
      severity = "Medium"
    ),
    provenance = prov
  )

  tryCatch({
    yaml::write_yaml(yml, out_path)
    written <- written + 1L
  }, error = function(e) {
    cat("FAIL:", yaml_id, conditionMessage(e), "\n")
    failed <<- failed + 1L
  })
}

cat(sprintf("\n===== ingest-define-xlsx.R =====\n"))
cat(sprintf("  written : %d\n", written))
cat(sprintf("  skipped : %d\n", skipped))
cat(sprintf("  failed  : %d\n", failed))
cat(sprintf("  output  : %s\n", out_dir))
