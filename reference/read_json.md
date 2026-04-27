# Read a CDISC Dataset-JSON file

Reads a CDISC Dataset-JSON v1.1 file into a data frame, restoring column
and dataset metadata from the JSON structure: column labels, lengths,
display formats, and the dataset name are all preserved as R attributes.

## Usage

``` r
read_json(file)
```

## Arguments

- file:

  Path to a `.json` Dataset-JSON file.

## Value

A data frame with:

- `attr(df, "label")`:

  Dataset label.

- `attr(df, "dataset_name")`:

  Dataset name.

- per-column `"label"`:

  Column label from the JSON `columns[].label` field.

- per-column `"sas.length"`:

  Column length from `columns[].length`.

- per-column `"format.sas"`:

  Display format from `columns[].displayFormat`.

- per-column `"xpt_type"`:

  Logical type from `columns[].dataType`.

## See also

[`write_json()`](https://vthanik.github.io/herald/reference/write_json.md)
for writing,
[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md),
[`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md),
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
to stamp CDISC attributes after reading.

Other io:
[`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md),
[`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md),
[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md),
[`write_json()`](https://vthanik.github.io/herald/reference/write_json.md),
[`write_parquet()`](https://vthanik.github.io/herald/reference/write_parquet.md),
[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md)

## Examples

``` r
dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
dm   <- apply_spec(dm, spec)
file <- tempfile(fileext = ".json")
on.exit(unlink(file))
write_json(dm, file, label = "Demographics")

# ---- Read back and inspect dataset-level attributes ------------------
dm2 <- read_json(file)
attr(dm2, "label")          # "Demographics"
#> [1] "Demographics"
attr(dm2, "dataset_name")   # "DM"
#> [1] "DM"

# ---- Inspect column-level attributes preserved from write_json -------
attr(dm2$USUBJID, "label")
#> [1] "Unique Subject Identifier"
attr(dm2$STUDYID, "sas.length")
#> [1] 12

# ---- Read then apply_spec to overwrite/supplement attributes from spec ----
dm3 <- read_json(file) |> apply_spec(spec)
attr(dm3$USUBJID, "label")
#> [1] "Unique Subject Identifier"

# ---- Read then validate immediately ----------------------------------
r <- validate(files = dm2, quiet = TRUE)
r$datasets_checked
#> [1] "DM2"
```
