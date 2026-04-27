# Write a herald_result as a self-contained HTML report

**\[experimental\]**

Renders a `herald_result` to a single-file, archival-quality HTML
document. All CSS, JavaScript, and data are embedded inline – the file
is suitable for submission packages, inspection, and long-term archiving
without external dependencies. The report includes:

- Header banner with run metadata and finding totals.

- Per-dataset summary table.

- Sortable findings table with rule-id deep links to the source document
  (CDISC Library / Define-XML / SDTM IG).

- Applied rules table with per-rule fired and advisory counts.

## Usage

``` r
write_report_html(x, path, title = NULL, ...)
```

## Arguments

- x:

  A `herald_result` object from
  [`validate()`](https://vthanik.github.io/herald/reference/validate.md).

- path:

  Output file path (should end in `.html`).

- title:

  Document title. Defaults to `"Herald validation <YYYY-MM-DD>"`.

- ...:

  Ignored.

## Value

`path` invisibly.

## See also

[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
to produce a result,
[`write_report_xlsx()`](https://vthanik.github.io/herald/reference/write_report_xlsx.md)
for a spreadsheet output,
[`report()`](https://vthanik.github.io/herald/reference/report.md) to
auto-select format from extension.

Other report:
[`report()`](https://vthanik.github.io/herald/reference/report.md),
[`write_report_json()`](https://vthanik.github.io/herald/reference/write_report_json.md),
[`write_report_xlsx()`](https://vthanik.github.io/herald/reference/write_report_xlsx.md)

## Examples

``` r
ae  <- data.frame(STUDYID = "X", USUBJID = "X-001", stringsAsFactors = FALSE)
r   <- validate(files = ae, rules = character(0), quiet = TRUE)
out <- tempfile(fileext = ".html")
on.exit(unlink(out))
write_report_html(r, out)
file.exists(out)
#> [1] TRUE

# custom title
write_report_html(r, out, title = "PILOT01 SDTM Conformance Report")
```
