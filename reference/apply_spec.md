# Stamp column and dataset attributes from a `herald_spec`

**\[stable\]**

Pre-validation helper that copies CDISC metadata from a
[`herald_spec`](https://vthanik.github.io/herald/reference/as_herald_spec.md)
onto each dataset's columns and onto the data frame itself, so
downstream rule operators can read attributes uniformly regardless of
how the data was ingested. Spec values overwrite any existing attribute;
columns with no spec row are untouched.

- Sets `attr(ds, "label")` from `spec$ds_spec$label`.

- Sets per-column `"label"`, `"format.sas"`, `"sas.length"`, and
  `"xpt_type"` from `spec$var_spec`.

- Leaves datasets that are not in `spec` unchanged.

Call this before
[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
when datasets come from CSV, plain data.frames, or any source that does
not itself carry CDISC metadata. XPT and Dataset-JSON readers already
set these attributes at ingest, so `apply_spec()` is optional there.

## Usage

``` r
apply_spec(datasets, spec)
```

## Arguments

- datasets:

  Either a single data frame **or** a named list of data frames. When a
  single data frame is passed, the dataset name is inferred from the
  variable name (`dm` -\> `"DM"`), then
  `attr(datasets, "dataset_name")`, then `"DATA"`. A single data frame
  is returned; a list returns a list.

- spec:

  A `herald_spec` (see
  [`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md)).

## Value

Same shape as `datasets`: a data frame if one was passed, a named list
otherwise.

## Stamped attributes

For each row in `spec$var_spec` matching a column in `datasets`,
`apply_spec()` writes:

- `attr(col, "label")` from `var_spec$label`

- `attr(col, "format.sas")` from `var_spec$format`

- `attr(col, "sas.length")` from `var_spec$length`

- `attr(col, "xpt_type")` from `var_spec$type`

Dataset-level `attr(ds, "label")` is taken from `spec$ds_spec$label`.

## Missing or extra variables

Variables present in `spec$var_spec` but not in the dataset are silently
skipped – `apply_spec()` does not add columns. Variables present in the
dataset but not in `spec$var_spec` are left unchanged (existing
attributes preserved). Datasets named in `spec$ds_spec` but missing from
`datasets` are also skipped without error; herald rules will catch
missing required datasets at validation time.

## See also

[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md),
[`validate()`](https://vthanik.github.io/herald/reference/validate.md).

Other spec:
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md),
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md),
[`is_herald_spec()`](https://vthanik.github.io/herald/reference/is_herald_spec.md),
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md),
[`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md),
[`write_define_html()`](https://vthanik.github.io/herald/reference/write_define_html.md),
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md)

## Examples

``` r
dm   <- readRDS(system.file("extdata", "dm.rds",        package = "herald"))
spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))

# single dataset -- name inferred from variable (dm -> "DM")
dm <- apply_spec(dm, spec)
attr(dm, "label")
#> [1] "Demographics"
attr(dm$USUBJID, "label")
#> [1] "Unique Subject Identifier"

# pipe-friendly
dm2 <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
dm2 <- dm2 |> apply_spec(spec)
```
