# Pilot SDTM specification (herald_spec)

A `herald_spec` object covering **31 SDTM datasets** and **747 variable
definitions** from the CDISC pilot study, derived from the pilot
`define.xml` via
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md) +
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md).
Pass to
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
before validating SDTM datasets to activate label-, length-, and
codelist-dependent rules.

## Usage

``` r
sdtm_spec
```

## Format

A `herald_spec` (S3 list, length 2) with elements `ds_spec` (31 rows, 2
columns) and `var_spec` (747 rows, 10 columns).

## Source

CDISC SDTM/ADaM Pilot Submission Package (public domain), loaded with
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md).

## Details

### Object structure

A `herald_spec` is a length-2 list with class
`c("herald_spec", "list")`:

- `$ds_spec` – 31 rows x 2 columns (`dataset`, `label`).

- `$var_spec` – 747 rows x 10 columns. Every variable across every
  dataset.

### Datasets covered (`ds_spec`)

All 31 SDTM datasets from the pilot:

|                            |                                                                                                                 |
|----------------------------|-----------------------------------------------------------------------------------------------------------------|
| Group                      | Datasets                                                                                                        |
| Trial design               | `TA`, `TE`, `TI`, `TS`, `TV`                                                                                    |
| Demographics / disposition | `DM`, `DS`, `MH`, `SC`, `SE`, `SV`                                                                              |
| Interventions              | `CM`, `EX`                                                                                                      |
| Events                     | `AE`                                                                                                            |
| Findings                   | `LBCH`, `LBHE`, `LBUR` (split lab), `VS`, `QSCO`, `QSDA`, `QSGI`, `QSHI`, `QSMM`, `QSNI` (split questionnaires) |
| Special-purpose            | `RELREC`                                                                                                        |
| Supplemental qualifiers    | `SUPPAE`, `SUPPDM`, `SUPPDS`, `SUPPLBCH`, `SUPPLBHE`, `SUPPLBUR`                                                |

### Variable metadata columns (`var_spec`)

All 10 columns shipped on `var_spec`:

- `dataset`:

  Dataset name the variable belongs to (e.g. `"DM"`).

- `variable`:

  Variable name (e.g. `"USUBJID"`).

- `label`:

  CDISC SDTM variable label (e.g. `"Unique Subject Identifier"`).

- `data_type`:

  One of `"text"`, `"integer"`, `"float"`, `"date"`, `"datetime"`,
  `"time"`, `"partial_date"`.

- `length`:

  Storage length as a string (numeric for `text`, `"8"` for numerics).

- `origin`:

  Variable origin – `"CRF"`, `"Assigned"`, `"Derived"`, `"Protocol"`,
  `"eDT"`, etc.

- `codelist`:

  Codelist OID when the variable is controlled (e.g. `"CL.SEX"`,
  `"CL.AGEU"`); empty string otherwise.

- `mandatory`:

  `"Yes"` / `"No"` – whether the variable is required by SDTM-IG.

- `order`:

  Variable order as a string – position within the dataset.

- `format`:

  Display format (e.g. `"$8."`, `"DATE9."`); empty string when unset.

## See also

