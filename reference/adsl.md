# Pilot ADSL (Subject-Level Analysis Dataset)

A 50-subject ADaM ADSL dataset from the CDISC pilot submission. ADSL is
the cornerstone analysis dataset: one row per subject, carrying every
population-level analysis variable (treatment assignment, population
flags, baseline measurements, disposition). All BDS and OCCDS analysis
datasets in the same study merge population flags from ADSL.

All 49 variables shipped here are documented below using labels from the
bundled
[`adam_spec`](https://vthanik.github.io/herald/reference/adam_spec.md).

## Usage

``` r
adsl
```

## Format

A data frame with **50 rows** and **49 columns**.

- `STUDYID`:

  *Study Identifier* (text, len 12).

- `USUBJID`:

  *Unique Subject Identifier* (text, len 11) – join key used by every
  BDS / OCCDS analysis dataset.

- `SUBJID`:

  *Subject Identifier for the Study* (text, len 4).

- `SITEID`:

  *Study Site Identifier* (text, len 3).

- `SITEGR1`:

  *Pooled Site Group 1* (text, len 3) – analysis pooling of small sites.

- `ARM`:

  *Description of Planned Arm* (text, len 20).

- `TRT01P`:

  *Planned Treatment for Period 01* (text, len 20).

- `TRT01PN`:

  *Planned Treatment for Period 01 (N)* (integer, len 8) – numeric
  companion to `TRT01P`.

- `TRT01A`:

  *Actual Treatment for Period 01* (text, len 20).

- `TRT01AN`:

  *Actual Treatment for Period 01 (N)* (integer, len 8).

- `TRTSDT`:

  *Date of First Exposure to Treatment* (numeric SAS date, len 8).

- `TRTEDT`:

  *Date of Last Exposure to Treatment* (numeric SAS date, len 8).

- `TRTDURD`:

  *Total Treatment Duration (Days)* (integer, len 8) –
  `TRTEDT - TRTSDT + 1`.

- `AVGDD`:

  *Avg Daily Dose (as planned)* (float, len 8).

- `CUMDOSE`:

  *Cumulative Dose (as planned)* (float, len 8).

- `AGE`:

  *Age* (integer, len 8).

- `AGEGR1`:

  *Pooled Age Group 1* (text, len 5) – e.g. `"<65"`, `"65-80"`, `">80"`.

- `AGEGR1N`:

  *Pooled Age Group 1 (N)* (integer, len 8).

- `AGEU`:

  *Age Units* (text, len 5).

- `RACE`:

  *Race* (text, len 32).

- `RACEN`:

  *Race (N)* (integer, len 8).

- `SEX`:

  *Sex* (text, len 1).

- `ETHNIC`:

  *Ethnicity* (text, len 22).

- `SAFFL`:

  *Safety Population Flag* (text, len 1) – `"Y"`/`""`.

- `ITTFL`:

  *Intent-To-Treat Population Flag* (text, len 1).

- `EFFFL`:

  *Efficacy Population Flag* (text, len 1).

- `COMP8FL`:

  *Completers of Week 8 Population Flag* (text, len 1).

- `COMP16FL`:

  *Completers of Week 16 Population Flag* (text, len 1).

- `COMP24FL`:

  *Completers of Week 24 Population Flag* (text, len 1).

- `DISCONFL`:

  *Did the Subject Discontinue the Study?* (text, len 1).

- `DSRAEFL`:

  *Discontinued due to AE?* (text, len 1).

- `DTHFL`:

  *Subject Died?* (text, len 1).

- `BMIBL`:

  *Baseline BMI (kg/m^2)* (float, len 8).

- `BMIBLGR1`:

  *Pooled Baseline BMI Group 1* (text, len 6).

- `HEIGHTBL`:

  *Baseline Height (cm)* (float, len 8).

- `WEIGHTBL`:

  *Baseline Weight (kg)* (float, len 8).

- `EDUCLVL`:

  *Years of Education* (integer, len 8).

- `DISONSDT`:

  *Date of Onset of Disease* (numeric SAS date, len 8).

- `DURDIS`:

  *Duration of Disease (Months)* (float, len 8).

- `DURDSGR1`:

  *Pooled Disease Duration Group 1* (text, len 4).

- `VISIT1DT`:

  *Date of Visit 1* (numeric SAS date, len 8).

- `RFSTDTC`:

  *Subject Reference Start Date/Time* (ISO 8601 datetime, len 20).

- `RFENDTC`:

  *Subject Reference End Date/Time* (ISO 8601 datetime, len 20).

- `VISNUMEN`:

  *End of Trt Visit (Vis 12 or Early Term.)* (integer, len 8).

- `RFENDT`:

  *Date of Discontinuation/Completion* (numeric SAS date, len 8).

- `DCDECOD`:

  *Standardized Disposition Term* (text, len 27) – `"COMPLETED"`,
  `"ADVERSE EVENT"`, `"WITHDRAWAL BY SUBJECT"`, etc.

- `EOSSTT`:

  *End of Study Status* (text, len 12) – `"COMPLETED"` /
  `"DISCONTINUED"`.

- `DCSREAS`:

  *Reason for Discontinuation from Study* (text, len 18).

- `MMSETOT`:

  *MMSE Total* (integer, len 8) – baseline Mini-Mental State Examination
  total.

## Source

CDISC SDTM/ADaM Pilot Submission Package (public domain). Trimmed to 50
subjects from the full 254-subject pilot ADSL.

## See also

[dm](https://vthanik.github.io/herald/reference/dm.md) (corresponding
SDTM source);
[adae](https://vthanik.github.io/herald/reference/adae.md),
[advs](https://vthanik.github.io/herald/reference/advs.md) (downstream
ADaM analyses);
[adam_spec](https://vthanik.github.io/herald/reference/adam_spec.md)
(variable metadata).

Other pilot-data:
[`adae`](https://vthanik.github.io/herald/reference/adae.md),
[`adam_spec`](https://vthanik.github.io/herald/reference/adam_spec.md),
[`advs`](https://vthanik.github.io/herald/reference/advs.md),
[`dm`](https://vthanik.github.io/herald/reference/dm.md),
[`pilot-data`](https://vthanik.github.io/herald/reference/pilot-data.md),
[`sdtm_spec`](https://vthanik.github.io/herald/reference/sdtm_spec.md)

## Examples

``` r
nrow(adsl)
#> [1] 50
names(adsl)[1:10]
#>  [1] "STUDYID" "USUBJID" "SUBJID"  "SITEID"  "SITEGR1" "ARM"    
#>  [7] "TRT01P"  "TRT01PN" "TRT01A"  "TRT01AN"

# Population subsets
table(adsl$SAFFL)             # Safety population
#> 
#>  Y 
#> 50 
table(adsl$ITTFL, adsl$EFFFL) # ITT vs Efficacy
#>    
#>      N  Y
#>   Y  4 46

# Treatment-arm summary
table(adsl$TRT01P)
#> 
#>              Placebo Xanomeline High Dose  Xanomeline Low Dose 
#>                   17                   15                   18 

# Baseline characteristics (numeric)
summary(adsl[, c("AGE", "BMIBL", "HEIGHTBL", "WEIGHTBL")])
#>       AGE            BMIBL          HEIGHTBL        WEIGHTBL     
#>  Min.   :60.00   Min.   :15.10   Min.   :142.2   Min.   : 39.90  
#>  1st Qu.:74.00   1st Qu.:21.90   1st Qu.:155.2   1st Qu.: 55.50  
#>  Median :77.00   Median :24.70   Median :160.0   Median : 65.30  
#>  Mean   :76.78   Mean   :24.71   Mean   :162.3   Mean   : 65.57  
#>  3rd Qu.:82.00   3rd Qu.:26.90   3rd Qu.:170.2   3rd Qu.: 76.00  
#>  Max.   :88.00   Max.   :34.50   Max.   :181.6   Max.   :101.60  
#>                  NAs    :1                       NAs    :1       

# \donttest{
adsl_stamped <- apply_spec(adsl, adam_spec)
r <- validate(files = adsl_stamped, quiet = TRUE)
r$profile
#> [1] NA
# }
```
