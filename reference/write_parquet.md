# Write a data frame to Apache Parquet with CDISC column attributes

Writes a data frame to a Parquet file, embedding CDISC metadata (column
labels, SAS formats, lengths, and XPT types) in the file's key/value
metadata under `herald.*` keys. This ensures a full round-trip:
[`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md)
restores every attribute that `write_parquet()` saved.

Requires the `arrow` package.

## Usage

``` r
write_parquet(x, file, dataset = NULL, label = NULL)
```

## Arguments

- x:

  A data frame. Column attributes (`label`, `format.sas`, `sas.length`,
  `xpt_type`) are written to Parquet key/value metadata when present.

- file:

  Output path (should end in `.parquet`).

- dataset:

  Dataset name (e.g., `"DM"`). Default: inferred from the variable name
  (`dm` -\> `"DM"`), then `attr(x, "dataset_name")`, then the uppercase
  file stem.

- label:

  Dataset label. Default: `attr(x, "label")`.

## Value

`x` invisibly.

## See also

[`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md),
[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md),
[`write_json()`](https://vthanik.github.io/herald/reference/write_json.md).

Other io:
[`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md),
[`read_json()`](https://vthanik.github.io/herald/reference/read_json.md),
[`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md),
[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md),
[`write_json()`](https://vthanik.github.io/herald/reference/write_json.md),
[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md)

## Examples

``` r
dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
dm   <- apply_spec(dm, spec)
out  <- tempfile(fileext = ".parquet")
on.exit(unlink(out))

# ---- Dataset name inferred from variable symbol (dm -> "DM"), with label ----
write_parquet(dm, out, label = "Demographics")
attr(read_parquet(out), "dataset_name")   # "DM"
#> [1] "DM"

# ---- Explicit dataset and label overrides ----------------------------
out2 <- tempfile(fileext = ".parquet")
on.exit(unlink(out2), add = TRUE)
write_parquet(dm, out2, dataset = "DM", label = "Demographics SDTM")
attr(read_parquet(out2), "label")
#> [1] "Demographics SDTM"

# ---- Plain data frame (no apply_spec) -- name from variable symbol ----
ae <- data.frame(STUDYID = "X", USUBJID = "X-001", stringsAsFactors = FALSE)
out3 <- tempfile(fileext = ".parquet")
on.exit(unlink(out3), add = TRUE)
write_parquet(ae, out3, dataset = "AE", label = "Adverse Events")

# ---- Round-trip: write and read back, compare column counts ----------
write_parquet(dm, out)
dm_rt <- read_parquet(out)
identical(names(dm), names(dm_rt))
#> [1] TRUE
```
