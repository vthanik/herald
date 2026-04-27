# Read an Apache Parquet dataset with CDISC column attributes

Reads a Parquet file into a data frame and restores CDISC metadata from
the file's key/value metadata: column labels, SAS formats, lengths, and
XPT types written by
[`write_parquet()`](https://vthanik.github.io/herald/reference/write_parquet.md)
are recovered as R attributes. Parquet files without `herald.*` keys are
read as plain data frames; call
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
afterwards to stamp attributes from a spec.

Requires the `arrow` package.

## Usage

``` r
read_parquet(file)
```

## Arguments

- file:

  Path to a `.parquet` file.

## Value

A data.frame with `attr(df, "label")`, `attr(df, "dataset_name")`, and
per-column `attr(col, "label")`, `attr(col, "format.sas")`,
`attr(col, "sas.length")`, `attr(col, "xpt_type")` populated from the
file's key/value metadata when present.

## See also

[`write_parquet()`](https://vthanik.github.io/herald/reference/write_parquet.md),
[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md),
[`read_json()`](https://vthanik.github.io/herald/reference/read_json.md).

Other io:
[`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md),
[`read_json()`](https://vthanik.github.io/herald/reference/read_json.md),
[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md),
[`write_json()`](https://vthanik.github.io/herald/reference/write_json.md),
[`write_parquet()`](https://vthanik.github.io/herald/reference/write_parquet.md),
[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md)

## Examples

``` r
dm  <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
dm  <- apply_spec(dm, spec)
out <- tempfile(fileext = ".parquet")
on.exit(unlink(out))
write_parquet(dm, out, label = "Demographics")

# ---- Read back and inspect dataset-level attributes ------------------
dm2 <- read_parquet(out)
attr(dm2, "label")           # "Demographics"
#> [1] "Demographics"
attr(dm2, "dataset_name")    # "DM"
#> [1] "DM"

# ---- Column-level attributes preserved in key/value metadata ---------
attr(dm2$USUBJID, "label")
#> [1] "Unique Subject Identifier"
attr(dm2$USUBJID, "sas.length")
#> [1] 11

# ---- Read then apply_spec to stamp from spec (supplement any missing attrs) ----
dm3 <- read_parquet(out) |> apply_spec(spec)
attr(dm3$STUDYID, "label")
#> [1] "Study Identifier"

# ---- Read then validate ----------------------------------------------
r <- validate(files = dm2, quiet = TRUE)
r$datasets_checked
#> [1] "DM2"
```
