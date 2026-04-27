# --------------------------------------------------------------------------
# study-discover.R -- folder scanning and standard auto-detection
# --------------------------------------------------------------------------

#' Scan a folder for dataset files
#'
#' Finds all .xpt and .json dataset files in a directory (non-recursive).
#'
#' @param path Directory path.
#' @param call Caller environment for errors.
#' @return Named list with `xpt_files` and `json_files` character vectors.
#' @noRd
scan_folder_datasets <- function(path, call = rlang::caller_env()) {
  if (!dir.exists(path)) {
    herald_error_io(
      "Directory {.path {path}} does not exist.",
      path = path,
      call = call
    )
  }

  xpt_files <- list.files(path, pattern = "\\.(xpt|XPT)$", full.names = TRUE)
  json_files <- list.files(path, pattern = "\\.(json|JSON)$", full.names = TRUE)

  # Filter JSON files to only Dataset-JSON (not spec files)
  # Dataset-JSON files contain "datasetJSONVersion" or "clinicalData"
  if (length(json_files) > 0L && requireNamespace("jsonlite", quietly = TRUE)) {
    is_dataset_json <- vapply(
      json_files,
      function(f) {
        first_line <- readLines(f, n = 5L, warn = FALSE)
        any(grepl(
          "datasetJSONVersion|clinicalData|referenceData",
          paste(first_line, collapse = " ")
        ))
      },
      logical(1)
    )
    json_files <- json_files[is_dataset_json]
  }

  list(
    xpt_files = xpt_files,
    json_files = json_files
  )
}

#' Load datasets from a folder with format + name filtering
#'
#' Like load_folder_datasets() but restricted to one file format and an
#' optional allowlist of dataset names (case-insensitive stem match).
#'
#' @param path Directory path.
#' @param datasets Character vector of dataset names to load, or NULL for all.
#' @param format "xpt" or "json".
#' @param call Caller environment for errors.
#' @return Named list of data frames (names = uppercase dataset names).
#' @noRd
load_folder_datasets_filtered <- function(
  path,
  datasets = NULL,
  format = "xpt",
  call = rlang::caller_env()
) {
  format <- match.arg(format, c("xpt", "json"))
  found <- scan_folder_datasets(path, call = call)

  candidate_files <- if (format == "xpt") found$xpt_files else found$json_files

  if (length(candidate_files) == 0L) {
    herald_error_io(
      "No .{format} files found in {.path {path}}.",
      path = path,
      call = call
    )
  }

  file_stems <- toupper(tools::file_path_sans_ext(basename(candidate_files)))

  # Filter by requested dataset names (case-insensitive)
  if (!is.null(datasets)) {
    requested <- toupper(datasets)
    missing_ds <- setdiff(requested, file_stems)
    if (length(missing_ds) > 0L) {
      herald_error_io(
        c(
          "Dataset(s) not found as .{format} file(s) in {.path {path}}:",
          "x" = "{.val {missing_ds}}",
          "i" = "Available: {.val {file_stems}}"
        ),
        path = path,
        call = call
      )
    }
    keep <- file_stems %in% requested
    candidate_files <- candidate_files[keep]
    file_stems <- file_stems[keep]
  }

  result <- vector("list", length(candidate_files))
  names(result) <- file_stems

  for (i in seq_along(candidate_files)) {
    f <- candidate_files[i]
    if (format == "xpt") {
      result[[i]] <- read_xpt(f)
    } else {
      data <- read_json(f)
      actual_name <- attr(data, "dataset_name") %||% file_stems[i]
      names(result)[i] <- actual_name
      result[[i]] <- data
    }
  }

  result
}

