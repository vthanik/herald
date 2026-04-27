# Herald Cookbook

A collection of focused recipes for `herald`. Each recipe is short,
runnable on the bundled pilot data, and answers a single question. Use
the table of contents to jump straight to the topic you need.

All recipes use the lazy datasets shipped with the package:

``` r
data(dm)         # SDTM Demographics  (50 rows x 25 cols)
data(adsl)       # ADaM Subject-Level (50 rows x 49 cols)
data(adae)       # ADaM Adverse Events (254 rows x 55 cols)
data(advs)       # ADaM Vital Signs   (6,138 rows x 35 cols)
data(sdtm_spec)  # herald_spec covering 31 SDTM datasets
data(adam_spec)  # herald_spec covering 12 ADaM datasets
```

## Filter the rule catalog

Use
[`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md)
to see what is available, then filter by any column. Pass the chosen
`rule_id` values to `validate(rules = ...)`.

``` r
catalog <- rule_catalog()
nrow(catalog)
#> [1] 1865

# Rules from a single standard
sdtm_rules <- catalog[catalog$standard == "SDTM-IG", ]
nrow(sdtm_rules)
#> [1] 740

# Only High-severity Define-XML rules
hi_define <- catalog[
  catalog$standard == "Define-XML" & catalog$severity == "High",
]
head(hi_define[, c("rule_id", "severity")], 5)
#> # A tibble: 5 × 2
#>   rule_id                         severity
#>   <chr>                           <chr>   
#> 1 define_arm_not_in_non_adam      High    
#> 2 define_attribute_length_le_1000 High    
#> 3 define_suppqual_qnam_has_vlm    High    
#> 4 define_version_is_2_1           High    
#> 5 define_version_valid            High
```

## Run a domain-scoped validation

[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
accepts a single data frame or a named list of data frames. Pass only
the domains you want to check.

``` r
r_sdtm <- validate(
  files = list(DM = apply_spec(dm, sdtm_spec)),
  standards = "SDTM-IG",
  quiet = TRUE
)
r_sdtm$datasets_checked
#> [1] "DM"
r_sdtm$rules_total
#> [1] 740
```

## Override severities for one run

`severity_map` rewrites severity labels at run time without touching the
catalog. The named vector maps “from” -\> “to”.

``` r
r <- validate(
  files = list(DM = dm),
  standards = "SDTM-IG",
  severity_map = c("Medium" = "High", "Low" = "Medium"),
  quiet = TRUE
)

# Severity rewrite is reflected in the result findings table
table(r$findings$severity)
#> 
#> High 
#>  242
```

## Limit a run to a hand-picked rule list

``` r
catalog <- rule_catalog()
chosen <- head(catalog$rule_id[catalog$has_predicate], 5)
chosen
#> [1] "1"   "10"  "102" "103" "104"

r <- validate(files = dm, rules = chosen, quiet = TRUE)
r$rules_total
#> [1] 5
```

## Register a custom dictionary provider

Sponsor-private codelists fit the same protocol as MedDRA / WHODrug.
Build with
[`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md)
(a tibble) or
[`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md)
(any membership predicate) and register session-wide.

``` r
codes <- data.frame(
  code = c("S01", "S02", "S03"),
  stringsAsFactors = FALSE
)
sponsor <- custom_provider(codes, name = "site-codes", fields = "code")

register_dictionary("site-codes", sponsor)
list_dictionaries()
#> # A tibble: 1 × 5
#>   name       version source  license         size_rows
#>   <chr>      <chr>   <chr>   <chr>               <int>
#> 1 site-codes unknown sponsor sponsor-private         3

unregister_dictionary("site-codes")
```

## Round-trip a Define-XML document

[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md)
parses a Define-XML 2.1 file into a `herald_define` object.
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md)
extracts the dataset and variable metadata that
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
needs.

``` r
define_path <- system.file(
  "extdata", "pilot-define.xml",
  package = "herald"
)
if (nzchar(define_path) && file.exists(define_path)) {
  d <- read_define_xml(define_path)
  spec <- as_herald_spec(d)
  is_herald_spec(spec)
  length(spec$ds_spec$dataset)
}
```

## Validate a directory of XPT files

In production the dataset source is usually a directory of XPT files.
`validate(path = ...)` reads every transport file in the directory,
applies any matching spec, and runs the corpus.

``` r
out <- file.path(tempdir(), "herald-cookbook")
dir.create(out, showWarnings = FALSE, recursive = TRUE)

write_xpt(apply_spec(dm, sdtm_spec), file.path(out, "dm.xpt"))

r <- validate(path = out, standards = "SDTM-IG", quiet = TRUE)
r$datasets_checked
#> [1] "DM"
```

## Batch-validate many studies

Drive a small jobs table from a study inventory and loop. The validation
result is the source of truth for every report format.

``` r
jobs <- data.frame(
  study   = c("STUDY-A", "STUDY-B"),
  path    = c("studies/A/sdtm", "studies/B/sdtm"),
  out_dir = c("qc/A", "qc/B"),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(jobs))) {
  job <- jobs[i, ]
  res <- validate(path = job$path, standards = "SDTM-IG", quiet = TRUE)
  dir.create(job$out_dir, recursive = TRUE, showWarnings = FALSE)
  report(res, file.path(job$out_dir, "report.html"))
  report(res, file.path(job$out_dir, "report.xlsx"))
  report(res, file.path(job$out_dir, "report.json"))
}
```

## Reproducible runs with renv

Pin every dependency in `renv.lock` so the validation result is
reproducible. The full setup looks like:

``` r
# Once per project
renv::init()
renv::install("vthanik/herald")
renv::snapshot()

