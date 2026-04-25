# --------------------------------------------------------------------------
# dict-providers-srs.R -- FDA Substance Registration System (UNII)
# --------------------------------------------------------------------------
# The FDA SRS / UNII table is a ~15-20 MB public registry listing
# unique-ingredient identifiers (UNII codes) and their preferred
# chemical names, used by TS-domain rules like CG0442-CG0451.
#
# Size and licensing:
#   - Public domain (FDA redistributes freely).
#   - Too large to bundle in herald without blowing the 5 MB CRAN
#     tarball cap.
#   - Distributed as a zipped tab-delimited file with columns:
#       UNII, PT, RN, EC, NCIT, RXCUI, ITIS, NCBI, PLANTS, GRIN,
#       INN_ID, MPNS, USAN_YEAR, USAN_STEM, UNII_TYPE, NAME_TYPE
#     (format documented at
#     https://fis.fda.gov/extensions/FDA_SRS_UNII/FDA_SRS_UNII.html)
#
# herald provides:
#   - download_srs()  -- fetches + parses + caches the zipped
#                        tab-delim distribution into a tidy RDS.
#   - srs_provider()  -- returns a herald_dict_provider backed by
#                        the cache entry.

.SRS_URL <- "https://fdasis.nlm.nih.gov/srs/download/srs/UNII_Data.zip"

#' Download + cache the FDA SRS / UNII table
#'
#' @description
#' Fetches the FDA's public bulk download, parses the tab-delimited
#' body inside the ZIP into a tidy tibble, writes it to the user
#' cache as an RDS, and updates the cache manifest. Idempotent --
#' re-runs short-circuit when the file is already cached.
#'
#' @param version Release tag for the cache path. Defaults to today's
#'   ISO date (`format(Sys.Date(), "%Y-%m-%d")`), since the FDA does
#'   not expose a version in the filename.
#' @param dest Target directory. Defaults to
#'   `tools::R_user_dir("herald", "cache")`.
#' @param force Re-download even when the RDS already exists.
#' @param timeout Seconds for `utils::download.file()`. Default 180.
#' @param quiet Suppress progress output.
#'
#' @return The path to the generated RDS, invisibly.
#'
#' @seealso [srs_provider()], [download_ct()].
#' @family ct
#' @export
download_srs <- function(version = format(Sys.Date(), "%Y-%m-%d"),
                         dest    = .ct_cache_dir(),
                         force   = FALSE,
                         timeout = 180L,
                         quiet   = FALSE) {
  call <- rlang::caller_env()
  check_scalar_chr(version, call = call)
  check_scalar_chr(dest, call = call)
  if (!dir.exists(dest)) dir.create(dest, recursive = TRUE)

  rds_path <- file.path(dest, sprintf("srs-%s.rds", version))

  .download_and_cache(
    url            = .SRS_URL,
    rds_path       = rds_path,
    fetch_ext      = ".zip",
    parser         = function(tmp, info) .parse_srs_zip(tmp, info$version),
    parser_info    = list(version = version),
    manifest_entry = list(
      package      = "srs",
      version      = version,
      release_date = version,
      path         = rds_path
    ),
    force   = force,
    timeout = timeout,
    quiet   = quiet,
    dest    = dest
  )
}

