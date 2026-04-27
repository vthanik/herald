# Generic in-memory Dictionary Provider

**\[experimental\]**

Wraps any data frame into a `herald_dict_provider`. The sponsor supplies
a (usually small) reference table and the fields (column names) that
rules may query. Useful for site codes, custom RACE categories,
pilot-study codelists, or any sponsor-private terminology that isn't
covered by a CDISC CT codelist.

## Usage

``` r
custom_provider(
  table,
  name,
  fields = NULL,
  version = "unknown",
  license = "sponsor-private"
)
```

## Arguments

- table:

  A data frame. The columns named in `fields` are queryable; other
  columns are kept for `lookup()` only.

- name:

  Canonical short name used in rule YAMLs (`dictionary: my-custom-cat`).

- fields:

  Character vector of column names to expose. Must be column names in
  `table`. Defaults to every column.

- version:

  Optional version tag.

- license:

  Optional license tag (e.g. `"sponsor-private"`).

## Value

A `herald_dict_provider`.

## See also

[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md).

Other dict:
[`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
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
races <- data.frame(
  race_code = c("1002-5", "2028-9", "2054-5"),
  race_label = c("American Indian or Alaska Native", "Asian", "Black or African American"),
  stringsAsFactors = FALSE
)
p <- custom_provider(races, name = "sponsor-race", fields = "race_code")
p$contains(c("2028-9", "9999"), field = "race_code")
#> [1]  TRUE FALSE
```
