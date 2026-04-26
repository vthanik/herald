#' CDISC Pilot 03 example data and specs (bundled)
#'
#' @description
#' Attribute-stripped, 50-subject subset of CDISC SDTM/ADaM Pilot 03
#' shipped with herald for use in examples, tests, and vignettes. All four
#' datasets share the same 50 USUBJIDs (drawn from the ADSL ITT population).
#' DM is filtered to those 50 subjects (screen failures excluded). ADAE may
#' contain fewer than 50 distinct subjects because not every sampled subject
#' had an adverse event.
#'
#' @details
#' ## Lazy-loaded datasets (recommended)
#'
#' These objects are available directly after `library(herald)`:
#'
#' | Object | Domain / type | Rows | Description |
#' |--------|--------------|------|-------------|
#' | [dm] | SDTM DM | 50 | Demographics |
#' | [adsl] | ADaM ADSL | 50 | Subject-level analysis |
#' | [adae] | ADaM ADAE | 254 | Adverse events |
#' | [advs] | ADaM ADVS | 6 138 | Vital signs |
#' | [sdtm_spec] | `herald_spec` | -- | SDTM variable metadata |
#' | [adam_spec] | `herald_spec` | -- | ADaM variable metadata |
#'
#' ## Raw RDS files (backwards compat)
#'
#' The same data is also available via `inst/extdata/` for scripts written
#' before lazy loading was added:
#'
#' * `dm.rds`, `adsl.rds`, `advs.rds`, `adae.rds`
#' * `sdtm-spec.rds`, `adam-spec.rds`
#'
#' @source phuse-scripts CDISC Pilot 03 (SDTM/ADaM, public domain).
#'   Specs built from the full pilot `define.xml` via [read_define_xml()] +
#'   [as_herald_spec()].
#'
#' @seealso [dm], [adsl], [adae], [advs], [sdtm_spec], [adam_spec]
#' @family pilot-data
#'
#' @examples
#' # Lazy-loaded -- available immediately after library(herald)
#' nrow(dm)
#' is_herald_spec(sdtm_spec)
#'
#' dm_stamped <- apply_spec(dm, sdtm_spec)
#' attr(dm_stamped$USUBJID, "label")  # stamped from define.xml
#'
#' # Legacy inst/extdata approach (still works)
#' dm2 <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
#' @name pilot-data
NULL
