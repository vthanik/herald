# WHO-Drug as a Dictionary Provider

**\[experimental\]**

Reads a UMC WHO-Drug B3 distribution from `path` and returns a
`herald_dict_provider` serving drug-name membership checks. Since
WHO-Drug is licensed, herald never bundles the data.

## Usage

``` r
whodrug_provider(path, version = "unknown", format = "b3")
```

## Arguments

- path:

  Directory containing the B3 distribution. Looks for `DD.txt`
  (required) and `DDA.txt` (optional alternate names).

- version:

  WHO-Drug release tag (e.g. `"2026-Mar-01"`). User-supplied.

- format:

  Currently only `"b3"` is supported; placeholder for future C3 support.

## Value

A `herald_dict_provider` with name `"whodrug"`.

## See also

[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md),
[`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md).

Other dict:
[`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
[`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md),
[`list_dictionaries()`](https://vthanik.github.io/herald/reference/list_dictionaries.md),
[`loinc_provider()`](https://vthanik.github.io/herald/reference/loinc_provider.md),
[`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md),
[`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md),
[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md),
[`snomed_provider()`](https://vthanik.github.io/herald/reference/snomed_provider.md),
[`srs_provider()`](https://vthanik.github.io/herald/reference/srs_provider.md),
[`unregister_dictionary()`](https://vthanik.github.io/herald/reference/unregister_dictionary.md)

## Examples

``` r
# Requires a licensed WHO-Drug B3 distribution (user-supplied)
if (interactive()) {
  p <- whodrug_provider("/path/to/whodrug-b3", version = "2026-Mar-01")

  # Drug-name lookup
  p$contains("ASPIRIN", field = "drug_name")       # TRUE
  p$contains("aspirin", field = "drug_name",
             ignore_case = TRUE)                    # TRUE

  # Alternate names (requires DDA.txt in the distribution)
  p$contains("ACETYLSALICYLIC ACID", field = "alternate_name")

  # Drug record number lookup
  p$contains("000062", field = "drug_record_number")

  # Provider metadata
  p$info()$version          # "2026-Mar-01"
  p$info()$size_rows

  # Register globally
  register_dictionary("whodrug", p)
}
```
