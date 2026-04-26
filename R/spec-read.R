# --------------------------------------------------------------------------
# spec-read.R -- herald_spec S3 class + constructors
# --------------------------------------------------------------------------
# A `herald_spec` is a list with two data.frame slots:
#
#   ds_spec  : (dataset, class, label, standard, ...)
#              one row per dataset in the submission
#   var_spec : (dataset, variable, type, label, format, length, role, ...)
#              one row per (dataset, variable) pair
#
# Downstream consumers:
#   apply_spec(datasets, spec)   -- stamps column attributes before validate()
#   rules-scope.R                -- reads ds_spec$class for scope gates
#   rules-crossrefs.R            -- reads var_spec$required / $allowed
#   sub-discover.R               -- reads ds_spec$standard
#
# No Define.xml parser lives here; richer formats can be added later.

#' Construct a `herald_spec` object
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Assembles a [`herald_spec`][herald_spec()] S3 object from two data
#' frames describing the datasets and variables in a submission. The
#' result is the canonical specification handed to [apply_spec()] and
#' [validate()]:
#'
#' * Normalises column names to lowercase.
#' * Checks required columns (`dataset` on `ds_spec`; `dataset`,
#'   `variable` on `var_spec`).
#' * Uppercases dataset and variable names for case-insensitive joins.
#' * Preserves any extra columns unchanged so sponsor-specific metadata
#'   round-trips through `apply_spec()`.
#'
#' @details
#' # Input dispatch
#'
#' `as_herald_spec()` is the simple two-arg form. The richer
#' [herald_spec()] constructor accepts the full Define-XML 2.1 slot set
#' (study, codelist, methods, comments, ARM displays, etc.). Common
#' upstream sources:
#'
#' * Two raw data frames (this constructor).
#' * A `herald_define` object from [read_define_xml()] -- pass
#'   `d$ds_spec` and `d$var_spec` directly.
#' * An existing `herald_spec` -- returned unchanged by [is_herald_spec()]
#'   guards in callers.
#'
#' @param ds_spec Data frame. Must carry column `dataset`. Recognised
#'   further columns: `class`, `label`, `standard`. Any other columns are
#'   preserved.
#' @param var_spec Optional data frame. Must carry columns `dataset` and
#'   `variable`. Recognised further columns: `type`, `label`, `format`,
#'   `length`, `role`. NULL is allowed (dataset-only spec).
#'
#' @return A list with class `c("herald_spec", "list")` holding `ds_spec`
#'   and (if supplied) `var_spec`.
#'
#' @examples
#' dm   <- readRDS(system.file("extdata", "dm.rds",   package = "herald"))
#' adsl <- readRDS(system.file("extdata", "adsl.rds", package = "herald"))
#' adae <- readRDS(system.file("extdata", "adae.rds", package = "herald"))
#'
#' # ---- Dataset-only spec (no var_spec) -- sufficient for class-scoped rules ----
#' spec_ds_only <- as_herald_spec(
#'   ds_spec = data.frame(dataset = "DM", stringsAsFactors = FALSE)
#' )
#' is_herald_spec(spec_ds_only)
#' spec_ds_only$ds_spec
#'
#' # ---- Single dataset with variable list -------------------------------
#' spec_single <- as_herald_spec(
#'   ds_spec  = data.frame(dataset = "DM", label = "Demographics",
#'                         stringsAsFactors = FALSE),
#'   var_spec = data.frame(dataset = "DM", variable = names(dm),
#'                         stringsAsFactors = FALSE)
#' )
#' nrow(spec_single$var_spec)
#'
#' # ---- Multi-dataset with class + label (ADaM) -------------------------
#' spec_adam <- as_herald_spec(
#'   ds_spec = data.frame(
#'     dataset = c("ADSL", "ADAE"),
#'     class   = c("SUBJECT LEVEL ANALYSIS DATASET", "OCCDS"),
#'     label   = c("Subject-Level Analysis Dataset", "Adverse Events"),
#'     stringsAsFactors = FALSE
#'   ),
#'   var_spec = data.frame(
#'     dataset  = c(rep("ADSL", ncol(adsl)), rep("ADAE", ncol(adae))),
#'     variable = c(names(adsl), names(adae)),
#'     stringsAsFactors = FALSE
#'   )
#' )
#' nrow(spec_adam$ds_spec)
#'
#' # ---- Rich var_spec with type, label, format, length ------------------
#' spec_rich <- as_herald_spec(
#'   ds_spec  = data.frame(dataset = "DM", stringsAsFactors = FALSE),
#'   var_spec = data.frame(
#'     dataset  = c("DM", "DM"),
#'     variable = c("STUDYID", "USUBJID"),
#'     label    = c("Study Identifier", "Unique Subject Identifier"),
#'     type     = c("text", "text"),
#'     length   = c(12L, 40L),
#'     stringsAsFactors = FALSE
#'   )
#' )
#' spec_rich$var_spec[, c("variable", "label", "length")]
#'
#' @seealso [apply_spec()] for the pre-validation step that stamps column
#'   attributes from a `herald_spec`.
#'
#' @family spec
#' @export
as_herald_spec <- function(ds_spec, var_spec = NULL) {
  call <- rlang::caller_env()
  check_data_frame(ds_spec, call = call)
  if (!is.null(var_spec)) {
    check_data_frame(var_spec, call = call)
  }

  ds_spec <- .normalise_spec_frame(
    ds_spec,
    required = "dataset",
    arg = "ds_spec",
    call = call
  )
  ds_spec$dataset <- toupper(as.character(ds_spec$dataset))

  if (!is.null(var_spec)) {
    var_spec <- .normalise_spec_frame(
      var_spec,
      required = c("dataset", "variable"),
      arg = "var_spec",
      call = call
    )
    var_spec$dataset <- toupper(as.character(var_spec$dataset))
    var_spec$variable <- toupper(as.character(var_spec$variable))
  }

  structure(
    list(ds_spec = ds_spec, var_spec = var_spec),
    class = c("herald_spec", "list")
  )
}

