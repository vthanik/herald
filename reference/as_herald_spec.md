# Construct a `herald_spec` object

**\[experimental\]**

Assembles a
[`herald_spec`](https://vthanik.github.io/herald/reference/herald_spec.md)
S3 object from two data frames describing the datasets and variables in
a submission. The result is the canonical specification handed to
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
and
[`validate()`](https://vthanik.github.io/herald/reference/validate.md):

- Normalises column names to lowercase.

- Checks required columns (`dataset` on `ds_spec`; `dataset`, `variable`
  on `var_spec`).

- Uppercases dataset and variable names for case-insensitive joins.

- Preserves any extra columns unchanged so sponsor-specific metadata
  round-trips through
  [`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md).

## Usage

``` r
as_herald_spec(ds_spec, var_spec = NULL)
```

## Arguments

- ds_spec:

  Data frame. Must carry column `dataset`. Recognised further columns:
  `class`, `label`, `standard`. Any other columns are preserved.

- var_spec:

  Optional data frame. Must carry columns `dataset` and `variable`.
  Recognised further columns: `type`, `label`, `format`, `length`,
  `role`. NULL is allowed (dataset-only spec).

## Value

A list with class `c("herald_spec", "list")` holding `ds_spec` and (if
supplied) `var_spec`.

## Input dispatch

`as_herald_spec()` is the simple two-arg form. The richer
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md)
constructor accepts the full Define-XML 2.1 slot set (study, codelist,
methods, comments, ARM displays, etc.). Common upstream sources:

- Two raw data frames (this constructor).

- A `herald_define` object from
  [`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md)
  – pass `d$ds_spec` and `d$var_spec` directly.

- An existing `herald_spec` – returned unchanged by
  [`is_herald_spec()`](https://vthanik.github.io/herald/reference/is_herald_spec.md)
  guards in callers.

## See also

[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
for the pre-validation step that stamps column attributes from a
`herald_spec`.

Other spec:
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md),
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md),
[`is_herald_spec()`](https://vthanik.github.io/herald/reference/is_herald_spec.md),
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md),
[`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md),
[`write_define_html()`](https://vthanik.github.io/herald/reference/write_define_html.md),
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md)

## Examples

``` r
dm   <- readRDS(system.file("extdata", "dm.rds",   package = "herald"))
adsl <- readRDS(system.file("extdata", "adsl.rds", package = "herald"))
adae <- readRDS(system.file("extdata", "adae.rds", package = "herald"))

# ---- Dataset-only spec (no var_spec) -- sufficient for class-scoped rules ----
spec_ds_only <- as_herald_spec(
  ds_spec = data.frame(dataset = "DM", stringsAsFactors = FALSE)
)
is_herald_spec(spec_ds_only)
#> [1] TRUE
spec_ds_only$ds_spec
#>   dataset
#> 1      DM

# ---- Single dataset with variable list -------------------------------
spec_single <- as_herald_spec(
  ds_spec  = data.frame(dataset = "DM", label = "Demographics",
                        stringsAsFactors = FALSE),
  var_spec = data.frame(dataset = "DM", variable = names(dm),
                        stringsAsFactors = FALSE)
)
nrow(spec_single$var_spec)
#> [1] 25

# ---- Multi-dataset with class + label (ADaM) -------------------------
spec_adam <- as_herald_spec(
  ds_spec = data.frame(
    dataset = c("ADSL", "ADAE"),
    class   = c("SUBJECT LEVEL ANALYSIS DATASET", "OCCDS"),
    label   = c("Subject-Level Analysis Dataset", "Adverse Events"),
    stringsAsFactors = FALSE
  ),
  var_spec = data.frame(
    dataset  = c(rep("ADSL", ncol(adsl)), rep("ADAE", ncol(adae))),
    variable = c(names(adsl), names(adae)),
    stringsAsFactors = FALSE
  )
)
nrow(spec_adam$ds_spec)
#> [1] 2

# ---- Rich var_spec with type, label, format, length ------------------
spec_rich <- as_herald_spec(
  ds_spec  = data.frame(dataset = "DM", stringsAsFactors = FALSE),
  var_spec = data.frame(
    dataset  = c("DM", "DM"),
    variable = c("STUDYID", "USUBJID"),
    label    = c("Study Identifier", "Unique Subject Identifier"),
    type     = c("text", "text"),
    length   = c(12L, 40L),
    stringsAsFactors = FALSE
  )
)
spec_rich$var_spec[, c("variable", "label", "length")]
#>   variable                     label length
#> 1  STUDYID          Study Identifier     12
#> 2  USUBJID Unique Subject Identifier     40
```
