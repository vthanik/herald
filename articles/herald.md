# Getting Started with herald

`herald` is a clinical submission validation package. It is designed for
R-native pipelines that need to read submission datasets, attach CDISC
metadata, execute conformance rules, and produce auditable reports.

The current package has four core objects:

| Object                       | What it represents                                                           |
|------------------------------|------------------------------------------------------------------------------|
| `data.frame` with attributes | A clinical dataset with labels, lengths, and XPT type metadata               |
| `herald_spec`                | Dataset and variable metadata used before validation                         |
| `herald_define`              | A Define-XML document parsed into R data frames                              |
| `herald_result`              | Validation findings, rule snapshot, dataset metadata, and skipped references |

## The workflow

Most workflows follow the same shape:

    read data -> build/read spec -> apply spec -> validate -> report

Use the pilot data bundled with the package:

``` r
dm <- readRDS(extdata("dm.rds"))
spec <- readRDS(extdata("sdtm-spec.rds"))

dim(dm)
#> [1] 50 25
names(dm)[1:6]
#> [1] "STUDYID" "DOMAIN"  "USUBJID" "SUBJID"  "RFSTDTC" "RFENDTC"
spec
#> <herald_spec>
#>   31 datasets, 747 variables
```

## Apply metadata

[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
stamps dataset-level and variable-level metadata. The result is still a
regular data frame, so existing R code keeps working.

``` r
dm <- apply_spec(dm, spec)

attr(dm, "label")
#> [1] "Demographics"
attr(dm$USUBJID, "label")
#> [1] "Unique Subject Identifier"
attr(dm$USUBJID, "sas.length")
#> [1] 11
attr(dm$USUBJID, "xpt_type")
#> NULL
```

## Validate

[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
accepts either a directory path or a named list of data frames. For a
first smoke test, use `rules = character(0)` to exercise the result
object and reporting path without running the full compiled corpus.

``` r
result <- validate(
  files = dm,
  rules = character(0),
  quiet = TRUE
)

result
#> ── herald validation -- Spec Checks Only ──────────────────────────────
#> Rules: 0/0 applied
#> Datasets checked: 1
#> Findings: 0
#> Duration: 0.161721 secs
names(result)
#>  [1] "findings"         "rules_applied"    "rules_total"     
#>  [4] "datasets_checked" "duration"         "timestamp"       
#>  [7] "profile"          "config_hash"      "dataset_meta"    
#> [10] "rule_catalog"     "op_errors"        "skipped_refs"
```

Run selected rules by passing rule identifiers. To inspect what is
available, use
[`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md).

``` r
catalog <- rule_catalog()
head(catalog[, c("rule_id", "standard", "authority", "severity", "has_predicate")])
#> # A tibble: 6 × 5
#>   rule_id standard authority severity has_predicate
#>   <chr>   <chr>    <chr>     <chr>    <lgl>        
#> 1 1       ADaM-IG  CDISC     Medium   TRUE         
#> 2 10      ADaM-IG  CDISC     Medium   TRUE         
#> 3 102     ADaM-IG  CDISC     Medium   TRUE         
#> 4 103     ADaM-IG  CDISC     Medium   TRUE         
#> 5 104     ADaM-IG  CDISC     Medium   TRUE         
#> 6 105     ADaM-IG  CDISC     Medium   TRUE

selected <- head(catalog$rule_id[catalog$has_predicate], 3)
selected
#> [1] "1"   "10"  "102"

selected_result <- validate(
  files = dm,
  rules = selected,
  quiet = TRUE
)

selected_result$rules_total
#> [1] 3
selected_result$datasets_checked
#> [1] "DM"
```

## Write reports

Reports are generated from a `herald_result`. The generic
[`report()`](https://vthanik.github.io/herald/reference/report.md)
dispatches from the file extension.

``` r
out_dir <- file.path(tempdir(), "herald-getting-started")
dir.create(out_dir, showWarnings = FALSE)

html_path <- file.path(out_dir, "validation-report.html")
json_path <- file.path(out_dir, "validation-report.json")
xlsx_path <- file.path(out_dir, "validation-report.xlsx")

report(selected_result, html_path)
report(selected_result, json_path)
report(selected_result, xlsx_path)

file.exists(c(html_path, json_path, xlsx_path))
#> [1] TRUE TRUE TRUE
```

## Convert dataset formats

[`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md)
converts among XPT, Dataset-JSON, and Parquet. Parquet requires the
optional `arrow` package.

``` r
xpt_path  <- file.path(out_dir, "dm.xpt")
json_path <- file.path(out_dir, "dm.json")

write_xpt(dm, xpt_path)
convert_dataset(xpt_path, json_path)

dm_from_json <- read_json(json_path)
identical(nrow(dm), nrow(dm_from_json))
#> [1] TRUE
```

## Where to go next

- [`vignette("validation-reporting")`](https://vthanik.github.io/herald/articles/validation-reporting.md)
  for rule filters, severity overrides, and reports.
- [`vignette("data-io")`](https://vthanik.github.io/herald/articles/data-io.md)
  for XPT, Dataset-JSON, Parquet, and conversions.
- [`vignette("define-xml")`](https://vthanik.github.io/herald/articles/define-xml.md)
  for Define-XML 2.1 read/write round-trips.
- [`vignette("dictionaries")`](https://vthanik.github.io/herald/articles/dictionaries.md)
  for controlled terminology and external dictionaries.
- [`vignette("architecture")`](https://vthanik.github.io/herald/articles/architecture.md)
  for package layers and extension points.