#' Construct a rich herald_spec with all submission slots
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Assembles a `herald_spec` that carries all Define-XML 2.1 slots:
#' `ds_spec`, `var_spec`, `study`, `value_spec`, `codelist`, `methods`,
#' `comments`, `documents`, `arm_displays`, and `arm_results`. Use this
#' constructor when you need round-trip fidelity through
#' [write_define_xml()]; reach for the simpler [as_herald_spec()] when
#' only datasets and variables matter.
#'
#' @details
#' # Input dispatch
#'
#' Each slot accepts a data frame in the layout produced by the matching
#' [read_define_xml()] field, so a Define-XML round-trip is just:
#'
#' ```r
#' d <- read_define_xml("define.xml")
#' s <- herald_spec(
#'   ds_spec      = d$ds_spec,      var_spec     = d$var_spec,
#'   study        = d$study,        codelist     = d$codelist,
#'   methods      = d$methods,      comments     = d$comments,
#'   documents    = d$documents,    arm_displays = d$arm_displays,
#'   arm_results  = d$arm_results
#' )
#' ```
#'
#' Slots not supplied default to either an empty data frame (`var_spec`,
#' `study`) or `NULL` (everything else). `write_define_xml()` emits an
#' element only when the corresponding slot is non-empty.
#'
#' @param ds_spec Data frame with column \code{dataset}.
#' @param var_spec Data frame with columns \code{dataset} and \code{variable}.
#' @param study Optional data.frame with columns \code{attribute} and
#'   \code{value} (rows: StudyName, StudyDescription, ProtocolName).
#' @param value_spec Optional data.frame for value-level metadata.
#' @param codelist Optional data.frame with codelist rows.
#' @param methods Optional data.frame with method definitions.
#' @param comments Optional data.frame with comment definitions.
#' @param documents Optional data.frame with document leaf definitions.
#' @param arm_displays Optional data.frame with ARM display definitions.
#' @param arm_results Optional data.frame with ARM result definitions.
#'
#' @return A list with class \code{c("herald_spec", "list")}.
#'
#' @examples
#' dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
#' adsl <- readRDS(system.file("extdata", "adsl.rds", package = "herald"))
#'
#' # ---- Minimal: ds_spec only (var_spec defaults to empty data frame) ----
#' s1 <- herald_spec(
#'   ds_spec = data.frame(dataset = "DM", label = "Demographics",
#'                        stringsAsFactors = FALSE)
#' )
#' is_herald_spec(s1)
#' nrow(s1$var_spec)   # 0 -- empty but present
#'
#' # ---- With ds_spec and var_spec ---------------------------------------
#' s2 <- herald_spec(
#'   ds_spec  = data.frame(dataset = "DM", label = "Demographics",
#'                         stringsAsFactors = FALSE),
#'   var_spec = data.frame(dataset = "DM", variable = names(dm),
#'                         stringsAsFactors = FALSE)
#' )
#' nrow(s2$var_spec)
#'
#' # ---- With study metadata slot (used by write_define_xml) -------------
#' s3 <- herald_spec(
#'   ds_spec = data.frame(dataset = "ADSL", stringsAsFactors = FALSE),
#'   study   = data.frame(
#'     attribute = c("StudyName", "ProtocolName"),
#'     value     = c("PILOT01", "PROTOCOL-A"),
#'     stringsAsFactors = FALSE
#'   )
#' )
#' s3$study
#'
#' # ---- Rich spec with codelist slot ------------------------------------
#' s4 <- herald_spec(
#'   ds_spec  = data.frame(dataset = "DM", stringsAsFactors = FALSE),
#'   var_spec = data.frame(dataset = "DM", variable = names(dm),
#'                         stringsAsFactors = FALSE),
#'   codelist = data.frame(
#'     codelist_id = "CL.SEX",
#'     codelist_label = "Sex",
#'     value = c("M", "F"),
#'     decoded_value = c("Male", "Female"),
#'     stringsAsFactors = FALSE
#'   )
#' )
#' nrow(s4$codelist)
#'
#' @seealso [as_herald_spec()] for the simpler two-arg constructor.
#' @family spec
#' @export
herald_spec <- function(
  ds_spec,
  var_spec = data.frame(
    dataset = character(),
    variable = character(),
    stringsAsFactors = FALSE
  ),
  study = data.frame(
    attribute = character(),
    value = character(),
    stringsAsFactors = FALSE
  ),
  value_spec = NULL,
  codelist = NULL,
  methods = NULL,
  comments = NULL,
  documents = NULL,
  arm_displays = NULL,
  arm_results = NULL
) {
  call <- rlang::caller_env()
  check_data_frame(ds_spec, call = call)

  ds_spec <- .normalise_spec_frame(
    ds_spec,
    required = "dataset",
    arg = "ds_spec",
    call = call
  )
  var_spec <- .normalise_spec_frame(
    var_spec,
    required = c("dataset", "variable"),
    arg = "var_spec",
    call = call
  )

  structure(
    list(
      ds_spec = ds_spec,
      var_spec = var_spec,
      study = study,
      value_spec = value_spec,
      codelist = codelist,
      methods = methods,
      comments = comments,
      documents = documents,
      arm_displays = arm_displays,
      arm_results = arm_results
    ),
    class = c("herald_spec", "list")
  )
}