#' Load all datasets from a folder
#'
#' Reads all XPT and Dataset-JSON files from a directory into a named list.
#'
#' @param path Directory path.
#' @param call Caller environment for errors.
#' @return Named list of data frames (names = uppercase dataset names).
#' @noRd
load_folder_datasets <- function(path, call = rlang::caller_env()) {
  found <- scan_folder_datasets(path, call = call)
  all_files <- c(found$xpt_files, found$json_files)

  if (length(all_files) == 0L) {
    herald_error_io(
      "No dataset files (.xpt, .json) found in {.path {path}}.",
      path = path,
      call = call
    )
  }

  datasets <- list()

  for (f in found$xpt_files) {
    ds_name <- toupper(tools::file_path_sans_ext(basename(f)))
    datasets[[ds_name]] <- read_xpt(f)
  }

  for (f in found$json_files) {
    data <- read_json(f)
    ds_name <- attr(data, "dataset_name") %||%
      toupper(tools::file_path_sans_ext(basename(f)))
    datasets[[ds_name]] <- data
  }

  datasets
}

#' Auto-detect clinical data standard from dataset names
#'
#' @param names Character vector of dataset names.
#' @return One of \code{"adam"}, \code{"sdtm"}, \code{"send"}, or \code{"unknown"}.
#' @noRd
detect_standard <- function(names) {
  names <- toupper(names)

  # ADaM: contains ADSL or AD-prefixed datasets
  adam_patterns <- c(
    "ADSL",
    "ADAE",
    "ADTTE",
    "ADLB",
    "ADVS",
    "ADEG",
    "ADCM",
    "ADEX",
    "ADMH",
    "ADEFF"
  )
  if (any(names %in% adam_patterns) || any(startsWith(names, "AD"))) {
    return("adam")
  }

  # SEND: contains TS, TX, BW, etc. (nonclinical)
  send_patterns <- c(
    "TS",
    "TX",
    "BW",
    "CL",
    "FW",
    "MA",
    "MI",
    "OM",
    "PM",
    "TF",
    "BG",
    "SC"
  )
  if (sum(names %in% send_patterns) >= 2L) {
    return("send")
  }

  # SDTM: contains DM, AE, LB, etc.
  sdtm_patterns <- c(
    "DM",
    "AE",
    "LB",
    "VS",
    "EX",
    "CM",
    "MH",
    "DS",
    "SV",
    "SE",
    "TA",
    "TE",
    "TI",
    "TV",
    "TS"
  )
  if (any(names %in% sdtm_patterns)) {
    return("sdtm")
  }

  "unknown"
}

# --------------------------------------------------------------------------
# ADaM class detection  --  variable-signature approach
# --------------------------------------------------------------------------

