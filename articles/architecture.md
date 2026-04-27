# Architecture

`herald` is organized as a set of small layers. Each layer can be used
directly, but the usual production path flows from data ingest to
validation reports.

    6  reports              report(), write_report_html(), write_report_xlsx()
    5  validation engine    validate(), rule_catalog(), supported_standards()
    4  rule operations      op_* functions registered in R/ops-*.R
    3  dictionaries         ct_provider(), srs_provider(), custom_provider()
    2  specifications       as_herald_spec(), herald_spec(), read_define_xml()
    1  metadata stamping    apply_spec()
    0  dataset I/O          read_xpt(), read_json(), read_parquet()

## Dataset contract

Datasets are normal R data frames. Metadata is carried in attributes:

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
attr(dm$USUBJID, "xpt_type")
#> NULL
```

This keeps the package compatible with base R, `dplyr`, `data.table`,
and other data-frame tooling while still preserving submission metadata
for XPT and report writers.

## Specification objects

[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md)
is the compact constructor for dataset and variable metadata.
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md)
is the richer constructor used by Define-XML.

``` r
simple_spec <- as_herald_spec(
  ds_spec = data.frame(
    dataset = "DM",
    label = "Demographics",
    class = "SPECIAL PURPOSE",
    stringsAsFactors = FALSE
  ),
  var_spec = data.frame(
    dataset = "DM",
    variable = c("STUDYID", "USUBJID"),
    label = c("Study Identifier", "Unique Subject Identifier"),
    type = c("text", "text"),
    stringsAsFactors = FALSE
  )
)

simple_spec
#> <herald_spec>
#>   1 dataset, 2 variables
```

## Rule catalog

Compiled rules live under `inst/rules`.
[`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md)
flattens the compiled corpus for browsing, filtering, and coverage
checks.

``` r
catalog <- rule_catalog()

nrow(catalog)
#> [1] 1865
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
```

[`supported_standards()`](https://vthanik.github.io/herald/reference/supported_standards.md)
summarizes predicate coverage by standard and authority.

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

## Operation registry

Rule predicates are implemented by operation functions in `R/ops-*.R`.
Operations return logical vectors with this convention:

| Return value | Meaning                                                     |
|--------------|-------------------------------------------------------------|
| `TRUE`       | Rule fires for that row or dataset                          |
| `FALSE`      | Rule passes                                                 |
| `NA`         | Advisory or skipped because required context is unavailable |

Every operation is registered with metadata so the rule engine can
dispatch by name and report unresolved references.

## Error contract

Package errors inherit from `herald_error`. Specific subclasses
distinguish input, file, spec, rule, validation, Define-XML, report, and
runtime failures. This lets pipelines catch broadly while tests pin
precise classes.

``` r
tryCatch(
  validate(quiet = TRUE),
  herald_error = function(e) class(e)
)
#> [1] "herald_error_input" "herald_error"       "rlang_error"       
#> [4] "error"              "condition"
```

## Extension points

The safest extension points are:

| Need                              | Extension point                                                                                                                                                                  |
|-----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| New controlled terminology source | [`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md) or [`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md) |
| Sponsor-specific dictionary       | [`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md) or `validate(dictionaries = ...)`                                                   |
| Severity policy                   | `validate(severity_map = ...)`                                                                                                                                                   |
| Output automation                 | [`report()`](https://vthanik.github.io/herald/reference/report.md) or specific report writers                                                                                    |
| Define-XML authoring              | [`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md) plus [`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md)         |

Internal rule operation authoring is more powerful, but it changes
validation semantics and should be paired with focused fixtures.

## Development checks

The package-level quality gate is:

``` r
devtools::document()
devtools::test()
devtools::check(args = "--no-manual")
```

For rule development, also track fixture coverage with:

``` r
source("tools/fixture-coverage.R")
```

See
[`vignette("rule-coverage")`](https://vthanik.github.io/herald/articles/rule-coverage.md)
for the current fixture coverage report.
