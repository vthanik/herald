# Validation and Reporting

[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
is the main entry point. It returns a `herald_result`: a stable object
containing findings, the rule catalog snapshot, dataset metadata,
skipped references, timing, and the detected submission profile.

## Inputs

Validation can start from in-memory data frames:

``` r
dm <- readRDS(extdata("dm.rds"))
spec <- readRDS(extdata("sdtm-spec.rds"))

dm <- apply_spec(dm, spec)

r0 <- validate(
  files = dm,
  rules = character(0),
  quiet = TRUE
)

r0
#> ── herald validation -- Spec Checks Only ──────────────────────────────
#> Rules: 0/0 applied
#> Datasets checked: 1
#> Findings: 0
#> Duration: 0.1632524 secs
```

Or from a directory of files:

``` r
submission_dir <- file.path(tempdir(), "herald-validation")
dir.create(submission_dir, showWarnings = FALSE)

write_xpt(dm, file.path(submission_dir, "dm.xpt"))

r1 <- validate(
  path  = submission_dir,
  rules = character(0),
  quiet = TRUE
)

r1$datasets_checked
#> [1] "DM"
```

## Rule selection

Use
[`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md)
to find rule IDs, then pass those IDs to
[`validate()`](https://vthanik.github.io/herald/reference/validate.md).
`authorities` and `standards` give broader filters.

``` r
catalog <- rule_catalog()

table(catalog$standard, catalog$authority)
#>              
#>               CDISC FDA HERALD
#>   ADaM-IG       790   0      0
#>   Define-XML    225   0      6
#>   herald-spec     0   0    103
#>   SDTM-IG       659  81      0
#>   SEND-IG         1   0      0
head(catalog[catalog$has_predicate, c("rule_id", "standard", "severity", "message")])
#> # A tibble: 6 × 4
#>   rule_id standard severity message                                    
#>   <chr>   <chr>    <chr>    <chr>                                      
#> 1 1       ADaM-IG  Medium   ADSL dataset does not exist                
#> 2 10      ADaM-IG  Medium   A variable with a suffix of FL is equal to…
#> 3 102     ADaM-IG  Medium   For every unique xx value of APERIOD, ther…
#> 4 103     ADaM-IG  Medium   For every unique xx value of APERIOD, ther…
#> 5 104     ADaM-IG  Medium   For every unique xx value of APERIOD, ther…
#> 6 105     ADaM-IG  Medium   There is more than one value of APERIODC f…

rule_ids <- head(catalog$rule_id[catalog$has_predicate], 5)

r2 <- validate(
  files = dm,
  rules = rule_ids,
  quiet = TRUE
)

r2$rules_total
#> [1] 5
r2$rules_applied
#> [1] 1
```

For exploratory runs,
[`supported_standards()`](https://vthanik.github.io/herald/reference/supported_standards.md)
gives a corpus-level summary.

``` r
supported_standards()
#> # A tibble: 7 × 6
#>   standard    authority n_rules n_predicate n_narrative pct_predicate
#>   <chr>       <chr>       <int>       <int>       <int>         <dbl>
#> 1 ADaM-IG     CDISC         790         790           0         1    
#> 2 Define-XML  CDISC         225         225           0         1    
#> 3 Define-XML  HERALD          6           5           1         0.833
#> 4 herald-spec HERALD        103         100           3         0.971
#> 5 SDTM-IG     CDISC         659         659           0         1    
#> 6 SDTM-IG     FDA            81          81           0         1    
#> 7 SEND-IG     CDISC           1           1           0         1
```

## Findings

Findings are stored in a tibble. The most useful columns for triage are
`rule_id`, `severity`, `status`, `dataset`, `variable`, `row`, and
`message`.

``` r
names(r2$findings)
#>  [1] "rule_id"           "authority"         "standard"         
#>  [4] "severity"          "severity_override" "status"           
#>  [7] "dataset"           "variable"          "row"              
#> [10] "value"             "expected"          "message"          
#> [13] "source_url"        "p21_id_equivalent" "license"

if (nrow(r2$findings)) {
  r2$findings[, c("rule_id", "severity", "status", "dataset", "variable", "row", "message")]
} else {
  "No findings emitted by the selected rules."
}
#> # A tibble: 1 × 7
#>   rule_id severity status dataset      variable   row message          
#>   <chr>   <chr>    <chr>  <chr>        <chr>    <int> <chr>            
#> 1 1       Medium   fired  <submission> NA          NA ADSL dataset doe…
```

Filter with base R or your preferred data-frame toolkit:

``` r
fired <- r2$findings[r2$findings$status == "fired", , drop = FALSE]
high  <- r2$findings[r2$findings$severity %in% c("Reject", "High", "Error"), , drop = FALSE]

nrow(fired)
#> [1] 1
nrow(high)
#> [1] 0
```

## Severity overrides

Sponsors often need study-specific severity policies. `severity_map` can
override by exact rule ID, by regular expression, or by severity
category.

``` r
r3 <- validate(
  files = dm,
  rules = rule_ids,
  severity_map = c("Medium" = "High"),
  quiet = TRUE
)

if (nrow(r3$findings)) {
  unique(r3$findings[, c("rule_id", "severity", "severity_override")])
} else {
  "No emitted findings to override in this small run."
}
#> # A tibble: 1 × 3
#>   rule_id severity severity_override
#>   <chr>   <chr>    <chr>            
#> 1 1       High     Medium
```

## Reports

Use [`report()`](https://vthanik.github.io/herald/reference/report.md)
when you want extension-based dispatch. Use the specific writers when
you want explicit output.

``` r
report_dir <- file.path(tempdir(), "herald-reports")
dir.create(report_dir, showWarnings = FALSE)

html <- file.path(report_dir, "report.html")
xlsx <- file.path(report_dir, "report.xlsx")
json <- file.path(report_dir, "report.json")

write_report_html(r2, html)
write_report_xlsx(r2, xlsx)
write_report_json(r2, json)

file.info(c(html, xlsx, json))[, c("size", "mtime")]
#>                                             size               mtime
#> /tmp/RtmpeLvPMv/herald-reports/report.html 19484 2026-04-27 09:23:32
#> /tmp/RtmpeLvPMv/herald-reports/report.xlsx  9560 2026-04-27 09:23:32
#> /tmp/RtmpeLvPMv/herald-reports/report.json  2944 2026-04-27 09:23:32
```

## Skipped references

Some rules require datasets or dictionaries that are absent. Those are
reported as skipped references rather than hidden as silent passes.

``` r
str(r2$skipped_refs, max.level = 2)
#> List of 2
#>  $ datasets    : list()
#>  $ dictionaries: list()
```

The result object keeps enough context for both automated pipelines and
human review. A CI job can fail on `nrow(result$findings) > 0`, while a
clinical programmer can open the HTML or XLSX report for triage.
