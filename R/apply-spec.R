# --------------------------------------------------------------------------
# apply-spec.R -- pre-validation helper that stamps column attributes
# --------------------------------------------------------------------------
# `apply_spec(datasets, spec)` iterates each dataset's columns and sets
# standard attributes from the `herald_spec` so that validation ops can
# read `attr(col, "label")`, `attr(col, "format.sas")`, `attr(col,
# "sas.length")`, `attr(col, "xpt_type")`, and `attr(ds, "label")`
# uniformly -- regardless of whether datasets were ingested from XPT,
# Dataset-JSON, Parquet, or a plain data.frame. Spec values win when
# present.

#' Stamp column and dataset attributes from a `herald_spec`
#'
#' @description
#' For each dataset in `datasets`, writes `attr(., "label")` from
#' `spec$ds_spec` when available, and for each column writes `"label"`,
#' `"format.sas"`, `"sas.length"`, and `"xpt_type"` from `spec$var_spec`
#' when a matching row exists. Spec values overwrite any existing
#' attribute; columns with no spec row are untouched. Datasets absent
#' from the spec are returned unchanged.
#'
#' Call this before [validate()] when datasets come from CSV, plain
#' data.frames, or any source that does not itself carry CDISC metadata.
#' XPT and Dataset-JSON readers already set these attributes at ingest,
#' so `apply_spec()` is optional there.
#'
#' @param datasets A named list of data frames. Names are dataset names
#'   (matched case-insensitively against `spec$ds_spec$dataset`).
#' @param spec A `herald_spec` (see [as_herald_spec()]).
#'
#' @return The `datasets` list with attributes populated.
#'
#' @examples
#' if (requireNamespace("pharmaversesdtm", quietly = TRUE)) {
#'   dm   <- pharmaversesdtm::dm
#'   spec <- as_herald_spec(
#'     ds_spec = data.frame(dataset = "DM", label = "Demographics",
#'                          stringsAsFactors = FALSE),
#'     var_spec = data.frame(
#'       dataset  = c("DM", "DM"),
#'       variable = c("USUBJID", "AGE"),
#'       type     = c("text", "integer"),
#'       label    = c("Unique Subject Identifier", "Age"),
#'       length   = c(40L, 8L),
#'       stringsAsFactors = FALSE
#'     )
#'   )
#'   out <- apply_spec(list(DM = dm), spec)
#'   attr(out$DM, "label")
#'   attr(out$DM$USUBJID, "label")
#' }
#'
#' @seealso [as_herald_spec()], [validate()].
#' @family spec
#' @export
apply_spec <- function(datasets, spec) {
  call <- rlang::caller_env()
  if (!is.list(datasets) || is.data.frame(datasets)) {
    herald_error(
      "{.arg datasets} must be a named list of data frames.",
      class = "herald_error_input",
      call = call
    )
  }
  if (!is_herald_spec(spec)) {
    herald_error(
      "{.arg spec} must be a {.cls herald_spec} object.",
      class = "herald_error_input",
      call = call
    )
  }

  nms <- names(datasets)
  if (is.null(nms) || any(!nzchar(nms))) {
    herald_error(
      "{.arg datasets} must have non-empty names for every element.",
      class = "herald_error_input",
      call = call
    )
  }

  for (i in seq_along(datasets)) {
    ds_name <- nms[[i]]
    ds      <- datasets[[i]]
    if (!is.data.frame(ds)) next

    ds <- .apply_ds_attrs(ds, spec, ds_name)
    ds <- .apply_var_attrs(ds, spec, ds_name)
    datasets[[i]] <- ds
  }

  datasets
}

#' Stamp dataset-level attributes from ds_spec.
#' @noRd
.apply_ds_attrs <- function(ds, spec, ds_name) {
  row <- .spec_ds(spec, ds_name)
  if (is.null(row)) return(ds)
  lbl <- row[["label"]]
  if (!is.null(lbl) && length(lbl) == 1L && !is.na(lbl) && nzchar(lbl)) {
    attr(ds, "label") <- as.character(lbl)
  }
  ds
}

#' Stamp column-level attributes from var_spec.
#' @noRd
.apply_var_attrs <- function(ds, spec, ds_name) {
  v <- spec[["var_spec"]]
  if (!is.data.frame(v) || nrow(v) == 0L) return(ds)

  ds_col <- toupper(as.character(v$dataset))
  hits   <- which(ds_col == toupper(as.character(ds_name)))
  if (length(hits) == 0L) return(ds)

  sub <- v[hits, , drop = FALSE]
  col_names_up <- toupper(names(ds))

  for (r in seq_len(nrow(sub))) {
    var_name <- toupper(as.character(sub$variable[[r]]))
    j <- which(col_names_up == var_name)
    if (length(j) == 0L) next
    j <- j[[1L]]
    col <- ds[[j]]

    lbl <- .scalar_or_null(sub[["label"]][[r]])
    if (!is.null(lbl))  attr(col, "label")      <- lbl

    fmt <- .scalar_or_null(sub[["format"]][[r]])
    if (!is.null(fmt))  attr(col, "format.sas") <- fmt

    len <- sub[["length"]][[r]]
    if (!is.null(len) && length(len) == 1L && !is.na(len)) {
      attr(col, "sas.length") <- as.integer(len)
    }

    typ <- .scalar_or_null(sub[["type"]][[r]])
    if (!is.null(typ))  attr(col, "xpt_type")   <- typ

    ds[[j]] <- col
  }
  ds
}

#' Return `x` as a non-empty character scalar, or NULL if absent/empty.
#' @noRd
.scalar_or_null <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(NULL)
  s <- as.character(x)
  if (!nzchar(s)) return(NULL)
  s
}
