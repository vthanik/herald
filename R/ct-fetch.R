# --------------------------------------------------------------------------
# ct-fetch.R -- available_ct_releases() + download_ct()
# --------------------------------------------------------------------------
# CDISC Controlled Terminology is published quarterly by NCI EVS as
# tab-delimited text under https://evs.nci.nih.gov/ftp1/CDISC/.
# herald fetches those files on demand and caches them under the
# user's R_user_dir so `load_ct(version = "YYYY-MM-DD")` can pick
# them up.
#
# NCI EVS URL template:
#   base    : https://evs.nci.nih.gov/ftp1/CDISC/<PACKAGE>/
#   current : <base><PACKAGE>%20Terminology.txt
#   archive : <base>Archive/<PACKAGE>%20Terminology%20<YYYY-MM-DD>.txt
#
# No auth required. Files are ~2 MB for SDTM, smaller for ADaM.

.NCI_EVS_BASE <- "https://evs.nci.nih.gov/ftp1/CDISC"

#' List available CDISC CT releases
#'
#' @description
#' Returns a tibble of CT releases visible to herald: the bundled one
#' shipped under `inst/rules/ct/`, plus everything in the user cache,
#' plus (when network is reachable) every archived quarterly release
#' listed on NCI EVS. Works offline -- missing columns become `NA`
#' rather than errors.
#'
#' @param package Character scalar, one of `"sdtm"`, `"adam"`,
#'   `"send"`. Defaults to `"sdtm"`.
#' @param include_remote Whether to query the NCI EVS archive index
#'   for historical releases. Defaults to `TRUE`. Set `FALSE` to
#'   stay strictly local (bundled + cache).
#' @param timeout Seconds for the remote listing fetch. Default 30.
#'
#' @return Tibble with columns
#'   \describe{
#'     \item{package}{`"sdtm"`, `"adam"`, or `"send"`.}
#'     \item{version}{Release date as `YYYY-MM-DD`, or `"bundled"`
#'       for the one shipped in the package.}
#'     \item{release_date}{Release date.}
#'     \item{url}{NCI EVS source URL, or `NA` for bundled-only.}
#'     \item{format}{`"txt"` (tab-delimited) -- always for fetched.}
#'     \item{source}{`"bundled"`, `"cache"`, or `"remote"`.}
#'   }
#'
#' @family ct
#' @export
available_ct_releases <- function(package = c("sdtm", "adam", "send"),
                                  include_remote = TRUE,
                                  timeout = 30L) {
  call <- rlang::caller_env()
  package <- match.arg(package)

  rows <- list()

  # Bundled (only for sdtm + adam currently)
  if (package %in% c("sdtm", "adam")) {
    m <- .bundled_ct_manifest()[[package]]
    if (!is.null(m)) {
      ver <- sub("^[a-z]+ct-", "", m$effective %||% "")
      rows[[length(rows) + 1L]] <- data.frame(
        package      = package,
        version      = if (nzchar(ver)) ver else "bundled",
        release_date = if (nzchar(ver)) ver else NA_character_,
        url          = NA_character_,
        format       = "rds",
        source       = "bundled",
        stringsAsFactors = FALSE
      )
    }
  }

  # Cache
  cached <- .list_cached_ct()
  cached <- cached[cached$package == package, , drop = FALSE]
  if (nrow(cached) > 0L) {
    rows[[length(rows) + 1L]] <- data.frame(
      package      = cached$package,
      version      = cached$version,
      release_date = cached$release_date,
      url          = rep(NA_character_, nrow(cached)),
      format       = rep("rds", nrow(cached)),
      source       = rep("cache", nrow(cached)),
      stringsAsFactors = FALSE
    )
  }

  # Remote (NCI EVS archive index)
  if (isTRUE(include_remote)) {
    remote <- tryCatch(
      .list_nci_evs_releases(package, timeout = timeout),
      error = function(e) {
        cli::cli_inform(c("i" = "NCI EVS listing unavailable: {conditionMessage(e)}"))
        NULL
      }
    )
    if (!is.null(remote) && nrow(remote) > 0L) {
      rows[[length(rows) + 1L]] <- remote
    }
  }

  if (length(rows) == 0L) {
    return(tibble::tibble(
      package = character(), version = character(),
      release_date = character(), url = character(),
      format = character(), source = character()
    ))
  }

  out <- do.call(rbind, rows)
  out <- out[order(out$source != "bundled",
                   is.na(out$release_date),
                   -rank(out$release_date)), , drop = FALSE]
  rownames(out) <- NULL
  tibble::as_tibble(out)
}

