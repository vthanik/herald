# Pilot ADaM specification (herald_spec)

A `herald_spec` object covering **12 ADaM datasets** and **509 variable
definitions** from the CDISC pilot study, derived from the ADaM
`define.xml` via
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md) +
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md).
Pass to
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
before running ADaM-IG validation to enable label-, length-, and
codelist-dependent rules.

## Usage

``` r
adam_spec
```

## Format

A `herald_spec` (S3 list, length 2) with elements `ds_spec` (12 rows, 2
columns) and `var_spec` (509 rows, 10 columns).

## Source

CDISC SDTM/ADaM Pilot Submission Package (public domain), loaded with
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md).

## Details

### Object structure

A `herald_spec` is a length-2 list with class
`c("herald_spec", "list")`:

- `$ds_spec` – 12 rows x 2 columns (`dataset`, `label`).

- `$var_spec` – 509 rows x 10 columns.

### Datasets covered (`ds_spec`)

All 12 ADaM datasets from the pilot:

|           |       |        |                                                       |
|-----------|-------|--------|-------------------------------------------------------|
| Dataset   | Class | n vars | Label                                                 |
| `ADADAS`  | BDS   | 40     | ADAS-Cog Analysis                                     |
| `ADAE`    | OCCDS | 55     | Adverse Events Analysis Dataset                       |
| `ADCIBC`  | BDS   | 36     | CIBIC+ Analysis                                       |
| `ADLBC`   | BDS   | 46     | Analysis Dataset Lab Blood Chemistry                  |
| `ADLBCPV` | BDS   | 46     | Analysis Dataset Lab Blood Chemistry (Previous Visit) |
| `ADLBH`   | BDS   | 46     | Analysis Dataset Lab Hematology                       |
| `ADLBHPV` | BDS   | 46     | Analysis Dataset Lab Hematology (Previous Visit)      |
| `ADLBHY`  | BDS   | 43     | Analysis Dataset Lab Hy's Law                         |
| `ADNPIX`  | BDS   | 41     | NPI-X Item Analysis Data                              |
| `ADSL`    | ADSL  | 49     | Subject-Level Analysis                                |
| `ADTTE`   | TTE   | 26     | AE Time To 1st Derm. Event Analysis                   |
| `ADVS`    | BDS   | 35     | Vital Signs Analysis Dataset                          |

(Class column reflects ADaM IG structure; assigned by herald via
[`detect_adam_class()`](https://vthanik.github.io/herald/reference/detect_adam_class.md).)

### Variable metadata columns (`var_spec`)

All 10 columns shipped on `var_spec`:

- `dataset`:

  ADaM dataset name (e.g. `"ADSL"`).

- `variable`:

  Variable name (e.g. `"TRT01P"`).

- `label`:

  ADaM variable label (e.g. `"Planned Treatment for Period 01"`).

- `data_type`:

  One of `"text"`, `"integer"`, `"float"`, `"date"`, `"datetime"`.

- `length`:

  Storage length as a string.

- `origin`:

  `"Derived"` for most ADaM variables; `"Predecessor"` for variables
  sourced from SDTM (with the source variable in `format`).

- `codelist`:

  Codelist OID when controlled.

- `mandatory`:

  `"Yes"` / `"No"` – ADaM IG required flag.

- `order`:

  Variable order as a string.

- `format`:

  Display format or predecessor reference.

## See also

[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md),
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md),
[`validate()`](https://vthanik.github.io/herald/reference/validate.md),
[`detect_adam_class()`](https://vthanik.github.io/herald/reference/detect_adam_class.md),
[sdtm_spec](https://vthanik.github.io/herald/reference/sdtm_spec.md).

Other pilot-data:
[`adae`](https://vthanik.github.io/herald/reference/adae.md),
[`adsl`](https://vthanik.github.io/herald/reference/adsl.md),
[`advs`](https://vthanik.github.io/herald/reference/advs.md),
[`dm`](https://vthanik.github.io/herald/reference/dm.md),
[`pilot-data`](https://vthanik.github.io/herald/reference/pilot-data.md),
[`sdtm_spec`](https://vthanik.github.io/herald/reference/sdtm_spec.md)

## Examples

``` r
is_herald_spec(adam_spec)
#> [1] TRUE

# Datasets covered
adam_spec$ds_spec
#>    dataset                                                 label
#> 1   ADADAS                                     ADAS-Cog Analysis
#> 2     ADAE                       Adverse Events Analysis Dataset
#> 3   ADCIBC                                       CIBIC+ Analysis
#> 4    ADLBC                  Analysis Dataset Lab Blood Chemistry
#> 5  ADLBCPV Analysis Dataset Lab Blood Chemistry (Previous Visit)
#> 6    ADLBH                       Analysis Dataset Lab Hematology
#> 7  ADLBHPV      Analysis Dataset Lab Hematology (Previous Visit)
#> 8   ADLBHY                         Analysis Dataset Lab Hy's Law
#> 9   ADNPIX                              NPI-X Item Analysis Data
#> 10    ADSL                                Subject-Level Analysis
#> 11   ADTTE                   AE Time To 1st Derm. Event Analysis
#> 12    ADVS                          Vital Signs Analysis Dataset

# Total variable definitions
nrow(adam_spec$var_spec)
#> [1] 509

# All metadata columns shipped on var_spec
names(adam_spec$var_spec)
#>  [1] "dataset"   "variable"  "label"     "data_type" "length"   
#>  [6] "origin"    "codelist"  "mandatory" "order"     "format"   

# Variable count per dataset
table(adam_spec$var_spec$dataset)
#> 
#>  ADADAS    ADAE  ADCIBC   ADLBC ADLBCPV   ADLBH ADLBHPV  ADLBHY 
#>      40      55      36      46      46      46      46      43 
#>  ADNPIX    ADSL   ADTTE    ADVS 
#>      41      49      26      35 

# ADSL variables that are population flags
adsl_vars <- adam_spec$var_spec[adam_spec$var_spec$dataset == "ADSL", ]
adsl_vars[grepl("FL$", adsl_vars$variable), c("variable", "label")]
#>                  variable                                  label
#> IT.ADSL.SAFFL       SAFFL                 Safety Population Flag
#> IT.ADSL.ITTFL       ITTFL        Intent-To-Treat Population Flag
#> IT.ADSL.EFFFL       EFFFL               Efficacy Population Flag
#> IT.ADSL.COMP8FL   COMP8FL   Completers of Week 8 Population Flag
#> IT.ADSL.COMP16FL COMP16FL  Completers of Week 16 Population Flag
#> IT.ADSL.COMP24FL COMP24FL  Completers of Week 24 Population Flag
#> IT.ADSL.DISCONFL DISCONFL Did the Subject Discontinue the Study?
#> IT.ADSL.DSRAEFL   DSRAEFL                Discontinued due to AE?
#> IT.ADSL.DTHFL       DTHFL                          Subject Died?

# \donttest{
adsl_stamped <- apply_spec(adsl, adam_spec)
r <- validate(files = adsl_stamped, quiet = TRUE)
# }
```
