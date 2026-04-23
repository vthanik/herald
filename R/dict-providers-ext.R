# --------------------------------------------------------------------------
# dict-providers-ext.R -- provider factories for external / licensed
# dictionaries: MedDRA, WHO-Drug.
# --------------------------------------------------------------------------
# These dictionaries are licensed (MSSO for MedDRA, UMC for
# WHO-Drug). herald NEVER ships the data. Users with valid licences
# point the factory at their local distribution; herald parses the
# file(s) into an in-memory provider.

# --------------------------------------------------------------------------
# MedDRA
# --------------------------------------------------------------------------
# Distribution: MSSO ships MedDRA as a directory of `$`-delimited
# ASCII files named by level:
#   mdhier.asc   -- hierarchy: pt -> hlt -> hlgt -> soc
#   llt.asc      -- lowest-level terms (mapped to a pt)
#   pt.asc       -- preferred terms
#   hlt.asc / hlgt.asc / soc.asc  -- level files
#
# For herald's rule corpus we need membership lookup at any level,
# so the factory reads `mdhier.asc` (contains pt + hlt + hlgt + soc
# columns in one row) and optionally `llt.asc` for the LLT level.
# Docs: https://www.meddra.org/how-to-use/basics/hierarchy

#' MedDRA as a Dictionary Provider
#'
#' @description
#' Reads an MSSO MedDRA ASCII distribution from `path` and returns a
#' `herald_dict_provider`. Supports membership checks at any level:
#' `"llt"`, `"pt"`, `"hlt"`, `"hlgt"`, `"soc"`. Since MedDRA is
#' licensed, herald never bundles the data -- the user must supply a
#' valid local distribution.
#'
#' @param path Directory containing the MedDRA ASCII files OR a direct
#'   path to `mdhier.asc`. When a directory is given, the factory
#'   looks for `mdhier.asc` (required) and `llt.asc` (optional).
#' @param version MedDRA release tag (e.g. `"27.0"`). User-supplied;
#'   MedDRA files don't self-identify. Defaults to `"unknown"`.
#'
#' @return A `herald_dict_provider` with name `"meddra"`.
#'
#' @examples
#' \dontrun{
#' p <- meddra_provider("/path/to/meddra_27_0/MedAscii",
#'                      version = "27.0")
#' p$contains("Headache", field = "pt")
#' register_dictionary("meddra", p)
#' }
#'
#' @seealso [register_dictionary()], [whodrug_provider()].
#' @family dict
#' @export
meddra_provider <- function(path, version = "unknown") {
  call <- rlang::caller_env()
  check_scalar_chr(path, call = call)
  check_scalar_chr(version, call = call)

  files <- .meddra_resolve_files(path, call)
  hier <- .parse_meddra_mdhier(files$mdhier)
  llt  <- if (!is.null(files$llt)) .parse_meddra_llt(files$llt) else NULL

  pool <- list(
    pt   = unique(hier$pt_name),
    hlt  = unique(hier$hlt_name),
    hlgt = unique(hier$hlgt_name),
    soc  = unique(hier$soc_name)
  )
  if (!is.null(llt)) pool$llt <- unique(llt$llt_name)

  n_rows <- nrow(hier) + if (!is.null(llt)) nrow(llt) else 0L

  contains_fn <- function(value, field = "pt", ignore_case = FALSE) {
    field <- as.character(field %||% "pt")
    if (!(field %in% names(pool))) return(rep(NA, length(value)))
    v <- sub(" +$", "", as.character(value))
    p <- pool[[field]]
    if (isTRUE(ignore_case)) {
      return(toupper(v) %in% toupper(p))
    }
    v %in% p
  }

  lookup_fn <- function(value, field = "pt") {
    if (field == "llt" && !is.null(llt)) {
      return(llt[llt$llt_name %in% as.character(value), , drop = FALSE])
    }
    col <- switch(field,
      pt = "pt_name", hlt = "hlt_name",
      hlgt = "hlgt_name", soc = "soc_name",
      NULL
    )
    if (is.null(col)) return(NULL)
    hits <- hier[hier[[col]] %in% as.character(value), , drop = FALSE]
    if (nrow(hits) == 0L) return(NULL)
    hits
  }

  new_dict_provider(
    name         = "meddra",
    version      = version,
    source       = "user-file",
    license      = "MSSO",
    license_note = "User-supplied MedDRA distribution (MSSO licensed; not bundled).",
    size_rows    = as.integer(n_rows),
    fields       = names(pool),
    contains     = contains_fn,
    lookup       = lookup_fn
  )
}

