# Pilot DM (Demographics) domain

A 50-subject Demographics (DM) domain from the CDISC SDTM pilot
submission. Contains exactly one row per subject with screening /
enrolment dates, baseline characteristics, treatment arm assignment, and
country of enrolment. DM is the SDTM "spine": every clinical-data domain
joins back to DM via `STUDYID`/`USUBJID`. Useful for demonstrating SDTM
validation,
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
metadata stamping, and cross-domain rule checking.

All 25 variables shipped here are listed below with the labels drawn
from the bundled
[`sdtm_spec`](https://vthanik.github.io/herald/reference/sdtm_spec.md).

## Usage

``` r
dm
```

## Format

A data frame with **50 rows** and **25 columns**. Required (mandatory)
variables per SDTM-IG v2.0 are flagged below.

- `STUDYID`:

  *Study Identifier* (text, len 12, **required**) – unique study code
  (`"CDISCPILOT01"` for all rows).

- `DOMAIN`:

  *Domain Abbreviation* (text, len 2, **required**) – constant `"DM"`.

- `USUBJID`:

  *Unique Subject Identifier* (text, len 11, **required**) –
  study-unique subject ID; primary join key.

- `SUBJID`:

  *Subject Identifier for the Study* (text, len 4, **required**) –
  subject ID within the study.

- `RFSTDTC`:

  *Subject Reference Start Date/Time* (ISO 8601 date, len 10) –
  typically date of first study treatment.

- `RFENDTC`:

  *Subject Reference End Date/Time* (ISO 8601 date, len 10) – typically
  date of last study treatment.

- `RFXSTDTC`:

  *Date/Time of First Study Treatment* (ISO 8601 datetime, len 20).

- `RFXENDTC`:

  *Date/Time of Last Study Treatment* (ISO 8601 datetime, len 20).

- `RFICDTC`:

  *Date/Time of Informed Consent* (ISO 8601 datetime, len 20).

- `RFPENDTC`:

  *Date/Time of End of Participation* (ISO 8601 datetime, len 20).

- `DTHDTC`:

  *Date/Time of Death* (ISO 8601 datetime, len 20) – `NA` for surviving
  subjects.

- `DTHFL`:

  *Subject Death Flag* (text, len 1, codelist `CL.Y_BLANK`) – `"Y"` if
  subject died, blank otherwise.

- `SITEID`:

  *Study Site Identifier* (text, len 3, **required**).

- `AGE`:

  *Age* (integer, len 8) – numeric age at consent in `AGEU` units.

- `AGEU`:

  *Age Units* (text, len 6, codelist `CL.AGEU`) – typically `"YEARS"`.

- `SEX`:

  *Sex* (text, len 1, **required**, codelist `CL.SEX`) – `"M"` or `"F"`.

- `RACE`:

  *Race* (text, len 78, codelist `CL.RACE`) – e.g. `"WHITE"`,
  `"BLACK OR AFRICAN AMERICAN"`.

- `ETHNIC`:

  *Ethnicity* (text, len 25, codelist `CL.ETHNIC`).

- `ARMCD`:

  *Planned Arm Code* (text, len 8, **required**, codelist `CL.ARMCD`) –
  short code for the planned arm.

- `ARM`:

  *Description of Planned Arm* (text, len 20, **required**, codelist
  `CL.ARM`).

- `ACTARMCD`:

  *Actual Arm Code* (text, len 8, **required**, codelist `CL.ARMCD`) –
  actual arm received; may differ from `ARMCD` for protocol violators.

- `ACTARM`:

  *Description of Actual Arm* (text, len 20, **required**, codelist
  `CL.ARM`).

- `COUNTRY`:

  *Country* (text, len 3, **required**, codelist `CL.COUNTRY`) – ISO
  3166 alpha-3 code (e.g. `"USA"`).

- `DMDTC`:

  *Date/Time of Collection* (ISO 8601 date, len 10) – date demographic
  data was collected.

- `DMDY`:

  *Study Day of Collection* (integer, len 8) – study day of `DMDTC`
  relative to `RFSTDTC`.

## Source

CDISC SDTM/ADaM Pilot Submission Package (public domain), restricted to
the 50 ITT subjects sampled from the 254-subject pilot ADSL. Labels and
lengths are sourced verbatim from the pilot `define.xml` via
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md).

## See also

[adsl](https://vthanik.github.io/herald/reference/adsl.md),
[adae](https://vthanik.github.io/herald/reference/adae.md),
[advs](https://vthanik.github.io/herald/reference/advs.md)
(analysis-ready ADaM derivations of the same 50 subjects);
[sdtm_spec](https://vthanik.github.io/herald/reference/sdtm_spec.md)
(variable metadata as a `herald_spec`).

Other pilot-data:
[`adae`](https://vthanik.github.io/herald/reference/adae.md),
[`adam_spec`](https://vthanik.github.io/herald/reference/adam_spec.md),
[`adsl`](https://vthanik.github.io/herald/reference/adsl.md),
[`advs`](https://vthanik.github.io/herald/reference/advs.md),
[`pilot-data`](https://vthanik.github.io/herald/reference/pilot-data.md),
[`sdtm_spec`](https://vthanik.github.io/herald/reference/sdtm_spec.md)

## Examples

``` r
nrow(dm)
#> [1] 50
names(dm)
#>  [1] "STUDYID"  "DOMAIN"   "USUBJID"  "SUBJID"   "RFSTDTC"  "RFENDTC" 
#>  [7] "RFXSTDTC" "RFXENDTC" "RFICDTC"  "RFPENDTC" "DTHDTC"   "DTHFL"   
#> [13] "SITEID"   "AGE"      "AGEU"     "SEX"      "RACE"     "ETHNIC"  
#> [19] "ARMCD"    "ARM"      "ACTARMCD" "ACTARM"   "COUNTRY"  "DMDTC"   
#> [25] "DMDY"    

# Subject counts by sex and arm
table(dm$SEX, dm$ARM)
#>    
#>     Placebo Xanomeline High Dose Xanomeline Low Dose
#>   F      12                    6                  14
#>   M       5                    9                   4

# \donttest{
# Stamp SDTM attributes from spec, then validate
dm_stamped <- apply_spec(dm, sdtm_spec)
attr(dm_stamped$USUBJID, "label")
#> [1] "Unique Subject Identifier"

r <- validate(files = dm_stamped, quiet = TRUE)
r$datasets_checked
#> [1] "DM_STAMPED"
# }
```
