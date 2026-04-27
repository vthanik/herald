# Convert a dataset between XPT, Dataset-JSON, and Parquet

Reads a dataset file in one CDISC-friendly format and writes it in
another, preserving all CDISC column attributes (label, format, length,
type) and dataset-level attributes (`dataset_name`, `label`).

Formats are inferred from the file extensions of `input` and `output`;
pass `from` / `to` to override. All nine directions are supported,
including same-format round-trips (useful as attribute sanity checks):

|           |            |
|-----------|------------|
| **input** | **output** |
| xpt       | xpt        |
| xpt       | json       |
| xpt       | parquet    |
| json      | xpt        |
| json      | json       |
| json      | parquet    |
| parquet   | xpt        |
| parquet   | json       |
| parquet   | parquet    |

## Usage

``` r
convert_dataset(
  input,
  output,
  to = NULL,
  from = NULL,
  dataset = NULL,
  label = NULL,
  version = 5L
)
```

## Arguments

- input:

  Path to the input dataset file.

- output:

  Path to the output dataset file.

- to:

  One of `"xpt"`, `"json"`, `"parquet"`. Default: inferred from
  `tools::file_ext(output)`.

- from:

  One of `"xpt"`, `"json"`, `"parquet"`. Default: inferred from
  `tools::file_ext(input)`.

- dataset:

  Dataset name override. Default: the `"dataset_name"` attribute of the
  input data, falling back to the uppercased file stem of `input`.

- label:

  Dataset label override. Default: the `"label"` attribute of the input
  data.

- version:

  XPT version (`5L` or `8L`). Only used when `to == "xpt"`; ignored
  otherwise.

## Value

`output` (the path to the written file) invisibly.

## See also

[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md),
[`read_json()`](https://vthanik.github.io/herald/reference/read_json.md),
[`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md),
[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md),
[`write_json()`](https://vthanik.github.io/herald/reference/write_json.md),
[`write_parquet()`](https://vthanik.github.io/herald/reference/write_parquet.md).

Other io:
[`read_json()`](https://vthanik.github.io/herald/reference/read_json.md),
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

xpt  <- tempfile(fileext = ".xpt")
json <- tempfile(fileext = ".json")
on.exit(unlink(c(xpt, json)))
write_xpt(dm, xpt)

# ---- XPT -> Dataset-JSON (format inferred from file extensions) ------
convert_dataset(xpt, json)
attr(read_json(json), "dataset_name")
#> [1] "DM"

# ---- Dataset-JSON -> XPT (reverse direction) -------------------------
xpt2 <- tempfile(fileext = ".xpt")
on.exit(unlink(xpt2), add = TRUE)
convert_dataset(json, xpt2)
attr(read_xpt(xpt2), "dataset_name")
#> [1] "DM"

# ---- Explicit format= override (no extension inference needed) -------
json2 <- tempfile()           # no extension
on.exit(unlink(json2), add = TRUE)
convert_dataset(xpt, json2, from = "xpt", to = "json")

# ---- Override dataset name and label at conversion time --------------
json3 <- tempfile(fileext = ".json")
on.exit(unlink(json3), add = TRUE)
convert_dataset(xpt, json3, dataset = "DM", label = "Demographics")
attr(read_json(json3), "label")
#> [1] "Demographics"
```
