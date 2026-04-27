# Write a herald_result to disk in any supported format

**\[stable\]**

Single-function entry point for writing validation results. `report()`
inspects the path extension (or the `format` override) and delegates to
the matching writer:

- `"html"` – self-contained archival HTML
  ([`write_report_html()`](https://vthanik.github.io/herald/reference/write_report_html.md)).

- `"xlsx"` – five-sheet workbook for sponsor review
  ([`write_report_xlsx()`](https://vthanik.github.io/herald/reference/write_report_xlsx.md)).

- `"json"` – machine-readable CI artifact
  ([`write_report_json()`](https://vthanik.github.io/herald/reference/write_report_json.md)).

## Usage

``` r
report(x, path, format = NULL, ...)
```

## Arguments

- x:

  A `herald_result` object from
  [`validate()`](https://vthanik.github.io/herald/reference/validate.md).

- path:

  Output file path. The extension (`.html`, `.xlsx`, `.json`) determines
  the format when `format` is not supplied.

- format:

  One of `"html"`, `"xlsx"`, `"json"`. Defaults to the extension of
  `path`.

- ...:

  Passed to the underlying writer.

## Value

`path` invisibly.

## Extension dispatch matrix

|                   |                                                                                          |                                    |
|-------------------|------------------------------------------------------------------------------------------|------------------------------------|
| Path / `format`   | Writer                                                                                   | Use case                           |
| `*.html` / "html" | [`write_report_html()`](https://vthanik.github.io/herald/reference/write_report_html.md) | Submission archive, sponsor review |
| `*.xlsx` / "xlsx" | [`write_report_xlsx()`](https://vthanik.github.io/herald/reference/write_report_xlsx.md) | Sponsor / regulator spreadsheet    |
| `*.json` / "json" | [`write_report_json()`](https://vthanik.github.io/herald/reference/write_report_json.md) | CI diff artifact, programmatic use |

When `format` is supplied it wins; otherwise the extension is parsed
from `path`. Unknown extensions raise an input error. The
`herald_result` is rendered without mutation – you can call `report()`
repeatedly with different paths.

## See also

[`write_report_html()`](https://vthanik.github.io/herald/reference/write_report_html.md),
[`write_report_xlsx()`](https://vthanik.github.io/herald/reference/write_report_xlsx.md),
[`write_report_json()`](https://vthanik.github.io/herald/reference/write_report_json.md).

Other report:
[`write_report_html()`](https://vthanik.github.io/herald/reference/write_report_html.md),
[`write_report_json()`](https://vthanik.github.io/herald/reference/write_report_json.md),
[`write_report_xlsx()`](https://vthanik.github.io/herald/reference/write_report_xlsx.md)

## Examples

``` r
ae   <- data.frame(STUDYID = "X", USUBJID = "X-001", stringsAsFactors = FALSE)
r    <- validate(files = ae, rules = character(0), quiet = TRUE)
out  <- tempfile(fileext = ".json")
on.exit(unlink(out))
report(r, out)        # format inferred from extension
file.exists(out)
#> [1] TRUE

# HTML
out2 <- tempfile(fileext = ".html")
on.exit(unlink(out2), add = TRUE)
report(r, out2)

# XLSX (requires openxlsx2)
if (requireNamespace("openxlsx2", quietly = TRUE)) {
  out3 <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out3), add = TRUE)
  report(r, out3)
}
```
