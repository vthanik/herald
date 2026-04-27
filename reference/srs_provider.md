# FDA SRS / UNII as a Dictionary Provider

**\[experimental\]**

Returns a `herald_dict_provider` backed by the user-cached FDA SRS table
(written by
[`download_srs()`](https://vthanik.github.io/herald/reference/download_srs.md)).
Rule ops query it under the name `"srs"`.

## Usage

``` r
srs_provider(version = "latest-cache")
```

## Arguments

- version:

  One of:

  - `"latest-cache"` (default) – newest cached SRS entry.

  - a `YYYY-MM-DD` string matching a prior
    [`download_srs()`](https://vthanik.github.io/herald/reference/download_srs.md).

  - an absolute `.rds` path.

## Value

A `herald_dict_provider` with name `"srs"`; returns NULL when the cache
is empty – op layer records a missing_ref with a hint pointing the user
at
[`download_srs()`](https://vthanik.github.io/herald/reference/download_srs.md).

## See also

[`download_srs()`](https://vthanik.github.io/herald/reference/download_srs.md),
[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md).

Other dict:
[`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
[`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md),
[`list_dictionaries()`](https://vthanik.github.io/herald/reference/list_dictionaries.md),
[`loinc_provider()`](https://vthanik.github.io/herald/reference/loinc_provider.md),
[`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md),
[`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md),
[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md),
[`snomed_provider()`](https://vthanik.github.io/herald/reference/snomed_provider.md),
[`unregister_dictionary()`](https://vthanik.github.io/herald/reference/unregister_dictionary.md),
[`whodrug_provider()`](https://vthanik.github.io/herald/reference/whodrug_provider.md)

## Examples

``` r
# Requires a prior download_srs() call to populate the cache
if (interactive()) {
  p <- srs_provider()

  # Preferred-name lookup (case-sensitive)
  p$contains("ASPIRIN", field = "preferred_name")    # TRUE
  p$contains("aspirin", field = "preferred_name",
             ignore_case = TRUE)                      # TRUE

  # UNII code lookup
  p$contains("R16CO5Y76E", field = "unii")           # TRUE (aspirin)

  # Provider metadata
  p$info()$version
  p$info()$size_rows

  # Pin to a specific cached version
  p2 <- srs_provider(version = "2026-04-01")

  # Register globally so all validate() calls pick it up
  register_dictionary("srs", p)
}
```