#' Download + cache a CDISC CT release from NCI EVS
#'
#' @description
#' Fetches the tab-delimited release from NCI EVS, parses it into the
#' herald CT schema (a named list of codelists keyed by submission
#' short name), writes the result to `<dest>/<package>-ct-<version>.rds`,
#' and updates the cache manifest. Idempotent: returns the existing
#' path if the file already exists and `!force`.
#'
#' @param package One of `"sdtm"`, `"adam"`, `"send"`.
#' @param version Release identifier. Either `"latest"` or a
#'   `YYYY-MM-DD` date matching an NCI EVS archive entry.
#' @param dest Target directory. Defaults to the user CT cache
#'   (`tools::R_user_dir("herald","cache")`). Maintainers pass
#'   `"inst/rules/ct"` to refresh the bundled files.
#' @param force Re-download even when the target file exists.
#' @param timeout Seconds for `utils::download.file()`. Default 120.
#' @param quiet Suppress progress output.
#'
#' @return The path to the generated RDS, invisibly.
#'
#' @family ct
#' @export
download_ct <- function(package = c("sdtm", "adam", "send"),
                        version = "latest",
                        dest    = .ct_cache_dir(),
                        force   = FALSE,
                        timeout = 120L,
                        quiet   = FALSE) {
  call <- rlang::caller_env()
  package <- match.arg(package)
  check_scalar_chr(version, call = call)
  check_scalar_chr(dest, call = call)
  if (!dir.exists(dest)) dir.create(dest, recursive = TRUE)

  url_info <- .nci_evs_url_for(package, version, timeout = timeout)
  rds_path <- file.path(dest, sprintf("%s-ct-%s.rds", package,
                                      url_info$release_date))

  if (file.exists(rds_path) && !isTRUE(force)) {
    if (!isTRUE(quiet)) {
      cli::cli_inform(c("v" = "Using cached {.path {rds_path}}"))
    }
    return(invisible(rds_path))
  }

  tmp <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp), add = TRUE)

  if (!isTRUE(quiet)) {
    cli::cli_inform(c("i" = "Downloading {.url {url_info$url}}"))
  }
  old_timeout <- getOption("timeout")
  on.exit(options(timeout = old_timeout), add = TRUE)
  options(timeout = max(timeout, old_timeout))
  utils::download.file(url_info$url, tmp, mode = "wb", quiet = quiet)

  ct <- .parse_nci_evs_txt(tmp, package = package,
                           release_date = url_info$release_date,
                           source_url = url_info$url)
  saveRDS(ct, rds_path, compress = "xz")
  n_codelists <- length(ct)
  n_terms <- sum(vapply(ct, function(e) nrow(e$terms %||% data.frame()),
                        integer(1L)))
  if (!isTRUE(quiet)) {
    cli::cli_inform(c(
      "v" = "Saved {.path {rds_path}} ({n_codelists} codelists, {n_terms} terms)"
    ))
  }

  if (.normalise_path(dest) != .normalise_path(.ct_cache_dir(create = FALSE))) {
    return(invisible(rds_path))
  }
  .ct_cache_write(list(
    package       = package,
    version       = url_info$release_date,
    release_date  = url_info$release_date,
    path          = rds_path,
    downloaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  ), dir = dest)
  invisible(rds_path)
}

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

.normalise_path <- function(p) normalizePath(p, winslash = "/", mustWork = FALSE)

#' Resolve (package, version) to an NCI EVS URL + release date.
#' @noRd
.nci_evs_url_for <- function(package, version, timeout) {
  base <- .nci_evs_index_for(package)
  if (identical(version, "latest")) {
    rel <- .nci_evs_latest_release(package, timeout = timeout)
    return(list(
      url = sprintf("%s/Archive/%s%%20Terminology%%20%s.txt",
                    base, toupper(package), rel),
      release_date = rel
    ))
  }
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", version)) {
    cli::cli_abort(
      c("{.arg version} must be {.val latest} or a {.val YYYY-MM-DD} date.",
        "x" = "Got {.val {version}}."),
      class = "herald_error_input"
    )
  }
  list(
    url = sprintf("%s/Archive/%s%%20Terminology%%20%s.txt",
                  base, toupper(package), version),
    release_date = version
  )
}

#' Per-package NCI EVS URL base.
#' @noRd
.nci_evs_index_for <- function(package) {
  paste0(.NCI_EVS_BASE, "/", toupper(package))
}

