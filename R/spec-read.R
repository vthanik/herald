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
#' Assembles a `herald_spec` S3 object from two data frames describing the
#' datasets and variables in a submission. Column names are normalised to
#' lowercase; required columns are checked. Extra columns pass through
#' unchanged.
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
#' if (requireNamespace("pharmaverseadam", quietly = TRUE)) {
#'   adsl_vars <- names(pharmaverseadam::adsl)
#'   adae_vars <- names(pharmaverseadam::adae)
#'   spec <- as_herald_spec(
#'     ds_spec = data.frame(
#'       dataset = c("ADSL", "ADAE"),
#'       class   = c("SUBJECT LEVEL ANALYSIS DATASET", "BASIC DATA STRUCTURE"),
#'       label   = c("Subject-Level Analysis Dataset", "Adverse Events"),
#'       stringsAsFactors = FALSE
#'     ),
#'     var_spec = data.frame(
#'       dataset  = c(rep("ADSL", length(adsl_vars)), rep("ADAE", length(adae_vars))),
#'       variable = c(adsl_vars, adae_vars),
#'       stringsAsFactors = FALSE
#'     )
#'   )
#'   is_herald_spec(spec)
#' }
#'
#' @seealso [apply_spec()] for the pre-validation step that stamps column
#'   attributes from a `herald_spec`.
#'
#' @family spec
#' @export
as_herald_spec <- function(ds_spec, var_spec = NULL) {
  call <- rlang::caller_env()
  check_data_frame(ds_spec, call = call)
  if (!is.null(var_spec)) check_data_frame(var_spec, call = call)

  ds_spec <- .normalise_spec_frame(ds_spec, required = "dataset",
                                   arg = "ds_spec", call = call)
  ds_spec$dataset <- toupper(as.character(ds_spec$dataset))

  if (!is.null(var_spec)) {
    var_spec <- .normalise_spec_frame(
      var_spec,
      required = c("dataset", "variable"),
      arg = "var_spec",
      call = call
    )
    var_spec$dataset  <- toupper(as.character(var_spec$dataset))
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
#' Assembles a \code{herald_spec} that carries all Define-XML 2.1 slots:
#' \code{ds_spec}, \code{var_spec}, \code{study}, \code{value_spec},
#' \code{codelist}, \code{methods}, \code{comments}, \code{documents},
#' \code{arm_displays}, and \code{arm_results}. Used by
#' \code{write_define_xml()} and round-trip tests.
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
#' if (requireNamespace("pharmaversesdtm", quietly = TRUE)) {
#'   dm_vars <- names(pharmaversesdtm::dm)
#'   spec <- herald_spec(
#'     ds_spec  = data.frame(dataset = "DM", label = "Demographics",
#'                           stringsAsFactors = FALSE),
#'     var_spec = data.frame(dataset = "DM", variable = dm_vars,
#'                           stringsAsFactors = FALSE)
#'   )
#'   is_herald_spec(spec)
#' }
#'
#' @seealso [as_herald_spec()] for the simpler two-arg constructor.
#' @family spec
#' @export
herald_spec <- function(
  ds_spec,
  var_spec      = data.frame(dataset = character(), variable = character(),
                              stringsAsFactors = FALSE),
  study         = data.frame(attribute = character(), value = character(),
                              stringsAsFactors = FALSE),
  value_spec    = NULL,
  codelist      = NULL,
  methods       = NULL,
  comments      = NULL,
  documents     = NULL,
  arm_displays  = NULL,
  arm_results   = NULL
) {
  call <- rlang::caller_env()
  check_data_frame(ds_spec, call = call)

  ds_spec  <- .normalise_spec_frame(ds_spec,  required = "dataset",
                                    arg = "ds_spec",  call = call)
  var_spec <- .normalise_spec_frame(var_spec, required = c("dataset", "variable"),
                                    arg = "var_spec", call = call)

  structure(
    list(
      ds_spec      = ds_spec,
      var_spec     = var_spec,
      study        = study,
      value_spec   = value_spec,
      codelist     = codelist,
      methods      = methods,
      comments     = comments,
      documents    = documents,
      arm_displays = arm_displays,
      arm_results  = arm_results
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
#' if (requireNamespace("pharmaversesdtm", quietly = TRUE)) {
#'   spec <- as_herald_spec(
#'     ds_spec = data.frame(dataset = "DM", stringsAsFactors = FALSE),
#'     var_spec = data.frame(
#'       dataset  = "DM",
#'       variable = names(pharmaversesdtm::dm),
#'       stringsAsFactors = FALSE
#'     )
#'   )
#'   is_herald_spec(spec)
#'   is_herald_spec(list())
#' }
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
  n_ds  <- if (is.data.frame(x$ds_spec))  nrow(x$ds_spec)  else 0L
  n_var <- if (is.data.frame(x$var_spec)) nrow(x$var_spec) else 0L
  cat("<herald_spec>\n")
  cat(sprintf("  %d dataset%s, %d variable%s\n",
              n_ds,  if (n_ds  == 1L) "" else "s",
              n_var, if (n_var == 1L) "" else "s"))
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
  if (!is_herald_spec(spec)) return(NULL)
  v <- spec[["var_spec"]]
  if (!is.data.frame(v) || nrow(v) == 0L) return(NULL)
  ds_key <- toupper(as.character(dataset %||% ""))
  vr_key <- toupper(as.character(variable %||% ""))
  hit <- toupper(as.character(v$dataset)) == ds_key &
         toupper(as.character(v$variable)) == vr_key
  if (!any(hit, na.rm = TRUE)) return(NULL)
  v[which(hit)[[1L]], , drop = FALSE]
}

#' Look up the ds_spec row for a dataset
#'
#' Returns a one-row data.frame, or NULL if not found.
#' @noRd
.spec_ds <- function(spec, dataset) {
  if (!is_herald_spec(spec)) return(NULL)
  d <- spec[["ds_spec"]]
  if (!is.data.frame(d) || nrow(d) == 0L) return(NULL)
  ds_key <- toupper(as.character(dataset %||% ""))
  hit <- toupper(as.character(d$dataset)) == ds_key
  if (!any(hit, na.rm = TRUE)) return(NULL)
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
