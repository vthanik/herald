# Dataset I/O and Format Conversion

`herald` treats clinical data frames as ordinary R data frames plus a
small attribute contract:

- dataset label: `attr(x, "label")`
- dataset name: `attr(x, "dataset_name")`
- variable label: `attr(x$VAR, "label")`
- XPT storage length: `attr(x$VAR, "sas.length")`
- XPT type: `attr(x$VAR, "xpt_type")`

Those attributes are used by the XPT, Dataset-JSON, Parquet, and
reporting layers.

## Prepare a dataset

``` r
dm <- readRDS(extdata("dm.rds"))
spec <- readRDS(extdata("sdtm-spec.rds"))
dm <- apply_spec(dm, spec)

attr(dm, "label")
#> [1] "Demographics"
attr(dm$USUBJID, "label")
#> [1] "Unique Subject Identifier"
```

## XPT

[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md)
writes SAS transport files in pure R.
[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md)
reads them back and restores dataset and column metadata.

``` r
io_dir <- file.path(tempdir(), "herald-io")
dir.create(io_dir, showWarnings = FALSE)

xpt <- file.path(io_dir, "dm.xpt")
write_xpt(dm, xpt)

dm_xpt <- read_xpt(xpt)

nrow(dm_xpt)
#> [1] 50
attr(dm_xpt, "label")
#> [1] "Demographics"
attr(dm_xpt$USUBJID, "label")
#> [1] "Unique Subject Identifier"
```

## Dataset-JSON

Dataset-JSON is useful for APIs, review automation, and text-friendly
interchange.

``` r
json <- file.path(io_dir, "dm.json")
write_json(dm, json)

dm_json <- read_json(json)

identical(nrow(dm), nrow(dm_json))
#> [1] TRUE
attr(dm_json$USUBJID, "label")
#> [1] "Unique Subject Identifier"
```

## Parquet

Parquet support uses the optional `arrow` package. Keep the code guarded
in portable vignettes and CI jobs.

``` r
parquet <- file.path(io_dir, "dm.parquet")
write_parquet(dm, parquet)

dm_parquet <- read_parquet(parquet)
nrow(dm_parquet)
#> [1] 50
```

## Conversion

[`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md)
infers formats from file extensions. Use `from =` and `to =` when
extensions are nonstandard.

``` r
xpt2  <- file.path(io_dir, "dm-roundtrip.xpt")
json2 <- file.path(io_dir, "dm-roundtrip.json")

convert_dataset(xpt, json2)
convert_dataset(json2, xpt2)

file.exists(c(json2, xpt2))
#> [1] TRUE TRUE
```

Same-format conversion is also valid. It is useful when you want to
normalize metadata or smoke-test read/write symmetry.

``` r
json3 <- file.path(io_dir, "dm-copy.json")
convert_dataset(json2, json3)
file.exists(json3)
#> [1] TRUE
```

## Validation after I/O

The validation layer is format-blind after data is loaded.

``` r
dm <- read_xpt(xpt)

result <- validate(
  files = dm,
  rules = character(0),
  quiet = TRUE
)

result$datasets_checked
#> [1] "DM"
```

The recommended production pattern is to stamp metadata once with
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md),
write transport files, read them back in CI, and validate the files that
will actually be submitted.