#' Detect the ADaM dataset class from column names
#'
#' @description
#' Infers the ADaM dataset class from the variables present in a dataset or
#' spec. Uses variable signatures rather than dataset name conventions so it
#' works across companies that name their ADaM datasets differently.
#'
#' Classes returned:
#' \describe{
#'   \item{ADSL}{Subject-level: one row per subject, no PARAMCD/AVAL.}
#'   \item{BDS}{Basic Data Structure: PARAMCD + AVAL present. Includes lab,
#'     vitals, ECG, exposure, and similar parameter-based datasets.}
#'   \item{TTE}{Time-to-event: BDS signature plus CNSR (censoring indicator).}
#'   \item{OCCDS}{Occurrence Data Structure: occurrence-based without a
#'     numeric AVAL parameter spine; e.g. AE, CM, MH, CE.}
#'   \item{unknown}{Insufficient variables to determine class.}
#' }
#'
#' @param vars Character vector of variable names (uppercase). Can be column
#'   names from a data frame or the \code{variable} column from a spec.
#'
#' @return A single character string: one of \code{"ADSL"}, \code{"BDS"},
#'   \code{"TTE"}, \code{"OCCDS"}, or \code{"unknown"}.
#'
#' @details
#' \strong{Signature rules (evaluated in order):}
#' \enumerate{
#'   \item \strong{TTE}: PARAMCD + AVAL + CNSR all present.
#'   \item \strong{BDS}: PARAMCD + AVAL present (without CNSR).
#'   \item \strong{ADSL}: USUBJID present, no PARAMCD, no AVAL, no
#'     occurrence-flag pattern.
#'   \item \strong{OCCDS}: USUBJID present + either (a) a term variable
#'     (*TERM, *DECOD, *DOSE) or (b) at least two occurrence flag variables
#'     matching \code{*FL} but no PARAMCD.
#'   \item \strong{unknown}: none of the above.
#' }
#'
#' @examples
#' adsl <- readRDS(system.file("extdata", "adsl.rds", package = "herald"))
#' advs <- readRDS(system.file("extdata", "advs.rds", package = "herald"))
#' adae <- readRDS(system.file("extdata", "adae.rds", package = "herald"))
#'
#' # ---- Infer class from column names of existing data frames -----------
#' detect_adam_class(names(adsl))  # "ADSL"
#' detect_adam_class(names(advs))  # "BDS"
#' detect_adam_class(names(adae))  # "OCCDS"
#'
#' # ---- TTE class requires PARAMCD + AVAL + CNSR ------------------------
#' detect_adam_class(c("USUBJID", "PARAMCD", "AVAL", "CNSR", "EVDTM"))
#'
#' # ---- Explicit character vector (e.g. from a spec variable list) ------
#' detect_adam_class(c("USUBJID", "SAFFL", "ITTFL", "TRTP", "AGE"))  # "ADSL"
#' detect_adam_class(c("USUBJID", "PARAMCD", "AVAL", "AVISITN"))    # "BDS"
#'
#' # ---- Unknown when no identifying variables are present ---------------
#' detect_adam_class(c("X", "Y", "Z"))  # "unknown"
#'
#' @family adam
#' @export
detect_adam_class <- function(vars) {
  vars <- toupper(vars)

  has_paramcd <- "PARAMCD" %in% vars
  has_aval <- "AVAL" %in% vars || "AVALC" %in% vars # numeric or character result
  has_cnsr <- "CNSR" %in% vars
  has_usubjid <- "USUBJID" %in% vars

  # 1. TTE: BDS + censoring indicator
  if (has_paramcd && has_aval && has_cnsr) {
    return("TTE")
  }

  # 2. BDS: parameter spine present (PARAMCD + AVAL or AVALC)
  if (has_paramcd && has_aval) {
    return("BDS")
  }

  # 3. Without a parameter spine, distinguish ADSL from OCCDS.
  #    ADSL has population/analysis flags (SAFFL, ITTFL, PPROTFL) but no
  #    domain-specific term or occurrence variables.
  #    OCCDS is identified by:
  #      a) term/decode variables (AETERM, AEDECOD, CMDECOD, MHDECOD, ...)
  #      b) occurrence-specific flags: AOC*FL, TRTEMFL, or any *EMFL pattern
  if (has_usubjid && !has_paramcd && !has_aval) {
    term_vars <- grep("TERM$|DECOD$", vars, value = TRUE)
    occ_flags <- grep("^AOC|TRTEMFL|EMFL$", vars, perl = TRUE, value = TRUE)
    if (length(term_vars) > 0L || length(occ_flags) > 0L) {
      return("OCCDS")
    }
    return("ADSL")
  }

  "unknown"
}

