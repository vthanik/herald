# --------------------------------------------------------------------------
# ct-load.R -- load_ct() + ct_info()
# --------------------------------------------------------------------------
# herald bundles the latest SDTM + ADaM CT as RDS under `inst/rules/ct/`.
# Users who need a newer or older quarterly release call `download_ct()`
# to cache it under `tools::R_user_dir("herald","cache")`, then load it
# via `load_ct(version = ...)`.
#
# CT schema (matches heraldrules-v0; named list keyed by codelist
# submission name):
#
#   list(
#     NY = list(
#       codelist_code = "C66742",
#       codelist_name = "No Yes Response",
#       extensible    = FALSE,
#       terms         = data.frame(submissionValue, conceptId, preferredTerm)
#     ),
#     ...
#   )
#
# Every returned object carries attributes: package, version,
# release_date, source_url, source_path.

#' Load bundled or cached CDISC Controlled Terminology
#'
#' @description
#' Returns a named list of codelists -- one entry per CDISC codelist,
#' keyed by its submission-short-name (e.g. `"NY"`, `"ACCPARTY"`). Each
#' entry is a list with `codelist_code`, `codelist_name`, `extensible`,
#' and a `terms` data frame holding submission values, NCI concept
#' ids, and preferred terms.
#'
#' @param package Character scalar, one of `"sdtm"`, `"adam"`. Defaults
#'   to `"sdtm"`.
#' @param version Which release to load. One of:
#'   \itemize{
#'     \item `"bundled"` (default) -- the RDS under
#'       `inst/rules/ct/` shipped with the installed herald.
#'     \item `"latest-cache"` -- newest entry for `package` in the
#'       user CT cache (`tools::R_user_dir("herald","cache")`).
#'     \item `"YYYY-MM-DD"` -- a specific release already downloaded
#'       into the cache.
#'     \item an absolute `.rds` path -- loaded as-is.
#'   }
#'
#' @return Named list with the schema above. Carries attributes
#'   `package`, `version`, `release_date`, `source_url`, `source_path`.
#'
#' @examples
#' \dontrun{
#' ct <- load_ct("sdtm")
#' names(ct)[1:5]
#' ct[["NY"]]$terms
#' attr(ct, "version")
#' }
#'
#' @seealso [available_ct_releases()], [download_ct()], [ct_info()].
#' @family ct
#' @export
load_ct <- function(package = c("sdtm", "adam"), version = "bundled") {
  call <- rlang::caller_env()
  package <- match.arg(package)
  check_scalar_chr(version, call = call)

  src <- .resolve_ct_source(package, version, call = call)
  if (!is.null(.CT_CACHE[[src$key]])) {
    return(.CT_CACHE[[src$key]])
  }

  ct <- readRDS(src$path)
  attr(ct, "package")      <- package
  attr(ct, "version")      <- src$version
  attr(ct, "release_date") <- src$release_date
  attr(ct, "source_url")   <- src$source_url
  attr(ct, "source_path")  <- src$path

  .CT_CACHE[[src$key]] <- ct
  ct
}

#' Summarise the currently resolvable CT.
#'
#' Returns a list describing what `load_ct(package, version)` would
#' return without deserialising it. Pulls version + release date from
#' the bundled `CT-MANIFEST.json` or the user cache manifest.
#'
#' @param package Character scalar, one of `"sdtm"`, `"adam"`.
#' @param version Same semantics as `load_ct()`.
#'
#' @return A list with `package`, `version`, `release_date`,
#'   `row_count`, `codelist_count`, `source_path`, `source_url`.
#'
#' @family ct
#' @export
ct_info <- function(package = c("sdtm", "adam"), version = "bundled") {
  call <- rlang::caller_env()
  package <- match.arg(package)
  check_scalar_chr(version, call = call)

  ct <- load_ct(package, version = version)
  n_terms <- sum(vapply(ct, function(e) nrow(e$terms %||% data.frame()), integer(1L)))
  list(
    package        = attr(ct, "package"),
    version        = attr(ct, "version"),
    release_date   = attr(ct, "release_date"),
    row_count      = as.integer(n_terms),
    codelist_count = length(ct),
    source_path    = attr(ct, "source_path"),
    source_url     = attr(ct, "source_url")
  )
}

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