#' Fetch the directory listing from NCI EVS and pull every
#' `<PACKAGE> Terminology YYYY-MM-DD.txt` filename out of it.
#' @noRd
.list_nci_evs_releases <- function(package, timeout = 30L) {
  base <- .nci_evs_index_for(package)
  url  <- paste0(base, "/Archive/")
  tmp  <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)
  old_timeout <- getOption("timeout")
  on.exit(options(timeout = old_timeout), add = TRUE)
  options(timeout = max(timeout, old_timeout))
  utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  rx <- sprintf("%s%%20Terminology%%20([0-9]{4}-[0-9]{2}-[0-9]{2})\\.txt",
                toupper(package))
  m <- regmatches(html, gregexpr(rx, html, perl = TRUE))[[1L]]
  if (length(m) == 0L) {
    return(tibble::tibble(
      package = character(), version = character(),
      release_date = character(), url = character(),
      format = character(), source = character()
    ))
  }
  dates <- regmatches(m, regexpr("[0-9]{4}-[0-9]{2}-[0-9]{2}", m))
  dates <- unique(sort(dates, decreasing = TRUE))
  data.frame(
    package      = rep(package, length(dates)),
    version      = dates,
    release_date = dates,
    url          = sprintf("%s/Archive/%s%%20Terminology%%20%s.txt",
                           base, toupper(package), dates),
    format       = rep("txt", length(dates)),
    source       = rep("remote", length(dates)),
    stringsAsFactors = FALSE
  )
}

#' Fetch `latest` by scraping the archive index (latest by date).
#' @noRd
.nci_evs_latest_release <- function(package, timeout = 30L) {
  releases <- .list_nci_evs_releases(package, timeout = timeout)
  if (nrow(releases) == 0L) {
    cli::cli_abort(
      "Could not discover the latest {.pkg {package}} CT release from NCI EVS.",
      class = "herald_error_runtime"
    )
  }
  releases$release_date[[1L]]
}

#' Parse an NCI EVS tab-delimited CT file into the herald schema.
#'
#' Handles the standard NCI EVS columns (Code, Codelist Code, Codelist
#' Extensible (Yes/No), Codelist Name, CDISC Submission Value, CDISC
#' Synonym(s), CDISC Definition, NCI Preferred Term). Codelist headers
#' appear as rows where `Codelist Code` equals the row's own `Code`;
#' term rows carry the parent codelist's code.
#' @noRd
.parse_nci_evs_txt <- function(path, package, release_date, source_url) {
  raw <- utils::read.delim(
    path, sep = "\t", quote = "", stringsAsFactors = FALSE,
    check.names = FALSE, na.strings = "", encoding = "UTF-8"
  )
  want <- c(
    code        = "Code",
    clist_code  = "Codelist Code",
    extensible  = "Codelist Extensible (Yes/No)",
    clist_name  = "Codelist Name",
    submission  = "CDISC Submission Value",
    synonyms    = "CDISC Synonym(s)",
    preferred   = "NCI Preferred Term",
    definition  = "CDISC Definition"
  )
  missing <- want[!want %in% names(raw)]
  if (length(missing) > 0L) {
    cli::cli_abort(
      c("NCI EVS file is missing expected column{?s}: {.val {unname(missing)}}",
        "i" = "Parsed columns: {.val {names(raw)}}"),
      class = "herald_error_runtime"
    )
  }
  df <- data.frame(
    code       = raw[[want[["code"]]]],
    clist_code = raw[[want[["clist_code"]]]],
    extensible = toupper(raw[[want[["extensible"]]]]) == "YES",
    clist_name = raw[[want[["clist_name"]]]],
    submission = raw[[want[["submission"]]]],
    synonyms   = raw[[want[["synonyms"]]]],
    preferred  = raw[[want[["preferred"]]]],
    definition = raw[[want[["definition"]]]],
    stringsAsFactors = FALSE
  )

  # Header rows have `Codelist Code` empty (NCI EVS convention) OR
  # equal to `Code`. Use the first as the definitive signal.
  is_header <- is.na(df$clist_code) | !nzchar(df$clist_code)
  headers <- df[is_header, , drop = FALSE]
  terms   <- df[!is_header, , drop = FALSE]

  out <- vector("list", nrow(headers))
  names(out) <- headers$submission

  for (i in seq_len(nrow(headers))) {
    h <- headers[i, ]
    tm <- terms[terms$clist_code == h$code, , drop = FALSE]
    out[[h$submission]] <- list(
      codelist_code = h$code,
      codelist_name = h$clist_name,
      extensible    = isTRUE(h$extensible),
      terms         = data.frame(
        submissionValue = tm$submission,
        conceptId       = tm$code,
        preferredTerm   = tm$preferred,
        stringsAsFactors = FALSE
      )
    )
  }

  attr(out, "package")      <- package
  attr(out, "version")      <- release_date
  attr(out, "release_date") <- release_date
  attr(out, "source_url")   <- source_url
  out
}
