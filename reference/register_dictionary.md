# Install a dictionary provider in the session registry

**\[experimental\]**

Adds `provider` to the session-level dictionary registry under `name`.
After this call every subsequent
[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
picks up the provider automatically unless explicitly overridden by the
`dictionaries =` argument:

- Sponsors install a MedDRA / WHO-Drug provider once at the top of a
  pipeline; downstream
  [`validate()`](https://vthanik.github.io/herald/reference/validate.md)
  calls inherit it.

- The same registry powers
  [`list_dictionaries()`](https://vthanik.github.io/herald/reference/list_dictionaries.md)
  for reporting.

- Use
  [`unregister_dictionary()`](https://vthanik.github.io/herald/reference/unregister_dictionary.md)
  to remove an entry.

## Usage

``` r
register_dictionary(name, provider)
```

## Arguments

- name:

  Character scalar – canonical short name (e.g. `"meddra"`, `"whodrug"`,
  `"srs"`, `"sponsor-race"`).

- provider:

  A `herald_dict_provider` (from one of the factories:
  [`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
  [`srs_provider()`](https://vthanik.github.io/herald/reference/srs_provider.md),
  [`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md),
  ...).

## Value

`invisible(provider)`.

## See also

Other dict:
[`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
[`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md),
[`list_dictionaries()`](https://vthanik.github.io/herald/reference/list_dictionaries.md),
[`loinc_provider()`](https://vthanik.github.io/herald/reference/loinc_provider.md),
[`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md),
[`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md),
[`snomed_provider()`](https://vthanik.github.io/herald/reference/snomed_provider.md),
[`srs_provider()`](https://vthanik.github.io/herald/reference/srs_provider.md),
[`unregister_dictionary()`](https://vthanik.github.io/herald/reference/unregister_dictionary.md),
[`whodrug_provider()`](https://vthanik.github.io/herald/reference/whodrug_provider.md)

## Examples

``` r
# Register bundled SDTM CT and inspect the registry
p <- ct_provider("sdtm")
register_dictionary("sdtm", p)
list_dictionaries()
#> # A tibble: 1 × 5
#>   name  version    source  license   size_rows
#>   <chr> <chr>      <chr>   <chr>         <int>
#> 1 sdtm  2026-03-27 bundled CC-BY-4.0     45612

# Register a custom sponsor-private dictionary
codes <- data.frame(site = c("S01", "S02", "S03"), stringsAsFactors = FALSE)
sponsor_p <- custom_provider(codes, name = "site-codes", fields = "site")
register_dictionary("site-codes", sponsor_p)
list_dictionaries()
#> # A tibble: 2 × 5
#>   name       version    source  license         size_rows
#>   <chr>      <chr>      <chr>   <chr>               <int>
#> 1 sdtm       2026-03-27 bundled CC-BY-4.0           45612
#> 2 site-codes unknown    sponsor sponsor-private         3

# Clean up
unregister_dictionary("sdtm")
unregister_dictionary("site-codes")
```
