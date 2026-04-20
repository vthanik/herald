# tools/parse-conformance-xlsx.R
# One-time harvest of CDISC-published Conformance Rules XLSX files into YAML
# rules under tools/handauthored/cdisc/{sdtm,adam}/.
#
# Inputs (CC-BY-4.0, redistributable with attribution):
#   tools/handauthored/conformance/SDTM_and_SDTMIG_Conformance_Rules_v2.0.xlsx
#   tools/handauthored/conformance/adam-conformance-rules-v5.0.xlsx
#
# Outputs: one YAML per unique rule-id under
#   tools/handauthored/cdisc/sdtm-conformance/
#   tools/handauthored/cdisc/adam-conformance/
#
# check_tree policy:
#   The XLSX contains natural-language rule text but NOT machine-executable
#   predicates. Emit each rule with check_tree: {narrative: "<rule text>"}.
#   The runtime engine will treat `narrative` as an advisory / documentation
#   finding (not a fail), pending predicate authoring by the herald team.
#
# Run:  Rscript tools/parse-conformance-xlsx.R

library(openxlsx2)
library(yaml)

project_root <- getwd()
conf_dir <- file.path(project_root, "tools", "handauthored", "conformance")
sdtm_xlsx <- file.path(conf_dir, "SDTM_and_SDTMIG_Conformance_Rules_v2.0.xlsx")
adam_xlsx <- file.path(conf_dir, "adam-conformance-rules-v5.0.xlsx")

stopifnot(file.exists(sdtm_xlsx), file.exists(adam_xlsx))

sdtm_out <- file.path(project_root, "tools", "handauthored",
                      "cdisc", "sdtm-conformance")
adam_out <- file.path(project_root, "tools", "handauthored",
                      "cdisc", "adam-conformance")
dir.create(sdtm_out, showWarnings = FALSE, recursive = TRUE)
dir.create(adam_out, showWarnings = FALSE, recursive = TRUE)

# ---- helpers ---------------------------------------------------------------

`%||%` <- function(a, b) if (is.null(a) || all(is.na(a))) b else a

slug <- function(x) gsub("[^A-Za-z0-9_-]", "_", x)

split_csv_like <- function(x) {
  if (is.null(x) || is.na(x) || !nzchar(x)) return(character(0))
  trimws(unlist(strsplit(x, "[;,]")))
}

normalize_severity <- function(x) {
  # Heuristic: XLSX doesn't carry severity. Rule text with "must" => High,
  # "should" => Medium, "may" => Low. Default Medium.
  if (is.null(x) || is.na(x)) return("Medium")
  lx <- tolower(x)
  if (grepl("\\bmust\\b|\\bshall\\b|\\brequired\\b|\\bmandatory\\b", lx)) return("High")
  if (grepl("\\bshould\\b|\\brecommended\\b", lx)) return("Medium")
  if (grepl("\\bmay\\b|\\bcan\\b|\\boptional\\b", lx)) return("Low")
  "Medium"
}

emit_yaml <- function(rec, path) {
  # yaml::as.yaml handles nested lists; we write line.sep = "\n" explicitly.
  writeLines(yaml::as.yaml(rec, line.sep = "\n"), path)
}

# ---- SDTM: parse + emit ----------------------------------------------------

