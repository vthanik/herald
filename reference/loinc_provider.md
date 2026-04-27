# LOINC as a Dictionary Provider

**\[experimental\]**

Reads a Regenstrief LOINC CSV distribution (`Loinc.csv`) and returns a
`herald_dict_provider` with membership lookup by `LOINC_NUM`,
`COMPONENT`, `SHORTNAME`, or `LONG_COMMON_NAME`.

## Usage

``` r
loinc_provider(path, version = "unknown")
```

## Arguments

- path:

  Path to `Loinc.csv` OR a directory containing it.

- version:

  LOINC release tag (e.g. `"2.77"`). User-supplied.

## Value

A `herald_dict_provider` with name `"loinc"`.

## See also

[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md).

Other dict:
[`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
[`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md),
[`list_dictionaries()`](https://vthanik.github.io/herald/reference/list_dictionaries.md),
[`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md),
[`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md),
[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md),
[`snomed_provider()`](https://vthanik.github.io/herald/reference/snomed_provider.md),
[`srs_provider()`](https://vthanik.github.io/herald/reference/srs_provider.md),
[`unregister_dictionary()`](https://vthanik.github.io/herald/reference/unregister_dictionary.md),
[`whodrug_provider()`](https://vthanik.github.io/herald/reference/whodrug_provider.md)

## Examples

``` r
# Requires a LOINC CSV distribution (user-supplied)
if (interactive()) {
  p <- loinc_provider("/path/to/Loinc_2.77/LoincTable", version = "2.77")

  # LOINC code lookup (case-sensitive)
  p$contains("2160-0", field = "loinc_num")          # TRUE
  p$contains("9999-9", field = "loinc_num")          # FALSE

  # Short name and long name lookup
  p$contains("Creatinine", field = "shortname")
  p$contains("Creatinine [Mass/volume] in Serum or Plasma",
             field = "long_common_name")

  # Component lookup
  p$contains("Creatinine", field = "component")

  # Provider metadata
  p$info()$version   # "2.77"
  p$info()$fields    # all queryable field names

  # Register globally
  register_dictionary("loinc", p)
}
```