#' Is `x` a `herald_spec`?
#'
#' @param x Any object.
#' @return `TRUE` if `x` inherits from `herald_spec`, else `FALSE`.
#'
#' @examples
#' dm <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
#' spec <- as_herald_spec(
#'   ds_spec  = data.frame(dataset = "DM", stringsAsFactors = FALSE),
#'   var_spec = data.frame(dataset = "DM", variable = names(dm),
#'                         stringsAsFactors = FALSE)
#' )
#'
#' # ---- Valid herald_spec -- returns TRUE -------------------------------
#' is_herald_spec(spec)
#'
#' # ---- Plain list -- returns FALSE -------------------------------------
#' is_herald_spec(list(ds_spec = data.frame()))
#'
#' # ---- NULL, data.frame, or character -- all FALSE ---------------------
#' is_herald_spec(NULL)
#' is_herald_spec(data.frame())
#' is_herald_spec("DM")
#'
#' @family spec
#' @export
is_herald_spec <- function(x) inherits(x, "herald_spec")

#' Print a herald_spec
#' @param x A `herald_spec` object.
#' @param ... Ignored.
#' @return `x` invisibly.
#' @export
print.herald_spec <- function(x, ...) {
  n_ds <- if (is.data.frame(x$ds_spec)) nrow(x$ds_spec) else 0L
  n_var <- if (is.data.frame(x$var_spec)) nrow(x$var_spec) else 0L
  cat("<herald_spec>\n")
  cat(sprintf(
    "  %d dataset%s, %d variable%s\n",
    n_ds,
    if (n_ds == 1L) "" else "s",
    n_var,
    if (n_var == 1L) "" else "s"
  ))
  invisible(x)
}

