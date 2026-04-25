#' CDISC Pilot 03 example data and specs (bundled)
#'
#' Attribute-stripped, 50-subject subset of CDISC SDTM/ADaM Pilot 03
#' shipped with herald for use in examples and tests. Subjects are drawn
#' from the ADSL ITT population (254 subjects) and the same 50 USUBJIDs
#' are applied to all four datasets. DM is filtered to those 50 USUBJIDs
#' (screen failures excluded). ADAE may contain fewer than 50 distinct
#' subjects because not every sampled subject had an adverse event.
#'
#' Source: phuse-scripts CDISC Pilot 03 (SDTM/ADaM).
#' Specs are built from the full pilot define.xml (not the 50-subject
#' subset) via [read_define_xml()] + [as_herald_spec()].
#'
#' @section Files in `inst/extdata/`:
#' * `dm.rds` -- SDTM DM, 50 rows, bare `data.frame`
#' * `adsl.rds` -- ADaM ADSL, 50 rows, bare `data.frame`
#' * `advs.rds` -- ADaM ADVS, ~6 300 rows, bare `data.frame`
#' * `adae.rds` -- ADaM ADAE, variable rows (<= 50 subjects), bare `data.frame`
#' * `sdtm-spec.rds` -- `herald_spec` derived from SDTM define.xml
#' * `adam-spec.rds` -- `herald_spec` derived from ADaM define.xml
#'
#' @examples
#' dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
#' spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
#' dm   <- apply_spec(list(DM = dm), spec)$DM
#' attr(dm$USUBJID, "label")  # stamped from define.xml
#'
#' adsl <- readRDS(system.file("extdata", "adsl.rds", package = "herald"))
#' aspec <- readRDS(system.file("extdata", "adam-spec.rds", package = "herald"))
#' adsl  <- apply_spec(list(ADSL = adsl), aspec)$ADSL
#' attr(adsl$USUBJID, "label")
#' @name pilot-data
NULL
