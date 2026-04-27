# Read a Define-XML 2.1 file

**\[stable\]**

Parses a Define-XML 2.1 file and returns a `herald_define` object
carrying datasets, variables, codelists, methods, comments, ARM
metadata, sponsor-defined key variables, and the LOINC dictionary
version declared in `MetaDataVersion`. Requires the `xml2` package.

## Usage

``` r
read_define_xml(path, call = rlang::caller_env())
```

## Arguments

- path:

  Path to the Define-XML file.

- call:

  Caller environment for error reporting.

## Value

A `herald_define` S3 object (inherits from `list`).

## Element coverage

herald round-trips the following Define-XML 2.1 elements through
`read_define_xml()` -\>
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md)
-\>
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md):

- `ODM` / `Study` / `MetaDataVersion` – study slot, including
  `StudyName`, `ProtocolName`, and `def:Standards`.

- `ItemGroupDef` / `def:Class` – per-dataset metadata into `ds_spec`,
  including SDTM domain, ADaM class, repeating flag, purpose, key
  variables.

- `ItemDef` / `ItemRef` – per-variable metadata into `var_spec`,
  including type, length, label, ordering, mandatory flag, codelist ref,
  method ref.

- `def:ValueListDef` / value-level conditions – value-level slot.

- `CodeList` / `EnumeratedItem` / `def:CodeListItem` – codelist slot
  with coded/decoded pairs and extended values.

- `MethodDef`, `def:CommentDef`, `def:leaf` – methods, comments,
  document slots.

- `arm:AnalysisDisplay` / `arm:AnalysisResult` – ARM displays and
  results slots when present.

Elements outside this set are not promoted to the in-memory object but
are preserved verbatim where possible by
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md).

## See also

Other spec:
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md),
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md),
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md),
[`is_herald_spec()`](https://vthanik.github.io/herald/reference/is_herald_spec.md),
[`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md),
[`write_define_html()`](https://vthanik.github.io/herald/reference/write_define_html.md),
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md)

## Examples

``` r
tmp <- tempfile(fileext = ".xml")
on.exit(unlink(tmp))
writeLines(c(
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
  '     xmlns:def="http://www.cdisc.org/ns/def/v2.1">',
  '  <Study OID="S.TEST">',
  '    <GlobalVariables>',
  '      <StudyName>PILOT01</StudyName>',
  '    </GlobalVariables>',
  '    <MetaDataVersion OID="MDV.1" Name="MDV1">',
  '      <ItemGroupDef OID="IG.DM" Name="DM" Repeating="No">',
  '        <Description>',
  '          <TranslatedText>Demographics</TranslatedText>',
  '        </Description>',
  '      </ItemGroupDef>',
  '    </MetaDataVersion>',
  '  </Study>',
  '</ODM>'
), tmp)

# ---- Parse and inspect dataset metadata ------------------------------
d <- read_define_xml(tmp)
d$ds_spec           # data frame: dataset, label
#>   dataset        label
#> 1      DM Demographics
d$var_spec          # data frame: dataset, variable, label, data_type, ...
#>  [1] dataset   variable  label     data_type length    origin   
#>  [7] codelist  mandatory order     format   
#> <0 rows> (or 0-length row.names)

# ---- Inspect study-level metadata ------------------------------------
d$study             # attribute/value pairs (StudyName, etc.)
#>   attribute   value
#> 1 StudyName PILOT01

# ---- Convert to herald_spec for apply_spec / write_define_xml round-trips ----
spec <- as_herald_spec(d$ds_spec, d$var_spec)
is_herald_spec(spec)
#> [1] TRUE

# ---- Pass directly to validate() for Define-XML dependent rules ------
r <- validate(
  files  = list(DM = data.frame(STUDYID = "X", stringsAsFactors = FALSE)),
  define = d,
  quiet  = TRUE
)
r$datasets_checked
#> [1] "DM"                      "Define_Dataset_Metadata"
#> [3] "Define_Study_Metadata"  
```
