# Pilot ADAE (Adverse Events Analysis Dataset, OCCDS)

An ADAE dataset from the CDISC ADaM pilot submission containing 254
adverse-event records across the 50 pilot subjects. ADAE is an OCCDS
(Occurrence Data Structure) following ADaM IG: each row is one
occurrence of an adverse event, joined to ADSL by `USUBJID` and carrying
the full MedDRA hierarchy plus serious-criteria, severity, and
treatment-emergent analysis flags. Useful for testing
dictionary-provider integration and cross-domain validation.

All 55 variables shipped here are documented below using labels from the
bundled
[`adam_spec`](https://vthanik.github.io/herald/reference/adam_spec.md).

## Usage

``` r
adae
```

## Format

A data frame with **254 rows** and **55 columns**.

- `STUDYID`:

  *Study Identifier* (text, len 12).

- `SITEID`:

  *Study Site Identifier* (text, len 3).

- `USUBJID`:

  *Unique Subject Identifier* (text, len 11).

- `TRTA`:

  *Actual Treatment* (text, len 20).

- `TRTAN`:

  *Actual Treatment (N)* (integer, len 8).

- `AGE`:

  *Age* (integer, len 8).

- `AGEGR1`:

  *Pooled Age Group 1* (text, len 5).

- `AGEGR1N`:

  *Pooled Age Group 1 (N)* (integer, len 8).

- `RACE`:

  *Race* (text, len 32).

- `RACEN`:

  *Race (N)* (integer, len 8).

- `SEX`:

  *Sex* (text, len 1).

- `SAFFL`:

  *Safety Population Flag* (text, len 1).

- `TRTSDT`:

  *Date of First Exposure to Treatment* (numeric date, len 8).

- `TRTEDT`:

  *Date of Last Exposure to Treatment* (numeric date, len 8).

- `ASTDT`:

  *Analysis Start Date* (numeric date, len 8) – AE onset for analysis.

- `ASTDTF`:

  *Analysis Start Date Imputation Flag* (text, len 1).

- `ASTDY`:

  *Analysis Start Relative Day* (integer, len 8) – study day of onset
  relative to `TRTSDT`.

- `AENDT`:

  *Analysis End Date* (numeric date, len 8).

- `AENDY`:

  *Analysis End Relative Day* (integer, len 8).

- `ADURN`:

  *AE Duration (N)* (integer, len 8).

- `ADURU`:

  *AE Duration Units* (text, len 3) – e.g. `"DAY"`.

- `AETERM`:

  *Reported Term for the Adverse Event* (text, len 46) – verbatim CRF
  term.

- `AELLT`:

  *Lowest Level Term* (text, len 46) – MedDRA LLT.

- `AELLTCD`:

  *Lowest Level Term Code* (integer, len 8).

- `AEDECOD`:

  *Dictionary-Derived Term* (text, len 46) – MedDRA PT.

- `AEPTCD`:

  *Preferred Term Code* (integer, len 8).

- `AEHLT`:

  *High Level Term* (text, len 8).

- `AEHLTCD`:

  *High Level Term Code* (integer, len 8).

- `AEHLGT`:

  *High Level Group Term* (text, len 9).

- `AEHLGTCD`:

  *High Level Group Term Code* (integer, len 8).

- `AEBODSYS`:

  *Body System or Organ Class* (text, len 67) – MedDRA SOC.

- `AESOC`:

  *Primary System Organ Class* (text, len 67).

- `AESOCCD`:

  *Primary System Organ Class Code* (integer, len 8).

- `AESEV`:

  *Severity/Intensity* (text, len 8) – `"MILD"`, `"MODERATE"`,
  `"SEVERE"`.

- `AESER`:

  *Serious Event* (text, len 1) – `"Y"`/`""`.

- `AESCAN`:

  *Involves Cancer* (text, len 1).

- `AESCONG`:

  *Congenital Anomaly or Birth Defect* (text, len 1).

- `AESDISAB`:

  *Persist or Signif Disability/Incapacity* (text, len 1).

- `AESDTH`:

  *Results in Death* (text, len 1).

- `AESHOSP`:

  *Requires or Prolongs Hospitalization* (text, len 1).

- `AESLIFE`:

  *Is Life Threatening* (text, len 1).

- `AESOD`:

  *Occurred with Overdose* (text, len 1).

- `AEREL`:

  *Causality* (text, len 8) – relationship to study drug.

- `AEACN`:

  *Action Taken with Study Treatment* (text, len 1).

- `AEOUT`:

  *Outcome of Adverse Event* (text, len 26).

- `AESEQ`:

  *Sequence Number* (integer, len 8) – AE sequence within subject.

- `TRTEMFL`:

  *Treatment Emergent Analysis Flag* (text, len 1) – `"Y"` if AE began
  after first dose.

- `AOCCFL`:

  *1st Occurrence of Any AE Flag* (text, len 1).

- `AOCCSFL`:

  *1st Occurrence of SOC Flag* (text, len 1).

- `AOCCPFL`:

  *1st Occurrence of Preferred Term Flag* (text, len 1).

- `AOCC02FL`:

  *1st Occurrence 02 Flag for Serious* (text, len 1).

- `AOCC03FL`:

  *1st Occurrence 03 Flag for Serious SOC* (text, len 1).

- `AOCC04FL`:

  *1st Occurrence 04 Flag for Serious PT* (text, len 1).

- `CQ01NAM`:

  *Customized Query 01 Name* (text, len 19) – sponsor custom MedDRA
  query.

- `AOCC01FL`:

  *1st Occurrence 01 Flag for CQ01* (text, len 1).

## Source

CDISC SDTM/ADaM Pilot Submission Package (public domain). 254 AE records
spanning the 50 pilot subjects.

## See also

[adsl](https://vthanik.github.io/herald/reference/adsl.md) (population
denominator); [dm](https://vthanik.github.io/herald/reference/dm.md);
[adam_spec](https://vthanik.github.io/herald/reference/adam_spec.md).

Other pilot-data:
[`adam_spec`](https://vthanik.github.io/herald/reference/adam_spec.md),
[`adsl`](https://vthanik.github.io/herald/reference/adsl.md),
[`advs`](https://vthanik.github.io/herald/reference/advs.md),
[`dm`](https://vthanik.github.io/herald/reference/dm.md),
[`pilot-data`](https://vthanik.github.io/herald/reference/pilot-data.md),
[`sdtm_spec`](https://vthanik.github.io/herald/reference/sdtm_spec.md)

## Examples

``` r
nrow(adae)
#> [1] 254
table(adae$AESEV)
#> 
#>     MILD MODERATE   SEVERE 
#>      157       89        8 
table(adae$TRTEMFL)
#> 
#>       Y 
#>  13 241 

# MedDRA SOC distribution
sort(table(adae$AEBODSYS), decreasing = TRUE)[1:5]
#> 
#> GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS 
#>                                                   54 
#>               SKIN AND SUBCUTANEOUS TISSUE DISORDERS 
#>                                                   51 
#>                             NERVOUS SYSTEM DISORDERS 
#>                                                   29 
#>                           GASTROINTESTINAL DISORDERS 
#>                                                   22 
#>                                       INVESTIGATIONS 
#>                                                   22 

# Serious AE summary
adae[adae$AESER == "Y", c("USUBJID", "AEDECOD", "AESEV", "AEOUT")]
#> [1] USUBJID AEDECOD AESEV   AEOUT  
#> <0 rows> (or 0-length row.names)

# Treatment-emergent first-occurrence subset
tefoc <- adae[adae$TRTEMFL == "Y" & adae$AOCCPFL == "Y", ]
nrow(tefoc)
#> [1] 162
```
