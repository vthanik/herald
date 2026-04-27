# Read a SAS Transport (XPT) file into a data frame

**\[stable\]**

Reads V5 (FDA standard) or V8 (extended) XPT transport files into R data
frames. Pure R implementation – no SAS, no haven, no Java dependency.
Preserves dataset and variable labels, SAS formats, SAS lengths, and
missing-value semantics so the result round-trips through
[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md)
without metadata loss.

## Usage

``` r
read_xpt(file, col_select = NULL, n_max = Inf, encoding = "wlatin1")
```

## Arguments

- file:

  File path to an `.xpt` file.

- col_select:

  Character vector of column names to read. `NULL` (default) reads all
  columns.

- n_max:

  Maximum number of rows to read. `Inf` (default) reads all rows.

- encoding:

  Character encoding of the XPT file. Defaults to `"wlatin1"` (SAS
  WLATIN1 = Windows-1252), which is the standard encoding for SAS on
  Windows and a superset of 7-bit ASCII. Accepts SAS encoding names
  (`"wlatin1"`, `"latin1"`, `"utf-8"`, `"shift-jis"`), aliases
  (`"wlt1"`, `"sjis"`), or standard names (`"WINDOWS-1252"`,
  `"ISO-8859-1"`). Set to `NULL` to pass bytes through without
  conversion.

## Value

A data frame for single-member files (with `attr(df, "label")`,
`attr(df, "dataset_name")`, and per-column `"label"`, `"format.sas"`,
`"sas.length"`, `"xpt_type"` attributes populated from the XPT header),
or a named list of data frames for multi-member files.

## Details

### Date/datetime conversion

Numeric columns with a SAS date or datetime format are automatically
converted to R `Date` or `POSIXct` classes using the SAS epoch
(1960-01-01). The conversion is based on the `format.sas` attribute
stored in the XPT file header (NAMESTR record).

Date formats (e.g. `DATE9.`, `MMDDYY10.`, `YYMMDD10.`, `E8601DA.`)
produce R `Date` values. Datetime formats (e.g. `DATETIME20.`,
`E8601DT.`, `DATEAMPM.`) produce R `POSIXct` values in UTC.

The `format.sas` attribute is preserved on converted columns for
round-trip fidelity with
[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md).

### SAS missing values

- Numeric SAS missing values (`.`, `.A`-`.Z`, `._`) are read as
  `NA_real_`. For date/datetime columns these become `NA` dates.

- Character blanks (all spaces) are read as `NA_character_`.

### Attributes

- Column labels are stored as the `"label"` attribute on each column.

- SAS formats are stored as the `"format.sas"` attribute on each column.

- The dataset label is stored as the `"label"` attribute on the data
  frame.

### Character encoding

XPT files contain no encoding metadata. SAS on Windows defaults to
WLATIN1 (Windows-1252), an extended ASCII encoding that is a superset of
7-bit ASCII. By default, `read_xpt()` converts WLATIN1 bytes to UTF-8.
This is a no-op for pure ASCII files (all bytes \< 0x80 are identical)
and correctly handles extended characters commonly found in clinical
data.

Supported SAS encoding names:

|           |       |               |
|-----------|-------|---------------|
| SAS name  | Alias | Standard name |
| wlatin1   | wlt1  | WINDOWS-1252  |
| latin1    | lat1  | ISO-8859-1    |
| utf-8     | utf8  | UTF-8         |
| us-ascii  | ansi  | US-ASCII      |
| wlatin2   | wlt2  | WINDOWS-1250  |
| wcyrillic | wcyr  | WINDOWS-1251  |
| shift-jis | sjis  | CP932         |
| euc-jp    | jeuc  | EUC-JP        |

WLATIN1 extended ASCII characters commonly found in clinical data:

|      |         |                      |
|------|---------|----------------------|
| Byte | Unicode | Description          |
| 0x91 | U+2018  | Left single quote    |
| 0x92 | U+2019  | Right single quote   |
| 0x93 | U+201C  | Left double quote    |
| 0x94 | U+201D  | Right double quote   |
| 0x96 | U+2013  | En dash              |
| 0x97 | U+2014  | Em dash              |
| 0x85 | U+2026  | Horizontal ellipsis  |
| 0x99 | U+2122  | Trademark            |
| 0xA9 | U+00A9  | Copyright            |
| 0xAE | U+00AE  | Registered           |
| 0xB0 | U+00B0  | Degree sign          |
| 0xB1 | U+00B1  | Plus-minus           |
| 0xB5 | U+00B5  | Micro sign           |
| 0xD7 | U+00D7  | Multiplication sign  |
| 0xE9 | U+00E9  | Latin small e acute  |
| 0xF1 | U+00F1  | Latin small n tilde  |
| 0xFC | U+00FC  | Latin small u umlaut |

See the full WLATIN1 map at
<https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP1252.TXT>.

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

[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md)
to write,
[`read_json()`](https://vthanik.github.io/herald/reference/read_json.md),
[`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md),
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
to stamp CDISC attributes after reading.

Other io:
[`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md),
[`read_json()`](https://vthanik.github.io/herald/reference/read_json.md),
[`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md),
[`write_json()`](https://vthanik.github.io/herald/reference/write_json.md),
[`write_parquet()`](https://vthanik.github.io/herald/reference/write_parquet.md),
[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md)

## Examples

``` r
dm  <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
dm  <- apply_spec(dm, spec)
tmp <- tempfile(fileext = ".xpt")
on.exit(unlink(tmp))
write_xpt(dm, tmp)

# ---- Full read -- all columns and all rows ---------------------------
dm2 <- read_xpt(tmp)
attr(dm2, "label")
#> [1] "Demographics"
attr(dm2, "dataset_name")
#> [1] "DM"
attr(dm2$USUBJID, "label")
#> [1] "Unique Subject Identifier"

# ---- Select specific columns only (faster for large files) -----------
dm3 <- read_xpt(tmp, col_select = c("STUDYID", "USUBJID", "AGE"))
names(dm3)
#> [1] "STUDYID" "USUBJID" "AGE"    

# ---- Read only the first 10 rows (useful for previewing) -------------
dm4 <- read_xpt(tmp, n_max = 10)
nrow(dm4)
#> [1] 10

# ---- Override character encoding (e.g. Latin-1 encoded legacy files) ----
dm5 <- read_xpt(tmp, encoding = "latin1")
attr(dm5$USUBJID, "label")
#> [1] "Unique Subject Identifier"
```
