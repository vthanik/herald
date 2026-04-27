# Write a data frame as CDISC Dataset-JSON v1.1

Writes a data frame to a CDISC Dataset-JSON v1.1 file following the
official CDISC specification. Column labels, types, and lengths are
extracted from attributes on each column. If the `herald.sort_keys`
attribute is set, the data is sorted before writing. JSON is always
UTF-8.

## Usage

``` r
write_json(
  x,
  file,
  dataset = NULL,
  label = NULL,
  study_oid = "",
  metadata_version_oid = "",
  metadata_ref = NULL,
  originator = "herald"
)
```

## Arguments

- x:

  A data frame.

- file:

  Output file path (should end in `.json`).

- dataset:

  Dataset name (e.g., `"DM"`). Default: inferred from the
  `"dataset_name"` attribute or the file name.

- label:

  Dataset label. Default: from the `"label"` attribute.

- study_oid:

  Study OID for metadata. Default: `""`.

- metadata_version_oid:

  Metadata version OID. Default: `""`.

- metadata_ref:

  Path to define.xml. Default: `NULL`.

- originator:

  Originator name. Default: `"herald"`.

## Value

`x` invisibly (the input data frame, not the file path).

## See also

[`read_json()`](https://vthanik.github.io/herald/reference/read_json.md)
for reading,
[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md)
for XPT I/O.

Other io:
[`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md),
[`read_json()`](https://vthanik.github.io/herald/reference/read_json.md),
[`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md),
[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md),
[`write_parquet()`](https://vthanik.github.io/herald/reference/write_parquet.md),
[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md)

## Examples

``` r
dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
dm   <- apply_spec(dm, spec)
file <- tempfile(fileext = ".json")
on.exit(unlink(file))

# ---- Write with label -- dataset name inferred from variable symbol (dm -> "DM") ----
write_json(dm, file, label = "Demographics")
attr(read_json(file), "dataset_name")   # "DM"
#> [1] "DM"

# ---- Explicit dataset and label overrides ----------------------------
file2 <- tempfile(fileext = ".json")
on.exit(unlink(file2), add = TRUE)
write_json(dm, file2, dataset = "DM", label = "Demographics SDTM")

# ---- With study OID and metadata reference (for define.xml linkage) ----
file3 <- tempfile(fileext = ".json")
on.exit(unlink(file3), add = TRUE)
write_json(dm, file3,
  dataset             = "DM",
  study_oid           = "STUDY.PILOT01",
  metadata_version_oid = "MDV.1",
  metadata_ref        = "define.xml"
)

# ---- Plain data frame without prior apply_spec (attributes inferred from variable name) ----
ae <- data.frame(
  STUDYID = "X", DOMAIN = "AE", USUBJID = "X-001",
  stringsAsFactors = FALSE
)
file4 <- tempfile(fileext = ".json")
on.exit(unlink(file4), add = TRUE)
write_json(ae, file4)
attr(read_json(file4), "dataset_name")  # "AE"
#> [1] "AE"
```
