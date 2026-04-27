# Define-XML 2.1

`herald` has a first-class Define-XML path:

    herald_spec -> write_define_xml() -> read_define_xml() -> validate()

The writer supports Define-XML 2.1 structures such as study metadata,
datasets, variables, codelists, methods, comments, documents, and ADaM
ARM tables.

## Build a rich spec

``` r
spec <- herald_spec(
  study = data.frame(
    attribute = c("StudyName", "StudyDescription", "ProtocolName"),
    value     = c("PILOT01", "Pilot study", "PILOT01"),
    stringsAsFactors = FALSE
  ),
  ds_spec = data.frame(
    dataset = c("DM", "AE"),
    label   = c("Demographics", "Adverse Events"),
    class   = c("SPECIAL PURPOSE", "EVENTS"),
    stringsAsFactors = FALSE
  ),
  var_spec = data.frame(
    dataset   = c("DM", "DM", "DM", "AE", "AE", "AE"),
    variable  = c("STUDYID", "USUBJID", "SEX", "STUDYID", "USUBJID", "AETERM"),
    label     = c("Study Identifier", "Unique Subject Identifier", "Sex",
                  "Study Identifier", "Unique Subject Identifier", "Reported Term"),
    data_type = c("text", "text", "text", "text", "text", "text"),
    length    = c("12", "40", "1", "12", "40", "200"),
    stringsAsFactors = FALSE
  ),
  codelist = data.frame(
    codelist_id   = c("CL.SEX", "CL.SEX"),
    name          = c("Sex", "Sex"),
    data_type     = c("text", "text"),
    term          = c("M", "F"),
    decoded_value = c("Male", "Female"),
    stringsAsFactors = FALSE
  ),
  methods = data.frame(
    method_id   = "MT.AGE",
    name        = "Derive AGE",
    type        = "Computation",
    description = "AGE is derived from reference start date and birth date.",
    stringsAsFactors = FALSE
  )
)

spec
#> <herald_spec>
#>   2 datasets, 6 variables
```

## Write XML

Use `validate = FALSE` while drafting incomplete metadata. Turn
validation on when the spec is ready for release.

``` r
define_dir <- file.path(tempdir(), "herald-define")
dir.create(define_dir, showWarnings = FALSE)

xml_path <- file.path(define_dir, "define.xml")
write_define_xml(spec, xml_path, validate = FALSE)

file.exists(xml_path)
#> [1] TRUE
readLines(xml_path, n = 5)
#> [1] "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"                                                                                                                                                                                                                                                                                                                                                               
#> [2] "<?xml-stylesheet type=\"text/xsl\" href=\"define2-1.xsl\"?>"                                                                                                                                                                                                                                                                                                                                              
#> [3] "<ODM xmlns=\"http://www.cdisc.org/ns/odm/v1.3\" xmlns:def=\"http://www.cdisc.org/ns/def/v2.1\" xmlns:arm=\"http://www.cdisc.org/ns/arm/v1.0\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" Context=\"Submission\" FileOID=\"DEF.HERALD\" FileType=\"Snapshot\" CreationDateTime=\"2026-04-27T09:23:20\" Originator=\"herald\" SourceSystem=\"herald\" SourceSystemVersion=\"0.1.0\" ODMVersion=\"1.3.2\">"
#> [4] "  <Study OID=\"S.HERALD\">"                                                                                                                                                                                                                                                                                                                                                                               
#> [5] "    <GlobalVariables>"
```

## Read XML back

[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md)
returns a `herald_define` object. The object exposes the same data-frame
slots used by validation and Define-XML dependent rules.

``` r
define <- read_define_xml(xml_path)

define
#> <herald_define>
#>   2 datasets, 6 variables, 0 key-var mappings
define$ds_spec[, c("dataset", "label")]
#>   dataset          label
#> 1      DM   Demographics
#> 2      AE Adverse Events
define$var_spec[, c("dataset", "variable", "label")]
#>               dataset variable                     label
#> IT.DM.STUDYID      DM  STUDYID          Study Identifier
#> IT.DM.USUBJID      DM  USUBJID Unique Subject Identifier
#> IT.DM.SEX          DM      SEX                       Sex
#> IT.AE.STUDYID      AE  STUDYID          Study Identifier
#> IT.AE.USUBJID      AE  USUBJID Unique Subject Identifier
#> IT.AE.AETERM       AE   AETERM             Reported Term
```

## Render reviewer HTML

[`write_define_html()`](https://vthanik.github.io/herald/reference/write_define_html.md)
renders a reviewer-friendly HTML page from the spec.

``` r
html_path <- file.path(define_dir, "define.html")
write_define_html(spec, html_path, define_xml = xml_path)

file.exists(html_path)
#> [1] TRUE
```

## Validate with Define-XML context

Pass the parsed Define-XML object to
[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
when rule execution needs metadata that is not present in datasets
alone.

``` r
dm <- readRDS(extdata("dm.rds"))
dm <- apply_spec(dm, spec)

result <- validate(
  files  = list(dm, define = define),
  define = define,
  rules  = character(0),
  quiet  = TRUE
)

result$datasets_checked
#> [1] "DM"                        "Define_Codelist_Metadata" 
#> [3] "Define_Dataset_Metadata"   "Define_MethodDef_Metadata"
#> [5] "Define_Study_Metadata"     "Define_Variable_Metadata"
```

## Practical guidance

Keep Define-XML authoring in the same pipeline as dataset writing:

1.  Build or read the `herald_spec`.
2.  Apply the spec to datasets.
3.  Write XPT or Dataset-JSON.
4.  Write Define-XML and HTML.
5.  Read the written Define-XML back.
6.  Validate the submitted files with the parsed Define-XML object.

This catches drift between the metadata source and the actual submission
artifacts before reviewers see it.