#' Resolve the MedDRA ASCII files under `path`. Accepts either a
#' directory containing the standard files or a direct mdhier.asc
#' path. Returns a named list(mdhier = <path>, llt = <path_or_NULL>).
#' @noRd
.meddra_resolve_files <- function(path, call) {
  if (!file.exists(path)) {
    herald_error(
      "MedDRA path {.path {path}} does not exist.",
      class = "herald_error_input", call = call
    )
  }
  if (dir.exists(path)) {
    hier_path <- .find_case_insensitive(path, "mdhier.asc")
    llt_path  <- .find_case_insensitive(path, "llt.asc")
    if (is.na(hier_path)) {
      herald_error(
        "MedDRA directory {.path {path}} is missing {.file mdhier.asc}.",
        class = "herald_error_input", call = call
      )
    }
    list(mdhier = hier_path,
         llt    = if (is.na(llt_path)) NULL else llt_path)
  } else {
    list(mdhier = path, llt = NULL)
  }
}

#' @noRd
.find_case_insensitive <- function(dir, filename) {
  files <- list.files(dir, full.names = TRUE)
  target <- tolower(filename)
  hit <- files[tolower(basename(files)) == target]
  if (length(hit) == 0L) return(NA_character_)
  hit[[1L]]
}

#' Parse mdhier.asc. Columns (per MedDRA docs):
#'   pt_code | hlt_code | hlgt_code | soc_code |
#'   pt_name | hlt_name | hlgt_name | soc_name |
#'   soc_abbrev | null | pt_soc_code | primary_soc_fg | null
#' Field separator is `$`. No header row.
#' @noRd
.parse_meddra_mdhier <- function(path) {
  col_names <- c(
    "pt_code", "hlt_code", "hlgt_code", "soc_code",
    "pt_name", "hlt_name", "hlgt_name", "soc_name",
    "soc_abbrev", "null1", "pt_soc_code", "primary_soc_fg", "null2"
  )
  raw <- utils::read.delim(
    path, sep = "$", header = FALSE, quote = "",
    stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = "", fileEncoding = "UTF-8"
  )
  # MedDRA files end each row with a trailing $ producing an extra
  # empty column; truncate to the known column count.
  keep <- min(length(col_names), ncol(raw))
  out <- raw[, seq_len(keep), drop = FALSE]
  names(out) <- col_names[seq_len(keep)]
  tibble::as_tibble(out)
}

#' Parse llt.asc. Columns (per MedDRA docs):
#'   llt_code | llt_name | pt_code | llt_whoart_code | llt_harts_code |
#'   llt_costart_sym | llt_icd9_code | llt_icd9cm_code | llt_icd10_code |
#'   llt_currency | llt_jart_code | null
#' @noRd
.parse_meddra_llt <- function(path) {
  col_names <- c(
    "llt_code", "llt_name", "pt_code", "llt_whoart_code",
    "llt_harts_code", "llt_costart_sym", "llt_icd9_code",
    "llt_icd9cm_code", "llt_icd10_code", "llt_currency",
    "llt_jart_code", "null1"
  )
  raw <- utils::read.delim(
    path, sep = "$", header = FALSE, quote = "",
    stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = "", fileEncoding = "UTF-8"
  )
  keep <- min(length(col_names), ncol(raw))
  out <- raw[, seq_len(keep), drop = FALSE]
  names(out) <- col_names[seq_len(keep)]
  tibble::as_tibble(out)
}

# --------------------------------------------------------------------------
# WHO-Drug (B3 format)
# --------------------------------------------------------------------------
# The UMC ships WHO-Drug in the B3 format: fixed-width ASCII files,
# comma-delimited variants, and multiple levels. For herald's needs
# we only require drug-name membership lookup, which lives in DD.txt
# (Drug Dictionary records, colon-delimited key fields) plus DDA.txt
# (alternate drug names).
#
# Field-layout doc: UMC "WHO-Drug Dictionary B3 format" technical
# specification (shipped with each WHO-Drug release).

