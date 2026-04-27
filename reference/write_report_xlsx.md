# Write a herald_result as a five-sheet XLSX workbook

**\[experimental\]**

Renders a `herald_result` to an Excel workbook structured for sponsor
review and regulatory submission. The workbook contains five sheets:

- `summary`:

  Key/value run metadata (version, timestamp, finding counts).

- `findings`:

  Full findings data frame, one row per finding.

- `datasets`:

  Per-dataset row/column counts and finding tallies.

- `rules`:

  Applied rule catalog with per-rule fired and advisory counts plus
  source URLs.

- `spec_validation`:

  Findings scoped to Define-XML / spec rules only.

Requires the `openxlsx2` package.

## Usage

``` r
write_report_xlsx(x, path, ...)
```

## Arguments

- x:

  A `herald_result` object from
  [`validate()`](https://vthanik.github.io/herald/reference/validate.md).

- path:

  Output file path (should end in `.xlsx`).

- ...:

  Ignored.

## Value

`path` invisibly.

## See also

[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
to produce a result,
[`write_report_html()`](https://vthanik.github.io/herald/reference/write_report_html.md)
for a self-contained HTML report,
[`report()`](https://vthanik.github.io/herald/reference/report.md) to
auto-select format.

Other report:
[`report()`](https://vthanik.github.io/herald/reference/report.md),
[`write_report_html()`](https://vthanik.github.io/herald/reference/write_report_html.md),
[`write_report_json()`](https://vthanik.github.io/herald/reference/write_report_json.md)

## Examples

``` r
ae  <- data.frame(STUDYID = "X", USUBJID = "X-001", stringsAsFactors = FALSE)
r   <- validate(files = ae, rules = character(0), quiet = TRUE)
out <- tempfile(fileext = ".xlsx")
on.exit(unlink(out))
write_report_xlsx(r, out)
file.exists(out)
#> [1] TRUE

# inspect sheet names
openxlsx2::wb_get_sheet_names(openxlsx2::wb_load(out))
#>    summary   findings   datasets      rules 
#>  "summary" "findings" "datasets"    "rules" 
```
