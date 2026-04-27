# Best Practices for Validation Projects

This guide shows how to organize `herald` in a production validation
project: metadata first, deterministic inputs, explicit rule selection,
reproducible dictionaries, and reports that can be reviewed by
programmers and auditors.

## Recommended project layout

Keep submitted data, metadata, validation outputs, and project setup
separate.

``` text
study/
  data/
    sdtm/
      dm.xpt
      ae.xpt
    adam/
      adsl.xpt
      adae.xpt
  metadata/
    define.xml
    spec.rds
  dictionaries/
    meddra/
    whodrug/
  programs/
    validate-sdtm.R
    validate-adam.R
  qc/
    sdtm-report.html
    sdtm-report.xlsx
    sdtm-report.json
```

The validation program should read only from `data/`, `metadata/`, and
`dictionaries/`, then write only to `qc/`. That makes reruns
predictable.

## Metadata first

Stamp metadata before writing transport files and before validation.
This keeps labels, lengths, and expected types synchronized across XPT,
Dataset-JSON, Define-XML, and reports.

``` r
dm <- readRDS(extdata("dm.rds"))
spec <- readRDS(extdata("sdtm-spec.rds"))

dm <- apply_spec(dm, spec)

attr(dm, "label")
#> [1] "Demographics"
attr(dm$USUBJID, "label")
#> [1] "Unique Subject Identifier"
attr(dm$USUBJID, "sas.length")
#> [1] 11
```

## Validate submitted artifacts

In production, validate the files you plan to submit, not an earlier
in-memory object. A good pattern is:

1.  Stamp metadata.
2.  Write XPT or Dataset-JSON.
3.  Read the written files back.
4.  Validate the reread files.
5.  Write all report formats.

``` r
root <- file.path(tempdir(), "herald-best-practices")
data_dir <- file.path(root, "data", "sdtm")
qc_dir <- file.path(root, "qc")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(qc_dir, recursive = TRUE, showWarnings = FALSE)

write_xpt(dm, file.path(data_dir, "dm.xpt"))

result <- validate(
  path  = data_dir,
  rules = character(0),
  quiet = TRUE
)

result$datasets_checked
#> [1] "DM"
```

## Make rule selection explicit

Do not let production programs hide the rule policy. Define rule filters
near the top of the program.

``` r
catalog <- rule_catalog()

rule_policy <- list(
  standards   = c("SDTM-IG", "Define-XML"),
  authorities = c("CDISC", "FDA"),
  severity_map = c("Medium" = "High")
)

head(catalog[catalog$standard %in% rule_policy$standards,
             c("rule_id", "standard", "authority", "severity")])
#> # A tibble: 6 × 4
#>   rule_id    standard   authority severity
#>   <chr>      <chr>      <chr>     <chr>   
#> 1 DEFINE-001 Define-XML CDISC     Medium  
#> 2 DEFINE-002 Define-XML CDISC     Medium  
#> 3 DEFINE-003 Define-XML CDISC     Medium  
#> 4 DEFINE-004 Define-XML CDISC     Medium  
#> 5 DEFINE-005 Define-XML CDISC     Medium  
#> 6 DEFINE-006 Define-XML CDISC     Medium
```

Use the same object in the validation call:

``` r
policy_result <- validate(
  path = data_dir,
  standards = rule_policy$standards,
  authorities = rule_policy$authorities,
  severity_map = rule_policy$severity_map,
  quiet = TRUE
)

policy_result$rules_total
#> [1] 965
```

## Keep dictionaries reproducible

Pass dictionary providers directly to
[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
when you want the run to be self-contained. Use session registration for
interactive work.

``` r
dictionaries <- list(
  "ct-sdtm" = ct_provider("sdtm")
)

dict_result <- validate(
  path = data_dir,
  rules = character(0),
  dictionaries = dictionaries,
  quiet = TRUE
)

dict_result$skipped_refs
#> $datasets
#> list()
#> 
#> $dictionaries
#> list()
```

For licensed dictionaries such as MedDRA or WHODrug, store the source
version in the project metadata and construct providers in one setup
block.

``` r
dictionaries <- list(
  "ct-sdtm" = ct_provider("sdtm", version = "bundled"),
  "meddra"  = meddra_provider("dictionaries/meddra", version = "27.0"),
  "whodrug" = whodrug_provider("dictionaries/whodrug", version = "2024-03")
)
```

## Report every run

Write all three report formats from the same `herald_result`.

``` r
html <- file.path(qc_dir, "sdtm-report.html")
xlsx <- file.path(qc_dir, "sdtm-report.xlsx")
json <- file.path(qc_dir, "sdtm-report.json")

report(result, html)
report(result, xlsx)
report(result, json)

file.exists(c(html, xlsx, json))
#> [1] TRUE TRUE TRUE
```

Use each format for a different audience:

| Format | Best use                                      |
|--------|-----------------------------------------------|
| HTML   | Programmer and study-team review              |
| XLSX   | Triage, filtering, comments, issue assignment |
| JSON   | CI gates, dashboards, audit archives          |

## Batch validation

A study usually has multiple packages: SDTM, ADaM, and sometimes
standalone Define-XML checks. Use a small metadata table and loop over
it.

``` r
jobs <- data.frame(
  package = c("sdtm", "adam"),
  path    = c("data/sdtm", "data/adam"),
  html    = c("qc/sdtm-report.html", "qc/adam-report.html"),
  xlsx    = c("qc/sdtm-report.xlsx", "qc/adam-report.xlsx"),
  json    = c("qc/sdtm-report.json", "qc/adam-report.json"),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(jobs))) {
  job <- jobs[i, ]
  res <- validate(path = job$path, quiet = TRUE)
  report(res, job$html)
  report(res, job$xlsx)
  report(res, job$json)
}
```

## CI gate

A simple CI policy can fail on high-impact fired findings while still
saving the full report set for review.

``` r
is_blocking <- function(result) {
  f <- result$findings
  if (!nrow(f)) return(FALSE)
  any(
    f$status == "fired" &
      f$severity %in% c("Reject", "Error", "High"),
    na.rm = TRUE
  )
}

is_blocking(result)
#> [1] FALSE
```

In CI, write reports first, then stop:

``` r
report(result, "qc/report.html")
report(result, "qc/report.xlsx")
report(result, "qc/report.json")

if (is_blocking(result)) {
  stop("Blocking validation findings found. See qc/report.html.")
}
```

## QC checklist

Before a validation run is considered review-ready:

| Check                                | Command                                                                                      |
|--------------------------------------|----------------------------------------------------------------------------------------------|
| Package loads from a clean R session | [`library(herald)`](https://github.com/vthanik/herald)                                       |
| Rule corpus is inspectable           | [`supported_standards()`](https://vthanik.github.io/herald/reference/supported_standards.md) |
| Datasets can be reread from disk     | `validate(path = "data/sdtm")`                                                               |
| Dictionary versions are explicit     | `ct_info("sdtm")`, provider `$info()`                                                        |
| Reports are written from one result  | `report(result, ...)`                                                                        |
| Skipped references are reviewed      | `result$skipped_refs`                                                                        |
| Blocking findings are gated          | `is_blocking(result)`                                                                        |

The key habit is to keep the validation result as the source of truth.
Reports, CI gates, dashboards, and manual issue triage should all derive
from the same `herald_result` object.
