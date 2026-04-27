# MedDRA as a Dictionary Provider

**\[experimental\]**

Reads an MSSO MedDRA ASCII distribution from `path` and returns a
`herald_dict_provider`. Supports membership checks at any level:
`"llt"`, `"pt"`, `"hlt"`, `"hlgt"`, `"soc"`. Since MedDRA is licensed,
herald never bundles the data – the user must supply a valid local
distribution.

## Usage

``` r
meddra_provider(path, version = "unknown")
```

## Arguments

- path:

  Directory containing the MedDRA ASCII files OR a direct path to
  `mdhier.asc`. When a directory is given, the factory looks for
  `mdhier.asc` (required) and `llt.asc` (optional).

- version:

  MedDRA release tag (e.g. `"27.0"`). User-supplied; MedDRA files don't
  self-identify. Defaults to `"unknown"`.

## Value

A `herald_dict_provider` with name `"meddra"`.

## See also

[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md),
[`whodrug_provider()`](https://vthanik.github.io/herald/reference/whodrug_provider.md).

Other dict:
[`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
[`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md),
[`list_dictionaries()`](https://vthanik.github.io/herald/reference/list_dictionaries.md),
[`loinc_provider()`](https://vthanik.github.io/herald/reference/loinc_provider.md),
[`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md),
[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md),
[`snomed_provider()`](https://vthanik.github.io/herald/reference/snomed_provider.md),
[`srs_provider()`](https://vthanik.github.io/herald/reference/srs_provider.md),
[`unregister_dictionary()`](https://vthanik.github.io/herald/reference/unregister_dictionary.md),
[`whodrug_provider()`](https://vthanik.github.io/herald/reference/whodrug_provider.md)

## Examples

``` r
# Requires a licensed MedDRA ASCII distribution (user-supplied)
if (interactive()) {
  p <- meddra_provider("/path/to/meddra_27_0/MedAscii", version = "27.0")

  # Preferred-term lookup
  p$contains("Headache", field = "pt")          # TRUE
  p$contains("HEADACHE", field = "pt")          # FALSE (case-sensitive)
  p$contains("HEADACHE", field = "pt",
             ignore_case = TRUE)                 # TRUE

  # High-level term and SOC lookup
  p$contains("Nervous system disorders", field = "soc")
  p$contains("Headaches NEC", field = "hlt")

  # Lowest-level term (when llt.asc is present)
  p$contains("Tension headache", field = "llt")

  # Inspect provider metadata
  p$info()$version          # "27.0"
  p$info()$fields           # available query fields

  # Register globally for all subsequent validate() calls
  register_dictionary("meddra", p)
}
```
