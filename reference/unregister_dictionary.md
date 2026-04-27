# Remove a dictionary from the session registry

**\[experimental\]**

Removes a previously
[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md)-installed
provider. Idempotent: removing an unregistered name returns `FALSE`
rather than erroring, so it is safe to call from teardown blocks.

## Usage

``` r
unregister_dictionary(name)
```

## Arguments

- name:

  Character scalar.

## Value

`invisible(TRUE)` if removed, `FALSE` if not registered.

## See also

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
[`whodrug_provider()`](https://vthanik.github.io/herald/reference/whodrug_provider.md)

## Examples

``` r
p <- ct_provider("sdtm")
register_dictionary("sdtm", p)
unregister_dictionary("sdtm")    # returns TRUE
unregister_dictionary("sdtm")    # already gone -- returns FALSE
```
