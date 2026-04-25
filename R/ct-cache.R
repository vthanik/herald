# --------------------------------------------------------------------------
# ct-cache.R -- user CT cache (tools::R_user_dir) + manifest
# --------------------------------------------------------------------------
# Downloaded CT releases live in the user's cache dir, separate from
# the bundled CT shipped under inst/. The cache has a small JSON
# manifest listing every downloaded release so load_ct(version = ...)
# can resolve a YYYY-MM-DD version to a file path without re-parsing
# filenames.

#' Return the user's CT cache directory, creating it on demand.
#'
#' Defaults to `tools::R_user_dir("herald", "cache")`. Users may
#' override by passing `dest` to `download_ct()`.
#' @noRd
.ct_cache_dir <- function(create = TRUE) {
  dir <- tools::R_user_dir("herald", "cache")
  if (create && !dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  dir
}

#' Path to the cache manifest (JSON).
#' @noRd
.ct_cache_manifest_path <- function(dir = .ct_cache_dir()) {
  file.path(dir, "cache-manifest.json")
}

#' Read the cache manifest. Returns an empty named list when missing
#' or malformed; never errors (cache corruption must not break
#' downstream `load_ct()`).
#' @noRd
.ct_cache_read <- function(dir = .ct_cache_dir(create = FALSE)) {
  if (!dir.exists(dir)) return(list())
  path <- .ct_cache_manifest_path(dir)
  if (!file.exists(path)) return(list())
  parsed <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (!is.list(parsed)) return(list())
  parsed
}

#' Append or update a manifest entry.
#' @noRd
.ct_cache_write <- function(entry, dir = .ct_cache_dir()) {
  if (!is.list(entry) || is.null(entry$package) || is.null(entry$version)) {
    herald_error_runtime(
      "{.arg entry} must be a list with {.field package} and {.field version} fields."
    )
  }
  m <- .ct_cache_read(dir)
  key <- paste0(entry$package, "@", entry$version)
  m[[key]] <- entry
  jsonlite::write_json(m, .ct_cache_manifest_path(dir),
                       pretty = TRUE, auto_unbox = TRUE)
  invisible(entry)
}

#' List cached CT entries as a tibble.
#' @noRd
.list_cached_ct <- function(dir = .ct_cache_dir(create = FALSE)) {
  m <- .ct_cache_read(dir)
  if (length(m) == 0L) {
    return(tibble::tibble(
      package       = character(),
      version       = character(),
      release_date  = character(),
      path          = character(),
      downloaded_at = character()
    ))
  }
  rows <- lapply(m, function(e) {
    data.frame(
      package       = as.character(e$package %||% NA_character_),
      version       = as.character(e$version %||% NA_character_),
      release_date  = as.character(e$release_date %||% NA_character_),
      path          = as.character(e$path %||% NA_character_),
      downloaded_at = as.character(e$downloaded_at %||% NA_character_),
      stringsAsFactors = FALSE
    )
  })
  tibble::as_tibble(do.call(rbind, rows))
}

#' Compose the canonical cache file name for a (package, version) pair.
#' Pattern: `<package>-ct-<version>.rds` (version is the release date).
#' @noRd
.cache_path <- function(package, version, dir = .ct_cache_dir()) {
  file.path(dir, sprintf("%s-ct-%s.rds", package, version))
}