# --------------------------------------------------------------------------
# Internal accessors
# --------------------------------------------------------------------------

#' Look up the var_spec row for a (dataset, variable) pair
#'
#' Returns a one-row data.frame, or NULL if not found or no var_spec.
#' Lookup is case-insensitive on both keys.
#' @noRd
.spec_var <- function(spec, dataset, variable) {
  if (!is_herald_spec(spec)) {
    return(NULL)
  }
  v <- spec[["var_spec"]]
  if (!is.data.frame(v) || nrow(v) == 0L) {
    return(NULL)
  }
  ds_key <- toupper(as.character(dataset %||% ""))
  vr_key <- toupper(as.character(variable %||% ""))
  hit <- toupper(as.character(v$dataset)) == ds_key &
    toupper(as.character(v$variable)) == vr_key
  if (!any(hit, na.rm = TRUE)) {
    return(NULL)
  }
  v[which(hit)[[1L]], , drop = FALSE]
}

#' Look up the ds_spec row for a dataset
#'
#' Returns a one-row data.frame, or NULL if not found.
#' @noRd
.spec_ds <- function(spec, dataset) {
  if (!is_herald_spec(spec)) {
    return(NULL)
  }
  d <- spec[["ds_spec"]]
  if (!is.data.frame(d) || nrow(d) == 0L) {
    return(NULL)
  }
  ds_key <- toupper(as.character(dataset %||% ""))
  hit <- toupper(as.character(d$dataset)) == ds_key
  if (!any(hit, na.rm = TRUE)) {
    return(NULL)
  }
  d[which(hit)[[1L]], , drop = FALSE]
}

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

#' Normalise a spec data.frame: lowercase column names, check required cols
#' @noRd
.normalise_spec_frame <- function(df, required, arg, call) {
  nm <- names(df)
  nm_lower <- tolower(nm)
  if (anyDuplicated(nm_lower)) {
    dup <- nm[duplicated(nm_lower) | duplicated(nm_lower, fromLast = TRUE)]
    herald_error(
      "{.arg {arg}} has duplicate column names (case-insensitive): {.val {unique(dup)}}.",
      class = "herald_error_input",
      call = call
    )
  }
  names(df) <- nm_lower
  missing_cols <- setdiff(required, nm_lower)
  if (length(missing_cols) > 0L) {
    herald_error(
      "{.arg {arg}} is missing required column{?s}: {.val {missing_cols}}.",
      class = "herald_error_input",
      call = call
    )
  }
  df
}