# In the validation program
library(herald)
result <- validate(path = "data/sdtm", quiet = TRUE)
report(result, "qc/report.html")
```

Lock the dictionary versions explicitly so a CT release update never
silently changes findings:

``` r
dictionaries <- list(
  "ct-sdtm" = ct_provider("sdtm", version = "2024-09-27"),
  "meddra"  = meddra_provider("dictionaries/meddra", version = "27.0")
)
result <- validate(
  path = "data/sdtm",
  dictionaries = dictionaries,
  quiet = TRUE
)
```

## CI integration with targets

Wrap each validation as a `targets` step so re-runs are incremental and
the result object is cached.

``` r
# _targets.R
library(targets)
tar_option_set(packages = "herald")

list(
  tar_target(sdtm_dir, "data/sdtm", format = "file"),
  tar_target(spec_xml, "metadata/define.xml", format = "file"),
  tar_target(spec, as_herald_spec(read_define_xml(spec_xml))),
  tar_target(result, validate(path = sdtm_dir, spec = spec, quiet = TRUE)),
  tar_target(html, {
    out <- "qc/report.html"
    report(result, out)
    out
  }, format = "file")
)
```

A typical GitHub Actions step then runs:

``` yaml
- name: Validate
  run: Rscript -e 'targets::tar_make()'
- name: Upload report
  uses: actions/upload-artifact@v4
  with:
    name: validation-report
    path: qc/
```

## Gate CI on blocking findings

Save reports first, then exit non-zero if any high-impact rule fired.

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

r <- validate(
  files = list(DM = apply_spec(dm, sdtm_spec)),
  standards = "SDTM-IG",
  quiet = TRUE
)
is_blocking(r)
#> [1] FALSE
```

## Inspect skipped rules

Rules that need a missing dataset or dictionary are recorded in
`result$skipped_refs` along with a hint string.

``` r
r <- validate(
  files = list(DM = dm),
  standards = "SDTM-IG",
  quiet = TRUE
)
str(r$skipped_refs, max.level = 2)
#> List of 2
#>  $ datasets    :List of 6
#>   ..$ TA    :List of 3
#>   ..$ SS    :List of 3
#>   ..$ DD    :List of 3
#>   ..$ AE    :List of 3
#>   ..$ DS    :List of 3
#>   ..$ SUPPDM:List of 3
#>  $ dictionaries:List of 1
#>   ..$ define.xml:List of 3
```

## Where to go next

- `extending-herald` – write your own op or dictionary provider.
- `migrating-from-p21` – mapping from Pinnacle 21 workflows.
- `faq` – short answers to first-time-user issues.
