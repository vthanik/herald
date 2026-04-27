# CDISC Pilot 03 example data and specs (bundled)

Attribute-stripped, 50-subject subset of CDISC SDTM/ADaM Pilot 03
shipped with herald for use in examples, tests, and vignettes. All four
datasets share the same 50 USUBJIDs (drawn from the ADSL ITT
population). DM is filtered to those 50 subjects (screen failures
excluded). ADAE may contain fewer than 50 distinct subjects because not
every sampled subject had an adverse event.

## Source

phuse-scripts CDISC Pilot 03 (SDTM/ADaM, public domain). Specs built
from the full pilot `define.xml` via
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md) +
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md).

## Details

### Lazy-loaded datasets (recommended)

These objects are available directly after
[`library(herald)`](https://github.com/vthanik/herald):

|                                                                      |               |       |                        |
|----------------------------------------------------------------------|---------------|-------|------------------------|
| Object                                                               | Domain / type | Rows  | Description            |
| [dm](https://vthanik.github.io/herald/reference/dm.md)               | SDTM DM       | 50    | Demographics           |
| [adsl](https://vthanik.github.io/herald/reference/adsl.md)           | ADaM ADSL     | 50    | Subject-level analysis |
| [adae](https://vthanik.github.io/herald/reference/adae.md)           | ADaM ADAE     | 254   | Adverse events         |
| [advs](https://vthanik.github.io/herald/reference/advs.md)           | ADaM ADVS     | 6 138 | Vital signs            |
| [sdtm_spec](https://vthanik.github.io/herald/reference/sdtm_spec.md) | `herald_spec` | –     | SDTM variable metadata |
| [adam_spec](https://vthanik.github.io/herald/reference/adam_spec.md) | `herald_spec` | –     | ADaM variable metadata |

### Raw RDS files (backwards compat)

The same data is also available via `inst/extdata/` for scripts written
before lazy loading was added:

- `dm.rds`, `adsl.rds`, `advs.rds`, `adae.rds`

- `sdtm-spec.rds`, `adam-spec.rds`

## See also

[dm](https://vthanik.github.io/herald/reference/dm.md),
[adsl](https://vthanik.github.io/herald/reference/adsl.md),
[adae](https://vthanik.github.io/herald/reference/adae.md),
[advs](https://vthanik.github.io/herald/reference/advs.md),
[sdtm_spec](https://vthanik.github.io/herald/reference/sdtm_spec.md),
[adam_spec](https://vthanik.github.io/herald/reference/adam_spec.md)

Other pilot-data:
[`adae`](https://vthanik.github.io/herald/reference/adae.md),
[`adam_spec`](https://vthanik.github.io/herald/reference/adam_spec.md),
[`adsl`](https://vthanik.github.io/herald/reference/adsl.md),
[`advs`](https://vthanik.github.io/herald/reference/advs.md),
[`dm`](https://vthanik.github.io/herald/reference/dm.md),
[`sdtm_spec`](https://vthanik.github.io/herald/reference/sdtm_spec.md)

## Examples

``` r
# Lazy-loaded -- available immediately after library(herald)
nrow(dm)
#> [1] 50
is_herald_spec(sdtm_spec)
#> [1] TRUE

dm_stamped <- apply_spec(dm, sdtm_spec)
attr(dm_stamped$USUBJID, "label")  # stamped from define.xml
#> [1] "Unique Subject Identifier"

# Legacy inst/extdata approach (still works)
dm2 <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
```