#' Detect ADaM class for each dataset
#'
#' Applies \code{\link{detect_adam_class}} to every dataset. Pass data frames
#' as bare variables (names inferred from symbols), as a named list, or as a
#' \code{herald_spec}.
#'
#' @param ... One or more data frames (names inferred from variable symbols or
#'   provided explicitly, e.g. \code{ADSL = adsl}), a single named list of
#'   data frames, or a single \code{herald_spec} object.
#' @param call Caller environment for error reporting.
#' @return A named character vector mapping dataset name to ADaM class.
#'
#' @examples
#' adsl <- readRDS(system.file("extdata", "adsl.rds", package = "herald"))
#' advs <- readRDS(system.file("extdata", "advs.rds", package = "herald"))
#' adae <- readRDS(system.file("extdata", "adae.rds", package = "herald"))
#'
#' # ---- Bare variable names -- dataset names inferred from symbols ------
#' detect_adam_classes(adsl, advs, adae)
#'
#' # ---- Explicit names when variable symbols differ from domain names ----
#' detect_adam_classes(ADSL = adsl, ADVS = advs, ADAE = adae)
#'
#' # ---- Named list of data frames ---------------------------------------
#' datasets <- list(ADSL = adsl, ADVS = advs, ADAE = adae)
#' detect_adam_classes(datasets)
#'
#' # ---- herald_spec -- reads variable names from var_spec$variable ------
#' spec <- as_herald_spec(
#'   ds_spec  = data.frame(dataset = c("ADSL", "ADVS"), stringsAsFactors = FALSE),
#'   var_spec = data.frame(
#'     dataset  = c(rep("ADSL", ncol(adsl)), rep("ADVS", ncol(advs))),
#'     variable = c(names(adsl), names(advs)),
#'     stringsAsFactors = FALSE
#'   )
#' )
#' detect_adam_classes(spec)
#'
#' @family adam
#' @export
detect_adam_classes <- function(..., call = rlang::caller_env()) {
  exprs <- rlang::enexprs(...)
  vals <- list(...)

  # Single herald_spec or named list passed as the only argument
  if (
    length(vals) == 1L &&
      (inherits(vals[[1L]], "herald_spec") ||
        (is.list(vals[[1L]]) && !is.data.frame(vals[[1L]])))
  ) {
    x <- vals[[1L]]
    if (inherits(x, "herald_spec")) {
      vs <- x$var_spec
      if (is.null(vs) || !"dataset" %in% names(vs)) {
        return(character(0L))
      }
      datasets <- unique(vs[["dataset"]])
      return(vapply(
        datasets,
        function(ds) {
          detect_adam_class(vs[vs[["dataset"]] == ds, "variable"])
        },
        character(1L)
      ))
    }
    if (is.list(x) && !is.null(names(x))) {
      return(vapply(
        names(x),
        function(nm) detect_adam_class(names(x[[nm]])),
        character(1L)
      ))
    }
  }

  # One or more data frames passed directly (bare or named)
  nms <- names(vals)
  if (is.null(nms)) {
    nms <- character(length(vals))
  }
  for (i in seq_along(vals)) {
    if (!nzchar(nms[[i]]) && is.symbol(exprs[[i]])) {
      nms[[i]] <- toupper(as.character(exprs[[i]]))
    }
    if (!nzchar(nms[[i]])) nms[[i]] <- paste0("DATA", i)
  }
  names(vals) <- nms

  if (length(vals) > 0L && all(vapply(vals, is.data.frame, logical(1L)))) {
    return(vapply(
      nms,
      function(nm) detect_adam_class(names(vals[[nm]])),
      character(1L)
    ))
  }

  herald_error_io(
    "Pass data frames, a named list of data frames, or a {.cls herald_spec}.",
    call = call
  )
}

#' Extract standard from spec metadata
#'
#' Reads the `standard` column from `spec$ds_spec` and parses values like
#' "ADaMIG 1.1" to "adam", "SDTMIG 3.3" to "sdtm", "SENDIG 3.1" to "send".
#'
#' @param spec A `herald_spec` object, or NULL.
#' @return One of `"adam"`, `"sdtm"`, `"send"`, or `NULL` if not determinable.
#' @noRd
extract_standard_from_spec <- function(spec) {
  if (
    is.null(spec) ||
      is.null(spec$ds_spec) ||
      !"standard" %in% names(spec$ds_spec)
  ) {
    return(NULL)
  }
  standards <- unique(stats::na.omit(spec$ds_spec[["standard"]]))
  standards <- standards[nzchar(standards)]
  if (length(standards) == 0L) {
    return(NULL)
  }
  std <- tolower(standards[1L])
  if (grepl("adam", std)) {
    return("adam")
  }
  if (grepl("sdtm", std)) {
    return("sdtm")
  }
  if (grepl("send", std)) {
    return("send")
  }
  NULL
}
