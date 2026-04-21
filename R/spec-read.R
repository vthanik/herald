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
#' spec <- as_herald_spec(
#'   ds_spec = data.frame(
#'     dataset = c("ADSL", "ADAE"),
#'     class   = c("SUBJECT LEVEL ANALYSIS DATASET", "BASIC DATA STRUCTURE"),
#'     label   = c("Subject-Level Analysis Dataset", "Adverse Events"),
#'     stringsAsFactors = FALSE
#'   ),
#'   var_spec = data.frame(
#'     dataset  = c("ADSL", "ADSL"),
#'     variable = c("USUBJID", "AGE"),
#'     type     = c("text", "integer"),
#'     label    = c("Unique Subject Identifier", "Age"),
#'     length   = c(40L, 8L),
#'     stringsAsFactors = FALSE
#'   )
#' )
#' is_herald_spec(spec)
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

#' Is `x` a `herald_spec`?
#'
#' @param x Any object.
#' @return `TRUE` if `x` inherits from `herald_spec`, else `FALSE`.
#' @family spec
#' @export
is_herald_spec <- function(x) inherits(x, "herald_spec")

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
