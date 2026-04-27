# SNOMED CT as a Dictionary Provider

**\[experimental\]**

Reads an IHTSDO SNOMED CT RF2 Description Snapshot file and returns a
`herald_dict_provider` with concept-id and term membership lookup.
SNOMED requires an affiliate licence in many jurisdictions; herald never
bundles the data.

## Usage

``` r
snomed_provider(path, version = "unknown")
```

## Arguments

- path:

  Path to the description-snapshot file OR a directory containing it
  (look pattern: `sct2_Description_Snapshot-en_*.txt`).

- version:

  SNOMED release tag. User-supplied.

## Value

A `herald_dict_provider` with name `"snomed"`.

## See also

[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md).

Other dict:
[`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
[`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md),
[`list_dictionaries()`](https://vthanik.github.io/herald/reference/list_dictionaries.md),
[`loinc_provider()`](https://vthanik.github.io/herald/reference/loinc_provider.md),
[`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md),
[`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md),
[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md),
[`srs_provider()`](https://vthanik.github.io/herald/reference/srs_provider.md),
[`unregister_dictionary()`](https://vthanik.github.io/herald/reference/unregister_dictionary.md),
[`whodrug_provider()`](https://vthanik.github.io/herald/reference/whodrug_provider.md)

## Examples

``` r
# Requires an IHTSDO SNOMED CT RF2 distribution (user-supplied)
if (interactive()) {
  p <- snomed_provider("/path/to/SnomedCT_RF2Release", version = "2024-01-31")

  # Term description lookup
  p$contains("Headache", field = "term")             # TRUE
  p$contains("headache", field = "term",
             ignore_case = TRUE)                      # TRUE

  # SNOMED concept ID lookup
  p$contains("25064002", field = "concept_id")       # TRUE (Headache)

  # Vector of values -- returns logical vector
  p$contains(c("Headache", "NOT_A_TERM"), field = "term")

  # Provider metadata
  p$info()$version        # "2024-01-31"
  p$info()$size_rows      # number of active descriptions

  # Register globally
  register_dictionary("snomed", p)
}
```
