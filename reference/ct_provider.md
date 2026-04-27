# CDISC Controlled Terminology as a Dictionary Provider

**\[experimental\]**

Returns a `herald_dict_provider` that serves the bundled (or
user-cached) CDISC CT. Rule ops that need to check codelist membership
look up this provider under the name `"ct-sdtm"` or `"ct-adam"`.

## Usage

``` r
ct_provider(package = c("sdtm", "adam"), version = "bundled")
```

## Arguments

- package:

  One of `"sdtm"`, `"adam"`. Defaults to `"sdtm"`.

- version:

  Same semantics as
  [`load_ct()`](https://vthanik.github.io/herald/reference/load_ct.md):
  `"bundled"` \| `"latest-cache"` \| `"YYYY-MM-DD"` \| absolute `.rds`
  path.

## Value

A `herald_dict_provider` with provider name `paste0("ct-", package)`.

## Provider protocol

`contains(value, field, ignore_case)` interprets `field` as the codelist
short name (e.g. `"NY"`, `"ARMNULRS"`), the NCI C-code, or the long
human-readable codelist name – the same dispatch order as
`.lookup_codelist()` used by SDTM ops. Returns `NA` when `field` is
missing or unknown so missing-codelist conditions surface as advisory
findings, not errors.

## Caching

The bundled CT is loaded once via
[`load_ct()`](https://vthanik.github.io/herald/reference/load_ct.md) and
held in the provider closure for the lifetime of the object. Cache hits
from a prior
[`download_ct()`](https://vthanik.github.io/herald/reference/download_ct.md)
are addressable through `version =`.

## See also

[`load_ct()`](https://vthanik.github.io/herald/reference/load_ct.md),
[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md).

Other dict:
[`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md),
[`list_dictionaries()`](https://vthanik.github.io/herald/reference/list_dictionaries.md),
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
# Bundled SDTM CT (always available, no network)
p <- ct_provider("sdtm")
p$contains("Y", field = "NY")           # TRUE
#> [1] TRUE
p$contains("UNKNOWN", field = "NY")     # FALSE
#> [1] FALSE
p$contains(c("Y", "N", "BAD"), field = "NY")  # TRUE TRUE FALSE
#> [1]  TRUE  TRUE FALSE
p$info()$version
#> [1] "2026-03-27"
p$info()$codelist_count
#> NULL

# Case-insensitive lookup
p$contains("y", field = "NY", ignore_case = TRUE)  # TRUE
#> [1] TRUE

# ADaM CT provider
pa <- ct_provider("adam")
pa$info()$size_rows
#> [1] 144

# Register globally so every validate() picks it up
register_dictionary("ct-sdtm", p)
list_dictionaries()
#> # A tibble: 1 × 5
#>   name    version    source  license   size_rows
#>   <chr>   <chr>      <chr>   <chr>         <int>
#> 1 ct-sdtm 2026-03-27 bundled CC-BY-4.0     45612
unregister_dictionary("ct-sdtm")

# Pinned version from user cache (requires prior download_ct())
if (interactive()) {
  p_pinned <- ct_provider("sdtm", version = "2024-09-27")
  p_pinned$info()$version
}
```
