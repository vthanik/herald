# List known dictionaries

Enumerates everything herald can see: session-registered dictionaries,
cache-discoverable dictionaries, and the bundled CDISC CT. Used for
reporting and debugging.

## Usage

``` r
list_dictionaries(include_global = TRUE, include_cache = TRUE)
```

## Arguments

- include_global:

  Include the session registry. Default TRUE.

- include_cache:

  Scan the user cache. Default TRUE.

## Value

A tibble with columns `name`, `version`, `source`, `license`,
`size_rows`.

## See also

Other dict:
[`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
[`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md),
[`loinc_provider()`](https://vthanik.github.io/herald/reference/loinc_provider.md),
[`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md),
[`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md),
[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md),
[`snomed_provider()`](https://vthanik.github.io/herald/reference/snomed_provider.md),
[`srs_provider()`](https://vthanik.github.io/herald/reference/srs_provider.md),
[`unregister_dictionary()`](https://vthanik.github.io/herald/reference/unregister_dictionary.md),
[`whodrug_provider()`](https://vthanik.github.io/herald/reference/whodrug_provider.md)

## Examples

``` r
# No providers registered yet -- returns empty tibble
list_dictionaries()
#> # A tibble: 0 × 5
#> # ℹ 5 variables: name <chr>, version <chr>, source <chr>,
#> #   license <chr>, size_rows <int>

# Register SDTM CT, then list
p <- ct_provider("sdtm")
register_dictionary("sdtm", p)
list_dictionaries()
#> # A tibble: 1 × 5
#>   name  version    source  license   size_rows
#>   <chr> <chr>      <chr>   <chr>         <int>
#> 1 sdtm  2026-03-27 bundled CC-BY-4.0     45612
unregister_dictionary("sdtm")

# Session registry only (skip cache scan)
list_dictionaries(include_global = TRUE, include_cache = FALSE)
#> # A tibble: 0 × 5
#> # ℹ 5 variables: name <chr>, version <chr>, source <chr>,
#> #   license <chr>, size_rows <int>
```