parse_sdtm <- function(path, out_dir) {
  wb <- wb_load(path)
  sheet <- "SDTMIG Conformance Rules v2.0"
  # Row 1 = headers; rows 2..N = data
  hdr <- wb_to_df(wb, sheet = sheet, start_row = 1, rows = 1, col_names = FALSE)
  colnames_vec <- as.character(unlist(hdr[1, ]))
  df <- wb_to_df(wb, sheet = sheet, start_row = 2, col_names = FALSE)
  names(df) <- colnames_vec[seq_along(df)]

  # Keep only rule-bearing rows
  df <- df[!is.na(df$`Rule ID`) & nzchar(df$`Rule ID`), , drop = FALSE]

  cat("SDTM rules (rows): ", nrow(df), "\n", sep = "")

  # Collapse rows with same Rule ID across IG versions into one YAML per rule
  by_id <- split(df, df$`Rule ID`)
  emitted <- 0L
  for (rule_id in names(by_id)) {
    sub <- by_id[[rule_id]]
    # Collect unique IG versions this rule applies to
    ig_versions <- unique(as.character(sub$`SDTMIG Version`))
    ig_versions <- ig_versions[!is.na(ig_versions) & nzchar(ig_versions)]

    first <- sub[1, , drop = FALSE]
    rule_text <- as.character(first$Rule %||% "")
    condition <- as.character(first$Condition %||% "")
    class_v   <- split_csv_like(as.character(first$Class %||% ""))
    domain_v  <- split_csv_like(as.character(first$Domain %||% ""))
    variable  <- as.character(first$Variable %||% "")
    document  <- as.character(first$Document %||% "")
    section   <- as.character(first$Section %||% "")
    cite_guidance <- as.character(first$`Cited Guidance` %||% "")
    rule_version  <- as.character(first$`Rule Version` %||% "1")

    rec <- list(
      id                = rule_id,
      authority         = "CDISC",
      standard          = "SDTM-IG",
      standard_versions = ig_versions,
      severity          = normalize_severity(rule_text),
      scope = list(
        classes         = class_v,
        domains         = domain_v,
        exclude_domains = list()
      ),
      variable          = variable,
      check             = list(
        narrative       = rule_text,
        condition       = condition
      ),
      outcome = list(
        message         = rule_text,
        severity        = normalize_severity(rule_text)
      ),
      provenance = list(
        source_document   = "CDISC SDTM and SDTMIG Conformance Rules v2.0",
        source_document_section = paste(document, section, sep = " "),
        source_url        = "https://www.cdisc.org/standards/foundational/sdtmig/sdtm-and-sdtmig-conformance-rules-v2-0",
        cited_guidance    = cite_guidance,
        source_version    = rule_version,
        license           = "CC-BY-4.0",
        executability     = "narrative"
      )
    )

    fname <- file.path(out_dir, paste0("SDTMIG-", slug(rule_id), ".yaml"))
    emit_yaml(rec, fname)
    emitted <- emitted + 1L
  }
  cat("SDTM YAMLs written: ", emitted, " under ", out_dir, "\n", sep = "")
  invisible(emitted)
}

# ---- ADaM: parse + emit ----------------------------------------------------

