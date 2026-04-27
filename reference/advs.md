# Pilot ADVS (Vital Signs Analysis Dataset, BDS)

An ADVS dataset from the CDISC ADaM pilot submission with 6,138 records
across all scheduled vital-sign assessments for the 50 pilot subjects.
ADVS follows the ADaM Basic Data Structure (BDS): one row per (subject,
parameter, visit, timepoint), with `AVAL` carrying the analysis value,
`BASE` the baseline, and `CHG`/`PCHG` the absolute / percent change from
baseline. The largest of the pilot datasets – useful for performance
benchmarking and BDS-rule coverage testing.

All 35 variables shipped here are documented below using labels from the
bundled
[`adam_spec`](https://vthanik.github.io/herald/reference/adam_spec.md).

## Usage

``` r
advs
```

## Format

A data frame with **6,138 rows** and **35 columns**.

- `STUDYID`:

  *Study Identifier* (text, len 12).

- `SITEID`:

  *Study Site Identifier* (text, len 3).

- `USUBJID`:

  *Unique Subject Identifier* (text, len 11).

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

- `TRTP`:

  *Planned Treatment* (text, len 20).

- `TRTPN`:

  *Planned Treatment (N)* (integer, len 8).

- `TRTA`:

  *Actual Treatment* (text, len 20).

- `TRTAN`:

  *Actual Treatment (N)* (integer, len 8).

- `PARAMCD`:

  *Parameter Code* (text, len 8) – short code (e.g. `"DIABP"`,
  `"SYSBP"`, `"PULSE"`, `"TEMP"`, `"WEIGHT"`).

- `PARAM`:

  *Parameter* (text, len 100) – human-readable name (e.g.
  `"Diastolic Blood Pressure (mmHg)"`).

- `PARAMN`:

  *Parameter (N)* (integer, len 8) – numeric companion to `PARAMCD`.

- `ADT`:

  *Analysis Date* (numeric date, len 8).

- `ADY`:

  *Analysis Relative Day* (integer, len 8) – study day of `ADT` relative
  to `TRTSDT`.

- `ATPTN`:

  *Analysis Timepoint (N)* (integer, len 8).

- `ATPT`:

  *Analysis Timepoint* (text, len 30) – e.g. `"PRE-DOSE"`.

- `AVISIT`:

  *Analysis Visit* (text, len 16) – normalised visit name (`"BASELINE"`,
  `"WEEK 8"`, etc.).

- `AVISITN`:

  *Analysis Visit (N)* (integer, len 8).

- `AVAL`:

  *Analysis Value* (float, len 8) – the value used in analyses.

- `BASE`:

  *Baseline Value* (float, len 8).

- `BASETYPE`:

  *Baseline Type* (text, len 30) – baseline definition flag for analyses
  with multiple baselines.

- `CHG`:

  *Change from Baseline* (float, len 8) – `AVAL - BASE`.

- `PCHG`:

  *Percent Change from Baseline* (float, len 8) – `100 * CHG / BASE`.

- `VISITNUM`:

  *Visit Number* (float, len 8) – numeric visit order from SDTM.

- `VISIT`:

  *Visit Name* (text, len 19) – visit label from SDTM.

- `VSSEQ`:

  *Sequence Number* (integer, len 8) – record sequence within
  (`USUBJID`, `VSTESTCD`).

- `ANL01FL`:

  *Analysis Flag 01* (text, len 1) – primary-analysis record flag.

- `ABLFL`:

  *Baseline Record Flag* (text, len 1) – `"Y"` on the row used to derive
  `BASE`.

## Source

CDISC SDTM/ADaM Pilot Submission Package (public domain). 6,138
vital-sign assessments across the 50 pilot subjects.

## See also

[adsl](https://vthanik.github.io/herald/reference/adsl.md) (population
denominator);
[adam_spec](https://vthanik.github.io/herald/reference/adam_spec.md).

Other pilot-data:
[`adae`](https://vthanik.github.io/herald/reference/adae.md),
[`adam_spec`](https://vthanik.github.io/herald/reference/adam_spec.md),
[`adsl`](https://vthanik.github.io/herald/reference/adsl.md),
[`dm`](https://vthanik.github.io/herald/reference/dm.md),
[`pilot-data`](https://vthanik.github.io/herald/reference/pilot-data.md),
[`sdtm_spec`](https://vthanik.github.io/herald/reference/sdtm_spec.md)

## Examples

``` r
nrow(advs)
#> [1] 6138
unique(advs$PARAMCD)
#> [1] "DIABP"  "HEIGHT" "PULSE"  "SYSBP"  "TEMP"   "WEIGHT"

# Records per parameter
table(advs$PARAMCD)
#> 
#>  DIABP HEIGHT  PULSE  SYSBP   TEMP WEIGHT 
#>   1698     50   1698   1698    564    430 

# Baseline records only
bl <- advs[advs$ABLFL == "Y", ]
nrow(bl)
#> [1] 548

# Mean change from baseline by parameter and visit (analysis subset)
anl <- advs[advs$ANL01FL == "Y" & !is.na(advs$CHG), ]
aggregate(CHG ~ PARAMCD + AVISIT, data = anl, mean)
#>    PARAMCD           AVISIT          CHG
#> 1    DIABP         Baseline  0.000000000
#> 2    PULSE         Baseline  0.000000000
#> 3    SYSBP         Baseline  0.000000000
#> 4     TEMP         Baseline  0.000000000
#> 5   WEIGHT         Baseline  0.000000000
#> 6    DIABP End of Treatment -0.962962963
#> 7    PULSE End of Treatment  1.074074074
#> 8    SYSBP End of Treatment -5.296296296
#> 9     TEMP End of Treatment  0.042045455
#> 10  WEIGHT End of Treatment -0.227727273
#> 11   DIABP          Week 12 -1.979166667
#> 12   PULSE          Week 12  4.802083333
#> 13   SYSBP          Week 12 -7.697916667
#> 14    TEMP          Week 12  0.154193548
#> 15  WEIGHT          Week 12  0.392258065
#> 16   DIABP          Week 16 -2.357142857
#> 17   PULSE          Week 16  1.333333333
#> 18   SYSBP          Week 16 -6.690476190
#> 19    TEMP          Week 16 -0.006071429
#> 20  WEIGHT          Week 16  0.005714286
#> 21   DIABP           Week 2 -1.280000000
#> 22   PULSE           Week 2  4.340000000
#> 23   SYSBP           Week 2 -4.766666667
#> 24    TEMP           Week 2 -0.044897959
#> 25  WEIGHT           Week 2  0.105744681
#> 26   DIABP          Week 20 -1.409090909
#> 27   PULSE          Week 20  1.060606061
#> 28   SYSBP          Week 20 -5.075757576
#> 29    TEMP          Week 20  0.155454545
#> 30  WEIGHT          Week 20 -0.183478261
#> 31   DIABP          Week 24  1.074074074
#> 32   PULSE          Week 24  1.962962963
#> 33   SYSBP          Week 24 -4.055555556
#> 34    TEMP          Week 24  0.101111111
#> 35  WEIGHT          Week 24  0.310000000
#> 36   DIABP          Week 26 -3.039215686
#> 37   PULSE          Week 26  0.941176471
#> 38   SYSBP          Week 26 -7.078431373
#> 39    TEMP          Week 26  0.014375000
#> 40  WEIGHT          Week 26 -0.026470588
#> 41   DIABP           Week 4 -0.422222222
#> 42   PULSE           Week 4  2.466666667
#> 43   SYSBP           Week 4 -4.740740741
#> 44    TEMP           Week 4 -0.101818182
#> 45  WEIGHT           Week 4  0.280681818
#> 46   DIABP           Week 6 -2.116666667
#> 47   PULSE           Week 6  2.800000000
#> 48   SYSBP           Week 6 -2.791666667
#> 49    TEMP           Week 6 -0.032307692
#> 50  WEIGHT           Week 6  0.434871795
#> 51   DIABP           Week 8 -0.076190476
#> 52   PULSE           Week 8  3.819047619
#> 53   SYSBP           Week 8 -1.847619048
#> 54    TEMP           Week 8  0.019411765
#> 55  WEIGHT           Week 8  0.525000000
```