[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md),
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md),
[`validate()`](https://vthanik.github.io/herald/reference/validate.md),
[adam_spec](https://vthanik.github.io/herald/reference/adam_spec.md).

Other pilot-data:
[`adae`](https://vthanik.github.io/herald/reference/adae.md),
[`adam_spec`](https://vthanik.github.io/herald/reference/adam_spec.md),
[`adsl`](https://vthanik.github.io/herald/reference/adsl.md),
[`advs`](https://vthanik.github.io/herald/reference/advs.md),
[`dm`](https://vthanik.github.io/herald/reference/dm.md),
[`pilot-data`](https://vthanik.github.io/herald/reference/pilot-data.md)

## Examples

``` r
is_herald_spec(sdtm_spec)
#> [1] TRUE

# Datasets covered
sdtm_spec$ds_spec
#>     dataset                               label
#> 1        TA                          Trial Arms
#> 2        TE                      Trial Elements
#> 3        TI Trial Inclusion/ Exclusion Criteria
#> 4        TS                       Trial Summary
#> 5        TV                        Trial Visits
#> 6        DM                        Demographics
#> 7        SE                    Subject Elements
#> 8        SV                      Subject Visits
#> 9        CM             Concomitant Medications
#> 10       EX                            Exposure
#> 11       AE                      Adverse Events
#> 12       DS                         Disposition
#> 13       MH                     Medical History
#> 14     LBCH            Laboratory Tests Results
#> 15     LBHE            Laboratory Tests Results
#> 16     LBUR            Laboratory Tests Results
#> 17     QSCO                      Questionnaires
#> 18     QSDA                      Questionnaires
#> 19     QSGI                      Questionnaires
#> 20     QSHI                      Questionnaires
#> 21     QSMM                      Questionnaires
#> 22     QSNI                      Questionnaires
#> 23       SC             Subject Characteristics
#> 24       VS                         Vital Signs
#> 25   RELREC                     Related Records
#> 26   SUPPAE      Supplemental Qualifiers for AE
#> 27   SUPPDM      Supplemental Qualifiers for DM
#> 28   SUPPDS      Supplemental Qualifiers for DS
#> 29 SUPPLBCH      Supplemental Qualifiers for LB
#> 30 SUPPLBHE      Supplemental Qualifiers for LB
#> 31 SUPPLBUR      Supplemental Qualifiers for LB

# Total variable definitions
nrow(sdtm_spec$var_spec)
#> [1] 747

# All metadata columns shipped on var_spec
names(sdtm_spec$var_spec)
#>  [1] "dataset"   "variable"  "label"     "data_type" "length"   
#>  [6] "origin"    "codelist"  "mandatory" "order"     "format"   

# Variables in DM, with their controlled-terminology codelists
dm_vars <- sdtm_spec$var_spec[sdtm_spec$var_spec$dataset == "DM", ]
dm_vars[, c("variable", "label", "codelist", "mandatory")]
#>                variable                              label   codelist
#> IT.DM.STUDYID   STUDYID                   Study Identifier           
#> IT.DM.DOMAIN     DOMAIN                Domain Abbreviation           
#> IT.DM.USUBJID   USUBJID          Unique Subject Identifier           
#> IT.DM.SUBJID     SUBJID   Subject Identifier for the Study           
#> IT.DM.RFSTDTC   RFSTDTC  Subject Reference Start Date/Time           
#> IT.DM.RFENDTC   RFENDTC    Subject Reference End Date/Time           
#> IT.DM.RFXSTDTC RFXSTDTC Date/Time of First Study Treatment           
#> IT.DM.RFXENDTC RFXENDTC  Date/Time of Last Study Treatment           
#> IT.DM.RFICDTC   RFICDTC      Date/Time of Informed Consent           
#> IT.DM.RFPENDTC RFPENDTC  Date/Time of End of Participation           
#> IT.DM.DTHDTC     DTHDTC                 Date/Time of Death           
#> IT.DM.DTHFL       DTHFL                 Subject Death Flag CL.Y_BLANK
#> IT.DM.SITEID     SITEID              Study Site Identifier           
#> IT.DM.AGE           AGE                                Age           
#> IT.DM.AGEU         AGEU                          Age Units    CL.AGEU
#> IT.DM.SEX           SEX                                Sex     CL.SEX
#> IT.DM.RACE         RACE                               Race    CL.RACE
#> IT.DM.ETHNIC     ETHNIC                          Ethnicity  CL.ETHNIC
#> IT.DM.ARMCD       ARMCD                   Planned Arm Code   CL.ARMCD
#> IT.DM.ARM           ARM         Description of Planned Arm     CL.ARM
#> IT.DM.ACTARMCD ACTARMCD                    Actual Arm Code   CL.ARMCD
#> IT.DM.ACTARM     ACTARM          Description of Actual Arm     CL.ARM
#> IT.DM.COUNTRY   COUNTRY                            Country CL.COUNTRY
#> IT.DM.DMDTC       DMDTC            Date/Time of Collection           
#> IT.DM.DMDY         DMDY            Study Day of Collection           
#>                mandatory
#> IT.DM.STUDYID        Yes
#> IT.DM.DOMAIN         Yes
#> IT.DM.USUBJID        Yes
#> IT.DM.SUBJID         Yes
#> IT.DM.RFSTDTC         No
#> IT.DM.RFENDTC         No
#> IT.DM.RFXSTDTC        No
#> IT.DM.RFXENDTC        No
#> IT.DM.RFICDTC         No
#> IT.DM.RFPENDTC        No
#> IT.DM.DTHDTC          No
#> IT.DM.DTHFL           No
#> IT.DM.SITEID         Yes
#> IT.DM.AGE             No
#> IT.DM.AGEU            No
#> IT.DM.SEX            Yes
#> IT.DM.RACE            No
#> IT.DM.ETHNIC          No
#> IT.DM.ARMCD          Yes
#> IT.DM.ARM            Yes
#> IT.DM.ACTARMCD       Yes
#> IT.DM.ACTARM         Yes
#> IT.DM.COUNTRY        Yes
#> IT.DM.DMDTC           No
#> IT.DM.DMDY            No

# Mandatory variable count per dataset
mand <- sdtm_spec$var_spec[sdtm_spec$var_spec$mandatory == "Yes", ]
table(mand$dataset)
#> 
#>       AE       CM       DM       DS       EX     LBCH     LBHE 
#>        5        5       11        6        5        6        6 
#>     LBUR       MH     QSCO     QSDA     QSGI     QSHI     QSMM 
#>        6        5        7        7        7        7        7 
#>     QSNI   RELREC       SC       SE   SUPPAE   SUPPDM   SUPPDS 
#>        7        4        6        6        7        7        7 
#> SUPPLBCH SUPPLBHE SUPPLBUR       SV       TA       TE       TI 
#>        7        7        7        4        7        5        5 
#>       TS       TV       VS 
#>        6        4        6 

# \donttest{
# Stamp DM with spec attributes, then validate
dm_stamped <- apply_spec(dm, sdtm_spec)
attr(dm_stamped$USUBJID, "label")
#> [1] "Unique Subject Identifier"

r <- validate(files = dm_stamped, quiet = TRUE)
# }
```
