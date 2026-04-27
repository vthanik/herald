# Write a Define-XML 2.1 HTML rendering

Generates a self-contained HTML file from a `herald_spec` object that
mirrors the CDISC Define-XML browser view. This is the `define.html`
file that is always co-produced alongside `define.xml` by
[`write_define_xml`](https://vthanik.github.io/herald/reference/write_define_xml.md),
but it can also be written independently.

## Usage

``` r
write_define_html(spec, path, define_xml = NULL)
```

## Arguments

- spec:

  A `herald_spec` object.

- path:

  File path for the output HTML.

- define_xml:

  Ignored. Kept for backwards compatibility.

## Value

The output path, invisibly.

## See also

Other spec:
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md),
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md),
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md),
[`is_herald_spec()`](https://vthanik.github.io/herald/reference/is_herald_spec.md),
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md),
[`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md),
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md)

## Examples

``` r
dm <- readRDS(system.file("extdata", "dm.rds", package = "herald"))

# ---- Minimal spec: dataset label only --------------------------------
spec1 <- as_herald_spec(
  ds_spec  = data.frame(dataset = "DM", label = "Demographics",
                        stringsAsFactors = FALSE),
  var_spec = data.frame(dataset = "DM", variable = "STUDYID",
                        stringsAsFactors = FALSE)
)
out1 <- tempfile(fileext = ".html")
on.exit(unlink(out1))
write_define_html(spec1, out1)
file.exists(out1)
#> [1] TRUE

# ---- Richer spec with variable metadata ------------------------------
spec2 <- as_herald_spec(
  ds_spec  = data.frame(dataset = "DM", label = "Demographics",
                        stringsAsFactors = FALSE),
  var_spec = data.frame(
    dataset   = rep("DM", 2),
    variable  = c("STUDYID", "USUBJID"),
    label     = c("Study Identifier", "Unique Subject Identifier"),
    data_type = c("text", "text"),
    stringsAsFactors = FALSE
  )
)
out2 <- tempfile(fileext = ".html")
on.exit(unlink(out2), add = TRUE)
write_define_html(spec2, out2)

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
out3 <- tempfile(fileext = ".html")
on.exit(unlink(out3), add = TRUE)
write_define_html(spec3, out3)

# ---- Spec built from a parsed Define-XML (read -> render as HTML) ----
xml_tmp <- tempfile(fileext = ".xml")
on.exit(unlink(xml_tmp), add = TRUE)
write_define_xml(spec2, xml_tmp, validate = FALSE)
d <- read_define_xml(xml_tmp)
spec_rt <- as_herald_spec(d$ds_spec, d$var_spec)
out4 <- tempfile(fileext = ".html")
on.exit(unlink(out4), add = TRUE)
write_define_html(spec_rt, out4)
```