#' WHO-Drug as a Dictionary Provider
#'
#' @description
#' Reads a UMC WHO-Drug B3 distribution from `path` and returns a
#' `herald_dict_provider` serving drug-name membership checks. Since
#' WHO-Drug is licensed, herald never bundles the data.
#'
#' @param path Directory containing the B3 distribution. Looks for
#'   `DD.txt` (required) and `DDA.txt` (optional alternate names).
#' @param version WHO-Drug release tag (e.g. `"2026-Mar-01"`).
#'   User-supplied.
#' @param format Currently only `"b3"` is supported; placeholder for
#'   future C3 support.
#'
#' @return A `herald_dict_provider` with name `"whodrug"`.
#'
#' @seealso [register_dictionary()], [meddra_provider()].
#' @family dict
#' @export
whodrug_provider <- function(path, version = "unknown", format = "b3") {
  call <- rlang::caller_env()
  check_scalar_chr(path, call = call)
  check_scalar_chr(version, call = call)
  check_scalar_chr(format, call = call)
  if (!identical(tolower(format), "b3")) {
    herald_error(
      "Only WHO-Drug format {.val b3} is supported right now.",
      class = "herald_error_input", call = call
    )
  }

  if (!dir.exists(path)) {
    herald_error(
      "WHO-Drug directory {.path {path}} does not exist.",
      class = "herald_error_input", call = call
    )
  }
  dd_path  <- .find_case_insensitive(path, "DD.txt")
  dda_path <- .find_case_insensitive(path, "DDA.txt")
  if (is.na(dd_path)) {
    herald_error(
      "WHO-Drug directory {.path {path}} is missing {.file DD.txt}.",
      class = "herald_error_input", call = call
    )
  }

  dd  <- .parse_whodrug_dd(dd_path)
  dda <- if (!is.na(dda_path)) .parse_whodrug_dda(dda_path) else NULL

  pool <- list(
    drug_name           = unique(dd$drug_name),
    drug_record_number  = unique(dd$drug_record_number)
  )
  if (!is.null(dda)) pool$alternate_name <- unique(dda$drug_name)

  n_rows <- nrow(dd) + if (!is.null(dda)) nrow(dda) else 0L

  contains_fn <- function(value, field = "drug_name", ignore_case = FALSE) {
    field <- as.character(field %||% "drug_name")
    if (!(field %in% names(pool))) return(rep(NA, length(value)))
    v <- sub(" +$", "", as.character(value))
    p <- pool[[field]]
    if (isTRUE(ignore_case)) {
      return(toupper(v) %in% toupper(p))
    }
    v %in% p
  }

  lookup_fn <- function(value, field = "drug_name") {
    col <- switch(field,
      drug_name          = "drug_name",
      drug_record_number = "drug_record_number",
      NULL
    )
    if (is.null(col)) return(NULL)
    hits <- dd[dd[[col]] %in% as.character(value), , drop = FALSE]
    if (nrow(hits) == 0L) return(NULL)
    hits
  }

  new_dict_provider(
    name         = "whodrug",
    version      = version,
    source       = "user-file",
    license      = "UMC",
    license_note = "User-supplied WHO-Drug distribution (UMC licensed; not bundled).",
    size_rows    = as.integer(n_rows),
    fields       = names(pool),
    contains     = contains_fn,
    lookup       = lookup_fn
  )
}

#' Parse DD.txt (WHO-Drug B3 Drug Dictionary). Key columns (per UMC
#' B3 spec): drug_record_number (positions 1-6), drug_name (7-1506),
#' atc_code (when present) -- we keep a pragmatic subset that covers
#' the membership-check use case.
#' Fixed-width record layout.
#' @noRd
.parse_whodrug_dd <- function(path) {
  # The B3 DD record is 1506 chars wide. For herald we only need the
  # record number + drug name. Use read.fwf for portability.
  widths <- c(6, 1, 1, 1500)
  col_names <- c("drug_record_number", "sequence1",
                 "sequence2", "drug_name")
  raw <- utils::read.fwf(
    path, widths = widths, header = FALSE,
    strip.white = TRUE, stringsAsFactors = FALSE,
    colClasses = "character", fileEncoding = "UTF-8",
    comment.char = ""
  )
  names(raw) <- col_names
  tibble::as_tibble(raw[, c("drug_record_number", "drug_name"),
                         drop = FALSE])
}

#' Parse DDA.txt (alternate drug names). Record layout: same leading
#' key columns plus the alternate name in positions 10-1509.
#' @noRd
.parse_whodrug_dda <- function(path) {
  widths <- c(6, 3, 1500)
  col_names <- c("drug_record_number", "sequence", "drug_name")
  raw <- utils::read.fwf(
    path, widths = widths, header = FALSE,
    strip.white = TRUE, stringsAsFactors = FALSE,
    colClasses = "character", fileEncoding = "UTF-8",
    comment.char = ""
  )
  names(raw) <- col_names
  tibble::as_tibble(raw[, c("drug_record_number", "drug_name"),
                         drop = FALSE])
}