#' Package-level session cache. Deserialising the 492 KB SDTM RDS is
#' fast but not free; cache per (package, version) within a session so
#' op_value_in_codelist can call load_ct() on every rule.
#' @noRd
.CT_CACHE <- new.env(parent = emptyenv())

#' Turn the user-facing `version` into a concrete source on disk.
#' Returns list(path, version, release_date, source_url, key).
#' @noRd
.resolve_ct_source <- function(package, version, call) {
  # 1. Explicit file path override.
  if (grepl("\\.rds$", version, ignore.case = TRUE) || file.exists(version)) {
    if (!file.exists(version)) {
      herald_error(
        "CT file {.path {version}} does not exist.",
        class = "herald_error_input",
        call = call
      )
    }
    return(list(
      path = normalizePath(version, winslash = "/", mustWork = TRUE),
      version = "custom", release_date = NA_character_,
      source_url = NA_character_,
      key = paste0("file:", version)
    ))
  }

  # 2. Bundled default.
  if (identical(version, "bundled")) {
    p <- .bundled_ct_path(package, call = call)
    meta <- .bundled_ct_manifest()[[package]] %||% list()
    rel <- sub("^[a-z]+ct-", "", meta$effective %||% "")
    return(list(
      path = p, version = rel %||% "bundled", release_date = rel,
      source_url = meta$source_url %||% NA_character_,
      key = paste0("bundled:", package)
    ))
  }

  # 3. Cache lookup.
  cached <- .list_cached_ct()
  cached <- cached[cached$package == package, , drop = FALSE]
  if (identical(version, "latest-cache")) {
    if (nrow(cached) == 0L) {
      herald_error(
        "No cached CT for {.pkg {package}}. Run `download_ct()` first.",
        class = "herald_error_input",
        call = call
      )
    }
    hit <- cached[order(cached$release_date, decreasing = TRUE)[1L], ]
  } else {
    hit <- cached[cached$version == version, , drop = FALSE]
    if (nrow(hit) == 0L) {
      herald_error(
        "No cached CT {.pkg {package}} version {.val {version}}. Use `available_ct_releases('{package}')` to see what's available.",
        class = "herald_error_input",
        call = call
      )
    }
    hit <- hit[1L, ]
  }
  list(
    path = hit$path,
    version = hit$version,
    release_date = hit$release_date,
    source_url = NA_character_,
    key = paste0("cache:", package, "@", hit$version)
  )
}

#' Bundled RDS path for a package; errors informatively if missing.
#' @noRd
.bundled_ct_path <- function(package, call) {
  p <- system.file("rules", "ct", paste0(package, "-ct.rds"),
                   package = "herald")
  if (!nzchar(p)) {
    herald_error(
      "Bundled CT for {.pkg {package}} not found. Reinstall herald or run `download_ct()`.",
      class = "herald_error_input",
      call = call
    )
  }
  p
}

#' Read and cache the bundled manifest so attribute defaults don't hit
#' the filesystem for every lookup.
#' @noRd
.bundled_ct_manifest <- function() {
  if (!is.null(.CT_CACHE$manifest)) return(.CT_CACHE$manifest)
  p <- system.file("rules", "ct", "CT-MANIFEST.json", package = "herald")
  if (!nzchar(p)) return(list())
  m <- tryCatch(jsonlite::fromJSON(p, simplifyVector = FALSE),
                error = function(e) list())
  out <- list()
  if (is.list(m$packages)) {
    for (nm in names(m$packages)) out[[nm]] <- m$packages[[nm]]
  }
  .CT_CACHE$manifest <- out
  out
}
