# Construct a dictionary-provider object

**\[experimental\]**

Low-level constructor used by every provider factory. Validates the
required fields, sets the S3 class, and returns the object. Factory
authors should prefer this over hand-assembling a list so the protocol
contract stays stable.

## Usage

``` r
new_dict_provider(
  name,
  version = NA_character_,
  source = "unknown",
  license = "unknown",
  license_note = "",
  size_rows = NA_integer_,
  fields = character(),
  contains,
  info = NULL,
  lookup = NULL
)
```

## Arguments

- name, version, source, license, license_note, size_rows, fields:

  Metadata fields.

- contains:

  Function `(value, field, ignore_case) -> logical`.

- info:

  Function `() -> list`. Defaults to a closure returning the metadata
  fields above.

- lookup:

  Optional function `(value, field) -> list`.

## Value

An object of class `c("herald_dict_provider", "list")`.

## Provider protocol

Every `herald_dict_provider` honours the same contract so rule ops do
not need to know whether the data comes from CDISC CT, FDA SRS, MedDRA,
WHO-Drug, LOINC, SNOMED, or a sponsor-private table:

- `provider$contains(value, field, ignore_case)` returns a logical
  vector aligned with `value`. Required.

- `provider$lookup(value, field)` returns matching rows (any
  row-bindable shape). Optional; ops that need richer metadata degrade
  gracefully when absent.

- `provider$info()` returns the metadata list (`name`, `version`,
  `source`, `license`, `license_note`, `size_rows`, `fields`).

## Caching

Providers built from on-disk distributions (CT, SRS, MedDRA, ...) keep
the parsed table in memory inside their closure – no re-parse cost
across
[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
calls. Bundled CDISC CT is mmap-friendly and loads lazily through
[`load_ct()`](https://vthanik.github.io/herald/reference/load_ct.md).

## See also

Other dict:
[`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
[`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md),
[`list_dictionaries()`](https://vthanik.github.io/herald/reference/list_dictionaries.md),
[`loinc_provider()`](https://vthanik.github.io/herald/reference/loinc_provider.md),
[`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md),
[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md),
[`snomed_provider()`](https://vthanik.github.io/herald/reference/snomed_provider.md),
[`srs_provider()`](https://vthanik.github.io/herald/reference/srs_provider.md),
[`unregister_dictionary()`](https://vthanik.github.io/herald/reference/unregister_dictionary.md),
[`whodrug_provider()`](https://vthanik.github.io/herald/reference/whodrug_provider.md)

## Examples

``` r
# ---- Minimal provider: name + contains function ----------------------
p1 <- new_dict_provider(
  name     = "my-codes",
  contains = function(value, field = "code", ignore_case = FALSE) {
    value %in% c("A", "B", "C")
  },
  fields   = "code",
  size_rows = 3L
)
p1$contains(c("A", "D"))        # TRUE FALSE
#> [1]  TRUE FALSE
p1$info()$name                   # "my-codes"
#> [1] "my-codes"

# ---- With version, source, and license metadata ----------------------
p2 <- new_dict_provider(
  name     = "sponsor-sex",
  version  = "2026-01",
  source   = "sponsor",
  license  = "sponsor-private",
  contains = function(value, field = "code", ignore_case = FALSE) {
    value %in% c("M", "F", "U")
  },
  fields    = "code",
  size_rows = 3L
)
p2$info()$version
#> [1] "2026-01"

# ---- With optional lookup function (returns matching rows) -----------
ref <- data.frame(
  code  = c("M", "F"),
  label = c("Male", "Female"),
  stringsAsFactors = FALSE
)
p3 <- new_dict_provider(
  name     = "sex-codes",
  contains = function(value, field = "code", ignore_case = FALSE) {
    value %in% ref$code
  },
  lookup   = function(value, field = "code") {
    ref[ref$code %in% value, , drop = FALSE]
  },
  fields    = "code",
  size_rows = nrow(ref)
)
p3$lookup("M")
#>   code label
#> 1    M  Male

# ---- Register and use in validate() ----------------------------------
register_dictionary("sex-codes", p3)
list_dictionaries()
#> # A tibble: 1 × 5
#>   name      version source  license size_rows
#>   <chr>     <chr>   <chr>   <chr>       <int>
#> 1 sex-codes NA      unknown unknown         2
unregister_dictionary("sex-codes")
```
