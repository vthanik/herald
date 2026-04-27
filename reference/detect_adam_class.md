# Detect the ADaM dataset class from column names

Infers the ADaM dataset class from the variables present in a dataset or
spec. Uses variable signatures rather than dataset name conventions so
it works across companies that name their ADaM datasets differently.

Classes returned:

- ADSL:

  Subject-level: one row per subject, no PARAMCD/AVAL.

- BDS:

  Basic Data Structure: PARAMCD + AVAL present. Includes lab, vitals,
  ECG, exposure, and similar parameter-based datasets.

- TTE:

  Time-to-event: BDS signature plus CNSR (censoring indicator).

- OCCDS:

  Occurrence Data Structure: occurrence-based without a numeric AVAL
  parameter spine; e.g. AE, CM, MH, CE.

- unknown:

  Insufficient variables to determine class.

## Usage

``` r
detect_adam_class(vars)
```

## Arguments

- vars:

  Character vector of variable names (uppercase). Can be column names
  from a data frame or the `variable` column from a spec.

## Value

A single character string: one of `"ADSL"`, `"BDS"`, `"TTE"`, `"OCCDS"`,
or `"unknown"`.

## Details

**Signature rules (evaluated in order):**

1.  **TTE**: PARAMCD + AVAL + CNSR all present.

2.  **BDS**: PARAMCD + AVAL present (without CNSR).

3.  **ADSL**: USUBJID present, no PARAMCD, no AVAL, no occurrence-flag
    pattern.

4.  **OCCDS**: USUBJID present + either (a) a term variable (\*TERM,
    \*DECOD, \*DOSE) or (b) at least two occurrence flag variables
    matching `*FL` but no PARAMCD.

5.  **unknown**: none of the above.

## See also

Other adam:
[`detect_adam_classes()`](https://vthanik.github.io/herald/reference/detect_adam_classes.md)

## Examples

``` r
adsl <- readRDS(system.file("extdata", "adsl.rds", package = "herald"))
advs <- readRDS(system.file("extdata", "advs.rds", package = "herald"))
adae <- readRDS(system.file("extdata", "adae.rds", package = "herald"))

# ---- Infer class from column names of existing data frames -----------
detect_adam_class(names(adsl))  # "ADSL"
#> [1] "OCCDS"
detect_adam_class(names(advs))  # "BDS"
#> [1] "BDS"
detect_adam_class(names(adae))  # "OCCDS"
#> [1] "OCCDS"

# ---- TTE class requires PARAMCD + AVAL + CNSR ------------------------
detect_adam_class(c("USUBJID", "PARAMCD", "AVAL", "CNSR", "EVDTM"))
#> [1] "TTE"

# ---- Explicit character vector (e.g. from a spec variable list) ------
detect_adam_class(c("USUBJID", "SAFFL", "ITTFL", "TRTP", "AGE"))  # "ADSL"
#> [1] "ADSL"
detect_adam_class(c("USUBJID", "PARAMCD", "AVAL", "AVISITN"))    # "BDS"
#> [1] "BDS"

# ---- Unknown when no identifying variables are present ---------------
detect_adam_class(c("X", "Y", "Z"))  # "unknown"
#> [1] "unknown"
```
