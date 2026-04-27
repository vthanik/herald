# Summarise herald's standards coverage

Returns a cross-tab of rule counts by standard and authority, with
predicate vs narrative split and corpus metadata.

## Usage

``` r
supported_standards()
```

## Value

A tibble with columns:

- standard:

  CDISC standard family.

- authority:

  Rule authority.

- n_rules:

  Total rules.

- n_predicate:

  Rules with an executable predicate.

- n_narrative:

  Rules pending predicate authoring.

- pct_predicate:

  Fraction of rules with a predicate (0–1).

The tibble carries two attributes:

- compiled_at:

  ISO-8601 timestamp when the corpus was last compiled.

- herald_version:

  Package version at compile time.

## See also

[`validate()`](https://vthanik.github.io/herald/reference/validate.md),
[`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md)

Other validate:
[`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md),
[`validate()`](https://vthanik.github.io/herald/reference/validate.md)

## Examples

``` r
stds <- supported_standards()
stds
#> # A tibble: 7 × 6
#>   standard    authority n_rules n_predicate n_narrative pct_predicate
#>   <chr>       <chr>       <int>       <int>       <int>         <dbl>
#> 1 ADaM-IG     CDISC         790         790           0         1    
#> 2 Define-XML  CDISC         225         225           0         1    
#> 3 Define-XML  HERALD          6           5           1         0.833
#> 4 SDTM-IG     CDISC         659         659           0         1    
#> 5 SDTM-IG     FDA            81          81           0         1    
#> 6 SEND-IG     CDISC           1           1           0         1    
#> 7 herald-spec HERALD        103         100           3         0.971

# Predicate coverage per standard (0 = no rules, 1 = fully implemented)
stds[, c("standard", "pct_predicate")]
#> # A tibble: 7 × 2
#>   standard    pct_predicate
#>   <chr>               <dbl>
#> 1 ADaM-IG             1    
#> 2 Define-XML          1    
#> 3 Define-XML          0.833
#> 4 SDTM-IG             1    
#> 5 SDTM-IG             1    
#> 6 SEND-IG             1    
#> 7 herald-spec         0.971

# Which standards have full predicate coverage?
stds[!is.na(stds$pct_predicate) & stds$pct_predicate == 1, ]
#> # A tibble: 5 × 6
#>   standard   authority n_rules n_predicate n_narrative pct_predicate
#>   <chr>      <chr>       <int>       <int>       <int>         <dbl>
#> 1 ADaM-IG    CDISC         790         790           0             1
#> 2 Define-XML CDISC         225         225           0             1
#> 3 SDTM-IG    CDISC         659         659           0             1
#> 4 SDTM-IG    FDA            81          81           0             1
#> 5 SEND-IG    CDISC           1           1           0             1

# Corpus compilation metadata
attr(stds, "compiled_at")
#> [1] "2026-04-25T01:08:45Z"
attr(stds, "herald_version")
#> [1] "0.1.0"
```
