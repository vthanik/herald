# Write a data frame to a SAS Transport (XPT) file

**\[stable\]**

Writes a data frame (or named list of data frames) to an XPT transport
file in V5 (FDA submission standard) or V8 (extended) format. Pure R
implementation – no SAS, no haven, no Java dependency. Round-trips
dataset / variable labels, SAS formats, SAS lengths, and `Date` /
`POSIXct` columns.

If the `herald.sort_keys` attribute is set on `x`, the data is sorted by
those keys before writing.

## Usage

``` r
write_xpt(
  x,
  file,
  version = 5,
  dataset = NULL,
  label = NULL,
  encoding = "wlatin1"
)
```

## Arguments

- x:

  A data frame, or a named list of data frames for multiple members.

- file:

  File path for the output `.xpt` file.

- version:

  Transport format version: `5` (default, FDA standard) or `8` (extended
  names/labels).

- dataset:

  Dataset name (e.g., `"DM"`). Default: the `"dataset_name"` attribute
  of `x` (set by
  [`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md),
  [`read_json()`](https://vthanik.github.io/herald/reference/read_json.md),
  or
  [`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)),
  then the uppercase file stem (`"sdtm/dm.xpt"` -\> `"DM"`), then
  `"DATA"`. V5: max 8 characters, uppercased. V8: max 32 characters.

- label:

  Dataset label. Defaults to `attr(x, "label")` or `""`.

- encoding:

  Character encoding for the output file. Defaults to `"wlatin1"` (SAS
  WLATIN1 = Windows-1252), which converts UTF-8 characters to extended
  ASCII for SAS compatibility. Accepts SAS encoding names (`"wlatin1"`,
  `"latin1"`, `"utf-8"`, `"shift-jis"`) or standard names
  (`"WINDOWS-1252"`, `"ISO-8859-1"`). Set to `NULL` to write bytes as-is
  without conversion.

## Value

`x` invisibly (the input data frame, not the file path).

## Details

### Date/datetime handling

R `Date` columns are converted to SAS date values (days since
1960-01-01) and automatically assigned `format.sas = "DATE9."` unless
the column already has a `format.sas` attribute. Similarly, `POSIXct`
columns are converted to SAS datetime values (seconds since 1960-01-01
00:00:00 UTC) with `format.sas = "DATETIME20."`. The `format.sas`
attribute is written into the XPT NAMESTR header so SAS recognizes the
variable as a date. Informats are not auto-set (matching SAS behaviour);
set `informat.sas` on the column before writing if needed.

### SAS missing values

- Numeric `NA`, `NaN`, `Inf`, `-Inf` are written as SAS missing (`.`).
  `NA` dates and datetimes are also written as SAS missing.

- Character `NA` values are written as blank strings (spaces).

### V5 constraints

Variable names must be at most 8 characters (A-Z, 0-9, underscore only),
character variables at most 200 bytes, labels at most 40 characters. All
names are uppercased.

### V8 extensions

Variable names up to 32 characters with mixed case. Labels up to 256
characters via LABELV8/LABELV9 extension records.

### Character encoding

By default, `write_xpt()` converts UTF-8 character data to WLATIN1
(Windows-1252) before writing. This ensures the XPT file is compatible
with SAS sessions using the default WLATIN1 encoding. For pure ASCII
data, the conversion is a no-op. See
[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md)
for the full encoding reference table.

## References

- SAS V5 transport format specification:
  <https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/movefile/n0167z9rttw8dyn15z1qqe8eiwzf.htm>

- SAS V8 transport format specification:
  <https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/movefile/p0ld1i106e1xm7n16eefi7qgj8m9.htm>

- Full WLATIN1 (Windows-1252) character map:
  <https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP1252.TXT>

- IANA character set registry:
  <https://www.iana.org/assignments/character-sets/character-sets.xhtml>

## See also

[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md)
to read,
[`write_json()`](https://vthanik.github.io/herald/reference/write_json.md),
[`write_parquet()`](https://vthanik.github.io/herald/reference/write_parquet.md),
[`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md)
to convert between formats.

Other io:
[`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md),
[`read_json()`](https://vthanik.github.io/herald/reference/read_json.md),
[`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md),
[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md),
[`write_json()`](https://vthanik.github.io/herald/reference/write_json.md),
[`write_parquet()`](https://vthanik.github.io/herald/reference/write_parquet.md)

## Examples

``` r
dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
dm   <- apply_spec(dm, spec)
tmp  <- tempfile(fileext = ".xpt")
on.exit(unlink(tmp))

# ---- V5 (FDA standard) -- dataset name inferred from variable symbol (dm -> "DM") ----
write_xpt(dm, tmp)
attr(read_xpt(tmp), "dataset_name")   # "DM"
#> [1] "DM"

# ---- V8 (extended names up to 32 chars) ------------------------------
tmp8 <- tempfile(fileext = ".xpt")
on.exit(unlink(tmp8), add = TRUE)
write_xpt(dm, tmp8, version = 8L)

# ---- Explicit dataset name and label overrides -----------------------
tmp3 <- tempfile(fileext = ".xpt")
on.exit(unlink(tmp3), add = TRUE)
write_xpt(dm, tmp3, dataset = "DM", label = "Demographics")
attr(read_xpt(tmp3), "label")
#> [1] "Demographics"

# ---- Plain data frame (no prior apply_spec) -- name from file stem ----
ae <- data.frame(STUDYID = "X", USUBJID = "X-001", stringsAsFactors = FALSE)
tmp_ae <- tempfile(fileext = ".xpt")
on.exit(unlink(tmp_ae), add = TRUE)
write_xpt(ae, tmp_ae, dataset = "AE", label = "Adverse Events")
attr(read_xpt(tmp_ae), "dataset_name")  # "AE"
#> [1] "AE"
```
