# Write a herald_result as canonical JSON

**\[experimental\]**

Serialises a `herald_result` to a UTF-8 JSON document with a stable key
order. Designed as the machine-readable artifact for CI pipelines,
diffing between runs, and programmatic post-processing:

- Top-level keys: `herald_version`, `timestamp`, `duration_secs`,
  `profile`, `config_hash`, `rules_applied`, `rules_total`,
  `datasets_checked`, `counts`, `findings`, `dataset_meta`,
  `rule_catalog`, `op_errors`.

- `findings` is a list of row objects (one entry per finding).

- `NA` values become `null`.

Requires the `jsonlite` package.

## Usage

``` r
write_report_json(x, path, pretty = TRUE, ...)
```

## Arguments

- x:

  A `herald_result` object from
  [`validate()`](https://vthanik.github.io/herald/reference/validate.md).

- path:

  Output file path (should end in `.json`).

- pretty:

  Logical. Pretty-print with two-space indent. Default `TRUE`.

- ...:

  Ignored.

## Value

`path` invisibly.

## See also

[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
to produce a result,
[`write_report_html()`](https://vthanik.github.io/herald/reference/write_report_html.md),
[`write_report_xlsx()`](https://vthanik.github.io/herald/reference/write_report_xlsx.md),
[`report()`](https://vthanik.github.io/herald/reference/report.md) to
auto-select format.

Other report:
[`report()`](https://vthanik.github.io/herald/reference/report.md),
[`write_report_html()`](https://vthanik.github.io/herald/reference/write_report_html.md),
[`write_report_xlsx()`](https://vthanik.github.io/herald/reference/write_report_xlsx.md)

## Examples

``` r
ae  <- data.frame(STUDYID = "X", USUBJID = "X-001", stringsAsFactors = FALSE)
r   <- validate(files = ae, rules = character(0), quiet = TRUE)
out <- tempfile(fileext = ".json")
on.exit(unlink(out))
write_report_json(r, out)
file.exists(out)
#> [1] TRUE

# compact output for CI pipelines
write_report_json(r, out, pretty = FALSE)
```