parse_adam <- function(path, out_dir) {
  wb <- wb_load(path)
  sheet <- "Rules Catalogue"
  # Row 1 = SECTION headers (merged); row 2 = real column headers; data from row 3.
  # openxlsx2 start_row behavior is quirky with merged headers, so read all from
  # row 1 and slice manually.
  all <- wb_to_df(wb, sheet = sheet, start_row = 1,
                  col_names = FALSE, skip_empty_cols = FALSE)
  colnames_vec <- trimws(as.character(unlist(all[2, ])))
  df <- all[-(1:2), , drop = FALSE]
  names(df) <- colnames_vec[seq_along(df)]

  df <- df[!is.na(df$`Rule ID`) & nzchar(df$`Rule ID`), , drop = FALSE]
  cat("ADaM rules (rows): ", nrow(df), "\n", sep = "")

  by_id <- split(df, df$`Rule ID`)
  emitted <- 0L
  for (rule_id in names(by_id)) {
    sub <- by_id[[rule_id]]
    rule_sets <- unique(as.character(sub$`Rule Set (Generally IG Version, OCCDS v1.0, ADNCA v1.0)`))
    rule_sets <- rule_sets[!is.na(rule_sets) & nzchar(rule_sets)]

    first <- sub[1, , drop = FALSE]
    rule_text_success <- as.character(first$`Natural Language Rule (Success Criteria)` %||%
                                       first$`Rule (Success Criteria)` %||% "")
    rule_text_failure <- as.character(first$`Natural Language Rule (Failure Criteria)` %||%
                                       first$`Rule (Failure Criteria)` %||% "")
    condition_success <- as.character(first$`Condition (Success)` %||% "")
    condition_failure <- as.character(first$`Condition (Failure)` %||% "")
    class_v <- split_csv_like(as.character(first$Class %||% ""))
    subclass <- as.character(first$Subclass %||% "")
    domain_v <- split_csv_like(as.character(first$`SEND/SDTM Domain` %||% ""))
    variable <- as.character(first$`Variable or Item` %||% "")
    define_elem <- as.character(first$`Define-XML Element` %||% "")
    doc <- as.character(first$`Implementation Guide (Cited document)` %||% "")
    section <- as.character(first$`Cited Section` %||% "")
    cite <- as.character(first$`Cited Guidance` %||% "")
    rule_version <- as.character(first$`Rule ID Version (represents any change to the rule) ` %||% "1")

    # Use failure text as the finding message (what goes wrong)
    msg <- if (nzchar(rule_text_failure)) rule_text_failure else rule_text_success
    sev <- normalize_severity(rule_text_failure %||% rule_text_success)

    rec <- list(
      id                = rule_id,
      authority         = "CDISC",
      standard          = "ADaM-IG",
      standard_versions = rule_sets,
      severity          = sev,
      scope = list(
        classes         = c(class_v, if (nzchar(subclass)) subclass else NULL),
        domains         = domain_v,
        exclude_domains = list()
      ),
      variable          = variable,
      define_element    = define_elem,
      check = list(
        narrative          = rule_text_success,
        condition_success  = condition_success,
        condition_failure  = condition_failure
      ),
      outcome = list(
        message  = msg,
        severity = sev
      ),
      provenance = list(
        source_document      = "CDISC ADaM Conformance Rules v5.0",
        source_document_section = paste(doc, section, sep = " "),
        source_url           = "https://www.cdisc.org/standards/foundational/adam/adam-conformance-rules-v5-0",
        cited_guidance       = cite,
        source_version       = rule_version,
        license              = "CC-BY-4.0",
        executability        = "narrative"
      )
    )

    fname <- file.path(out_dir, paste0("ADaM-", slug(rule_id), ".yaml"))
    emit_yaml(rec, fname)
    emitted <- emitted + 1L
  }
  cat("ADaM YAMLs written: ", emitted, " under ", out_dir, "\n", sep = "")
  invisible(emitted)
}

# ---- NOTICE for CC-BY-4.0 attribution --------------------------------------

notice_path <- file.path(dirname(sdtm_out), "NOTICE.md")
writeLines(c(
  "# CDISC Conformance Rules — attribution",
  "",
  "This directory contains rule metadata harvested from CDISC-published",
  "Conformance Rules XLSX documents, redistributed under Creative Commons",
  "Attribution 4.0 International (CC-BY-4.0).",
  "",
  "- SDTM and SDTMIG Conformance Rules v2.0",
  "  https://www.cdisc.org/standards/foundational/sdtmig/sdtm-and-sdtmig-conformance-rules-v2-0",
  "- ADaM Conformance Rules v5.0",
  "  https://www.cdisc.org/standards/foundational/adam/adam-conformance-rules-v5-0",
  "",
  "License: CC-BY-4.0  https://creativecommons.org/licenses/by/4.0/",
  "Attribution: Clinical Data Interchange Standards Consortium (CDISC)."
), notice_path)

# ---- Run -------------------------------------------------------------------

cat("===== CDISC Conformance Rules harvest =====\n")
parse_sdtm(sdtm_xlsx, sdtm_out)
parse_adam(adam_xlsx, adam_out)
cat("===== done =====\n")
