# Detect ADaM class for each dataset

Applies
[`detect_adam_class`](https://vthanik.github.io/herald/reference/detect_adam_class.md)
to every dataset. Pass data frames as bare variables (names inferred
from symbols), as a named list, or as a `herald_spec`.

## Usage

``` r
detect_adam_classes(..., call = rlang::caller_env())
```

## Arguments

- ...:

  One or more data frames (names inferred from variable symbols or
  provided explicitly, e.g. `ADSL = adsl`), a single named list of data
  frames, or a single `herald_spec` object.

- call:

  Caller environment for error reporting.

## Value

A named character vector mapping dataset name to ADaM class.

## See also

Other adam:
[`detect_adam_class()`](https://vthanik.github.io/herald/reference/detect_adam_class.md)

## Examples

``` r
adsl <- readRDS(system.file("extdata", "adsl.rds", package = "herald"))
advs <- readRDS(system.file("extdata", "advs.rds", package = "herald"))
adae <- readRDS(system.file("extdata", "adae.rds", package = "herald"))

# ---- Bare variable names -- dataset names inferred from symbols ------
detect_adam_classes(adsl, advs, adae)
#>    ADSL    ADVS    ADAE 
#> "OCCDS"   "BDS" "OCCDS" 

# ---- Explicit names when variable symbols differ from domain names ----
detect_adam_classes(ADSL = adsl, ADVS = advs, ADAE = adae)
#>    ADSL    ADVS    ADAE 
#> "OCCDS"   "BDS" "OCCDS" 

# ---- Named list of data frames ---------------------------------------
datasets <- list(ADSL = adsl, ADVS = advs, ADAE = adae)
detect_adam_classes(datasets)
#>    ADSL    ADVS    ADAE 
#> "OCCDS"   "BDS" "OCCDS" 

# ---- herald_spec -- reads variable names from var_spec$variable ------
spec <- as_herald_spec(
  ds_spec  = data.frame(dataset = c("ADSL", "ADVS"), stringsAsFactors = FALSE),
  var_spec = data.frame(
    dataset  = c(rep("ADSL", ncol(adsl)), rep("ADVS", ncol(advs))),
    variable = c(names(adsl), names(advs)),
    stringsAsFactors = FALSE
  )
)
detect_adam_classes(spec)
#>    ADSL    ADVS 
#> "OCCDS"   "BDS" 
```
