# --------------------------------------------------------------------------
# dict-providers-ct.R -- ct_provider wrapping load_ct() for CDISC CT
# --------------------------------------------------------------------------
# The bundled SDTM and ADaM Controlled Terminology ship as nested
# lists keyed by codelist submission name (R/ct-load.R). This factory
# wraps that data in a `herald_dict_provider` so ops can look it up
# through the same interface as MedDRA, WhoDrug, SRS, and sponsor
# dicts.
#
# The provider's `contains(value, field)` treats `field` as the
# codelist-submission-short-name ("NY", "ARMNULRS", etc.) or the NCI
# C-code or long human-readable name -- same lookup order as the
# existing `.lookup_codelist()` helper in R/ops-set.R.

#' CDISC Controlled Terminology as a Dictionary Provider
#'
#' @description
#' Returns a `herald_dict_provider` that serves the bundled (or
#' user-cached) CDISC CT. Rule ops that need to check codelist
#' membership look up this provider under the name `"ct-sdtm"` or
#' `"ct-adam"`.
#'
#' @param package One of `"sdtm"`, `"adam"`. Defaults to `"sdtm"`.
#' @param version Same semantics as [load_ct()]:
#'   `"bundled"` | `"latest-cache"` | `"YYYY-MM-DD"` | absolute
#'   `.rds` path.
#'
#' @return A `herald_dict_provider` with provider name
#'   `paste0("ct-", package)`.
#'
#' @examples
#' # Bundled SDTM CT (always available, no network)
#' p <- ct_provider("sdtm")
#' p$contains("Y", field = "NY")           # TRUE
#' p$contains("UNKNOWN", field = "NY")     # FALSE
#' p$contains(c("Y", "N", "BAD"), field = "NY")  # TRUE TRUE FALSE
#' p$info()$version
#' p$info()$codelist_count
#'
#' # Case-insensitive lookup
#' p$contains("y", field = "NY", ignore_case = TRUE)  # TRUE
#'
#' # ADaM CT provider
#' pa <- ct_provider("adam")
#' pa$info()$size_rows
#'
#' # Register globally so every validate() picks it up
#' register_dictionary("ct-sdtm", p)
#' list_dictionaries()
#' unregister_dictionary("ct-sdtm")
#'
#' # Pinned version from user cache (requires prior download_ct())
#' if (interactive()) {
#'   p_pinned <- ct_provider("sdtm", version = "2024-09-27")
#'   p_pinned$info()$version
#' }
#'
#' @seealso [load_ct()], [register_dictionary()].
#' @family dict
#' @export
ct_provider <- function(package = c("sdtm", "adam"), version = "bundled") {
  package <- match.arg(package)
  ct <- load_ct(package, version = version)

  n_codelists <- length(ct)
  n_terms <- sum(vapply(
    ct,
    function(e) nrow(e$terms %||% data.frame()),
    integer(1L)
  ))

  prov_name <- paste0("ct-", package)

  contains_fn <- function(value, field = NULL, ignore_case = FALSE) {
    if (is.null(field) || !nzchar(as.character(field))) {
      return(rep(NA, length(value)))
    }
    entry <- .lookup_codelist(ct, field)
    if (is.null(entry)) {
      return(rep(NA, length(value)))
    }
    accepted <- as.character(entry$terms$submissionValue %||% character())
    v <- as.character(value)
    v <- sub(" +$", "", v)
    if (isTRUE(ignore_case)) {
      return(toupper(v) %in% toupper(accepted))
    }
    v %in% accepted
  }

  lookup_fn <- function(value, field = NULL) {
    if (is.null(field) || !nzchar(as.character(field))) {
      return(NULL)
    }
    entry <- .lookup_codelist(ct, field)
    if (is.null(entry)) {
      return(NULL)
    }
    tms <- entry$terms
    hits <- tms[tms$submissionValue %in% as.character(value), , drop = FALSE]
    if (nrow(hits) == 0L) {
      return(NULL)
    }
    hits
  }

  src_path <- attr(ct, "source_path") %||% ""
  bundled_root <- system.file("rules", "ct", package = "herald")
  inst_root <- file.path("inst", "rules", "ct")
  is_bundled <- (nzchar(bundled_root) &&
    startsWith(
      normalizePath(src_path, winslash = "/", mustWork = FALSE),
      normalizePath(bundled_root, winslash = "/", mustWork = FALSE)
    )) ||
    startsWith(src_path, inst_root)

  new_dict_provider(
    name = prov_name,
    version = attr(ct, "version") %||% NA_character_,
    source = if (is_bundled) "bundled" else "cache",
    license = "CC-BY-4.0",
    license_note = "CDISC NCI Thesaurus CT (NCI EVS, public domain)",
    size_rows = n_terms,
    fields = names(ct),
    contains = contains_fn,
    lookup = lookup_fn
  )
}
