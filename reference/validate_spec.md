# Validate a herald_spec for Define-XML completeness

Runs the built-in spec-validation rules (standard: `herald-spec`)
against the slots of `spec`. If any issues are found a detailed HTML
report is written to `report`, opened in the IDE viewer, and an error is
raised.

## Usage

``` r
validate_spec(spec, report = NULL, view = TRUE)
```

## Arguments

- spec:

  A `herald_spec` object from
  [`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md)
  or
  [`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md).

- report:

  File path for the HTML report. Defaults to a temporary file. Ignored
  when there are no issues.

- view:

  Logical. If `TRUE` (default) and issues are found, the report is
  opened in the IDE viewer pane before aborting.

## Value

Invisibly, when the spec is clean. Otherwise an error of class
`herald_error_validation` is raised.

## See also

Other spec:
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md),
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md),
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md),
[`is_herald_spec()`](https://vthanik.github.io/herald/reference/is_herald_spec.md),
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md),
[`write_define_html()`](https://vthanik.github.io/herald/reference/write_define_html.md),
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md)

## Examples

``` r
# ---- Valid spec -- returns invisibly (no issues found) ---------------
spec_ok <- as_herald_spec(
  ds_spec = data.frame(
    dataset = "DM",
    label   = "Demographics",
    stringsAsFactors = FALSE
  )
)
invisible(validate_spec(spec_ok))   # returns NULL invisibly

# ---- Suppress the viewer for automated pipelines ---------------------
invisible(validate_spec(spec_ok, view = FALSE))

# ---- Send the HTML report to a known path (not a tempfile) -----------
report_path <- tempfile(fileext = ".html")
on.exit(unlink(report_path))
invisible(validate_spec(spec_ok, report = report_path, view = FALSE))
file.exists(report_path)   # FALSE -- file is only written when issues exist
#> [1] FALSE

# ---- Invalid spec triggers an error (catch it for demonstration) -----
spec_bad <- as_herald_spec(
  ds_spec = data.frame(dataset = "DM", stringsAsFactors = FALSE)
)
tryCatch(
  validate_spec(spec_bad, view = FALSE),
  herald_error_validation = function(e) conditionMessage(e)
)
```