#' FDA SRS / UNII as a Dictionary Provider
#'
#' @description
#' Returns a `herald_dict_provider` backed by the user-cached FDA SRS
#' table (written by [download_srs()]). Rule ops query it under the
#' name `"srs"`.
#'
#' @param version One of:
#'   \itemize{
#'     \item `"latest-cache"` (default) -- newest cached SRS entry.
#'     \item a `YYYY-MM-DD` string matching a prior `download_srs()`.
#'     \item an absolute `.rds` path.
#'   }
#'
#' @return A `herald_dict_provider` with name `"srs"`; returns NULL
#'   when the cache is empty -- op layer records a missing_ref with
#'   a hint pointing the user at `download_srs()`.
#'
#' @seealso [download_srs()], [register_dictionary()].
#' @family dict
#' @export
srs_provider <- function(version = "latest-cache") {
  call <- rlang::caller_env()
  path <- .resolve_srs_rds(version, call)
  if (is.null(path)) return(NULL)

  srs <- readRDS(path)
  n_rows <- nrow(srs)
  ver <- if (!is.null(attr(srs, "version"))) attr(srs, "version") else version

  contains_fn <- function(value, field = "preferred_name",
                          ignore_case = FALSE) {
    field <- as.character(field %||% "preferred_name")
    col <- switch(field,
                  "preferred_name" = "PT",
                  "pt"             = "PT",
                  "unii"           = "UNII",
                  "code"           = "UNII",
                  "PT")
    if (!col %in% names(srs)) return(rep(NA, length(value)))
    pool <- as.character(srs[[col]])
    v <- sub(" +$", "", as.character(value))
    if (isTRUE(ignore_case)) {
      return(toupper(v) %in% toupper(pool))
    }
    v %in% pool
  }

  lookup_fn <- function(value, field = "preferred_name") {
    field <- as.character(field %||% "preferred_name")
    col <- switch(field,
                  "preferred_name" = "PT", "pt" = "PT",
                  "unii" = "UNII", "code" = "UNII",
                  "PT")
    if (!col %in% names(srs)) return(NULL)
    hits <- srs[srs[[col]] %in% as.character(value), , drop = FALSE]
    if (nrow(hits) == 0L) return(NULL)
    hits
  }

  new_dict_provider(
    name         = "srs",
    version      = as.character(ver),
    source       = "cache",
    license      = "public",
    license_note = "FDA Substance Registration System (public; not bundled)",
    size_rows    = n_rows,
    fields       = c("preferred_name", "unii"),
    contains     = contains_fn,
    lookup       = lookup_fn
  )
}

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

#' Resolve (version) -> RDS path from the user cache.
#' Returns NULL when no SRS entries are cached.
#' @noRd
.resolve_srs_rds <- function(version, call) {
  if (grepl("\\.rds$", version, ignore.case = TRUE)) {
    if (!file.exists(version)) return(NULL)
    return(normalizePath(version, winslash = "/", mustWork = TRUE))
  }
  cached <- .list_cached_ct()
  cached <- cached[cached$package == "srs", , drop = FALSE]
  if (nrow(cached) == 0L) return(NULL)
  if (identical(version, "latest-cache")) {
    hit <- cached[order(cached$release_date, decreasing = TRUE)[1L], ]
  } else {
    hit <- cached[cached$version == version, , drop = FALSE]
    if (nrow(hit) == 0L) return(NULL)
    hit <- hit[1L, ]
  }
  hit$path
}

#' Parse the FDA SRS zipped tab-delimited distribution into a tibble.
#' Keeps only the columns rule ops need (UNII + PT) plus a couple of
#' identifier cross-walks that may be useful later (RN, NCIT, RXCUI).
#' @noRd
.parse_srs_zip <- function(path, version) {
  files <- utils::unzip(path, list = TRUE)
  txt <- files$Name[grepl("\\.txt$", files$Name, ignore.case = TRUE)][1L]
  if (is.na(txt)) {
    herald_error_runtime(
      "SRS download does not contain a .txt file (saw: {.val {files$Name}})."
    )
  }
  # Extract to a tempdir so read.delim can open / close the file
  # without the connection-leak risks of unz().
  ex_dir <- tempfile("srs-extract-")
  dir.create(ex_dir)
  on.exit(unlink(ex_dir, recursive = TRUE), add = TRUE)
  utils::unzip(path, files = txt, exdir = ex_dir, junkpaths = TRUE)
  ex_path <- file.path(ex_dir, basename(txt))

  raw <- utils::read.delim(ex_path, sep = "\t", quote = "",
                           stringsAsFactors = FALSE,
                           check.names = FALSE, na.strings = "",
                           fileEncoding = "UTF-8")
  keep <- intersect(c("UNII", "PT", "RN", "NCIT", "RXCUI",
                      "UNII_TYPE", "NAME_TYPE"),
                    names(raw))
  if (!all(c("UNII", "PT") %in% keep)) {
    herald_error_runtime(
      c("SRS file missing required columns UNII / PT.",
        "i" = "Got columns: {.val {names(raw)}}")
    )
  }
  out <- tibble::as_tibble(raw[, keep, drop = FALSE])
  attr(out, "version")     <- version
  attr(out, "source_url")  <- .SRS_URL
  attr(out, "release_date")<- version
  out
}
