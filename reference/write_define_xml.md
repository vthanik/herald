# Write a Define-XML 2.1 file from a herald specification

Generates a valid Define-XML 2.1 document from a `herald_spec` object
and writes it to disk. The output includes full namespace declarations
for ODM 1.3, Define-XML 2.1 extensions, and Analysis Results Metadata
(ARM) 1.0.

This is the inverse of
[`read_define_xml`](https://vthanik.github.io/herald/reference/read_define_xml.md):
a spec created from any source (programmatic or parsed Define-XML) can
be written out as Define-XML 2.1.

## Usage

``` r
write_define_xml(spec, path, stylesheet = TRUE, validate = TRUE)
```

## Arguments

- spec:

  A `herald_spec` object. At minimum, `ds_spec` and `var_spec` must be
  populated.

- path:

  File path for the output XML. Should end in `.xml`.

- stylesheet:

  Logical. Kept for backwards compatibility; ignored. A stylesheet
  processing instruction and `define2-1.xsl` are always copied alongside
  the output file.

- validate:

  Logical. Run DD0001–DD0085 Define-XML rules against the spec before
  writing? Default `TRUE`. Findings are reported as warnings; generation
  is never blocked.

## Value

The output path, invisibly. The validation result (if run) is attached
as the `"validation"` attribute. `define.html` and `define2-1.xsl` are
always written to the same directory.

## See also

[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md)
for the inverse operation.

Other spec:
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md),
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md),
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md),
[`is_herald_spec()`](https://vthanik.github.io/herald/reference/is_herald_spec.md),
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md),
[`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md),
[`write_define_html()`](https://vthanik.github.io/herald/reference/write_define_html.md)

## Examples

``` r
dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))

# ---- Minimal spec with one variable -- skip pre-flight validation ----
spec1 <- as_herald_spec(
  ds_spec  = data.frame(dataset = "DM", label = "Demographics",
                        stringsAsFactors = FALSE),
  var_spec = data.frame(dataset = "DM", variable = "STUDYID",
                        stringsAsFactors = FALSE)
)
tmp1 <- tempfile(fileext = ".xml")
on.exit(unlink(tmp1))
write_define_xml(spec1, tmp1, validate = FALSE)

# ---- With var_spec: variable labels, types, and lengths --------------
spec2 <- as_herald_spec(
  ds_spec  = data.frame(dataset = "DM", label = "Demographics",
                        stringsAsFactors = FALSE),
  var_spec = data.frame(
    dataset   = rep("DM", 2),
    variable  = c("STUDYID", "USUBJID"),
    label     = c("Study Identifier", "Unique Subject Identifier"),
    data_type = c("text", "text"),
    length    = c("12", "40"),
    stringsAsFactors = FALSE
  )
)
tmp2 <- tempfile(fileext = ".xml")
on.exit(unlink(tmp2), add = TRUE)
write_define_xml(spec2, tmp2, validate = FALSE)

# ---- Multi-dataset spec ----------------------------------------------
adsl <- readRDS(system.file("extdata", "adsl.rds", package = "herald"))
spec3 <- as_herald_spec(
  ds_spec  = data.frame(
    dataset = c("DM", "ADSL"),
    label   = c("Demographics", "Subject-Level Analysis Dataset"),
    stringsAsFactors = FALSE
  ),
  var_spec = data.frame(
    dataset  = c(rep("DM", ncol(dm)), rep("ADSL", ncol(adsl))),
    variable = c(names(dm), names(adsl)),
    stringsAsFactors = FALSE
  )
)
tmp3 <- tempfile(fileext = ".xml")
on.exit(unlink(tmp3), add = TRUE)
write_define_xml(spec3, tmp3, validate = FALSE)

# ---- Round-trip: write then read back --------------------------------
tmp4 <- tempfile(fileext = ".xml")
on.exit(unlink(tmp4), add = TRUE)
write_define_xml(spec2, tmp4, validate = FALSE)
d <- read_define_xml(tmp4)
d$ds_spec
#>   dataset        label
#> 1      DM Demographics
d$var_spec[, c("dataset", "variable", "label")]
#>               dataset variable                     label
#> IT.DM.STUDYID      DM  STUDYID          Study Identifier
#> IT.DM.USUBJID      DM  USUBJID Unique Subject Identifier
```
