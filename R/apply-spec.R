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
#' `r lifecycle::badge("stable")`
#'
#' Pre-validation helper that copies CDISC metadata from a
#' [`herald_spec`][as_herald_spec()] onto each dataset's columns and
#' onto the data frame itself, so downstream rule operators can read
#' attributes uniformly regardless of how the data was ingested. Spec
#' values overwrite any existing attribute; columns with no spec row
#' are untouched.
#'
#' * Sets `attr(ds, "label")` from `spec$ds_spec$label`.
#' * Sets per-column `"label"`, `"format.sas"`, `"sas.length"`, and
#'   `"xpt_type"` from `spec$var_spec`.
#' * Leaves datasets that are not in `spec` unchanged.
#'
#' Call this before [validate()] when datasets come from CSV, plain
#' data.frames, or any source that does not itself carry CDISC metadata.
#' XPT and Dataset-JSON readers already set these attributes at ingest,
#' so `apply_spec()` is optional there.
#'
#' @details
#' # Stamped attributes
#'
#' For each row in `spec$var_spec` matching a column in `datasets`,
#' `apply_spec()` writes:
#'
#' * `attr(col, "label")` from `var_spec$label`
#' * `attr(col, "format.sas")` from `var_spec$format`
#' * `attr(col, "sas.length")` from `var_spec$length`
#' * `attr(col, "xpt_type")` from `var_spec$type`
#'
#' Dataset-level `attr(ds, "label")` is taken from `spec$ds_spec$label`.
#'
#' # Missing or extra variables
#'
#' Variables present in `spec$var_spec` but not in the dataset are
#' silently skipped -- `apply_spec()` does not add columns. Variables
#' present in the dataset but not in `spec$var_spec` are left unchanged
#' (existing attributes preserved). Datasets named in `spec$ds_spec`
#' but missing from `datasets` are also skipped without error; herald
#' rules will catch missing required datasets at validation time.
#'
#' @param datasets Either a single data frame **or** a named list of data
#'   frames. When a single data frame is passed, the dataset name is
#'   inferred from the variable name (`dm` -> `"DM"`), then
#'   `attr(datasets, "dataset_name")`, then `"DATA"`. A single data frame
#'   is returned; a list returns a list.
#' @param spec A `herald_spec` (see [as_herald_spec()]).
#'
#' @return Same shape as `datasets`: a data frame if one was passed, a
#'   named list otherwise.
#'
#' @examples
#' dm   <- readRDS(system.file("extdata", "dm.rds",        package = "herald"))
#' spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
#'
#' # single dataset -- name inferred from variable (dm -> "DM")
#' dm <- apply_spec(dm, spec)
#' attr(dm, "label")
#' attr(dm$USUBJID, "label")
#'
#' # pipe-friendly
#' dm2 <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
#' dm2 <- dm2 |> apply_spec(spec)
#'
#' @seealso [as_herald_spec()], [validate()].
#' @family spec
#' @export
apply_spec <- function(datasets, spec) {
  ds_expr <- rlang::enexpr(datasets)
  call <- rlang::caller_env()

  single_df <- is.data.frame(datasets)

  if (single_df) {
    ds_name <- NULL
    ds_attr <- attr(datasets, "dataset_name")
    if (!is.null(ds_attr) && length(ds_attr) == 1L && nzchar(ds_attr)) {
      ds_name <- toupper(as.character(ds_attr))
    } else if (is.symbol(ds_expr)) {
      cand <- as.character(ds_expr)
      if (grepl("^[A-Za-z_][A-Za-z0-9_]*$", cand)) ds_name <- toupper(cand)
    }
    if (is.null(ds_name)) {
      ds_name <- "DATA"
    }
    datasets_list <- stats::setNames(list(datasets), ds_name)
  } else if (is.list(datasets)) {
    datasets_list <- datasets
  } else {
    herald_error(
      c(
        "{.arg datasets} must be a data frame or a named list of data frames.",
        "x" = "You supplied {.obj_type_friendly {datasets}}."
      ),
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

  nms <- names(datasets_list)
  if (is.null(nms) || any(!nzchar(nms))) {
    herald_error(
      "{.arg datasets} must have non-empty names for every element.",
      class = "herald_error_input",
      call = call
    )
  }

  for (i in seq_along(datasets_list)) {
    ds_name_i <- nms[[i]]
    ds <- datasets_list[[i]]
    if (!is.data.frame(ds)) {
      next
    }

    ds <- .apply_ds_attrs(ds, spec, ds_name_i)
    ds <- .apply_var_attrs(ds, spec, ds_name_i)
    datasets_list[[i]] <- ds
  }

  if (single_df) datasets_list[[1L]] else datasets_list
}

#' Stamp dataset-level attributes from ds_spec.
#' @noRd
.apply_ds_attrs <- function(ds, spec, ds_name) {
  row <- .spec_ds(spec, ds_name)
  if (is.null(row)) {
    return(ds)
  }
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
  if (!is.data.frame(v) || nrow(v) == 0L) {
    return(ds)
  }

  ds_col <- toupper(as.character(v$dataset))
  hits <- which(ds_col == toupper(as.character(ds_name)))
  if (length(hits) == 0L) {
    return(ds)
  }

  sub <- v[hits, , drop = FALSE]
  col_names_up <- toupper(names(ds))

  for (r in seq_len(nrow(sub))) {
    var_name <- toupper(as.character(sub$variable[[r]]))
    j <- which(col_names_up == var_name)
    if (length(j) == 0L) {
      next
    }
    j <- j[[1L]]
    col <- ds[[j]]

    lbl <- .scalar_or_null(sub[["label"]][[r]])
    if (!is.null(lbl)) {
      attr(col, "label") <- lbl
    }

    fmt <- .scalar_or_null(sub[["format"]][[r]])
    if (!is.null(fmt)) {
      attr(col, "format.sas") <- fmt
    }

    len <- sub[["length"]][[r]]
    if (!is.null(len) && length(len) == 1L && !is.na(len)) {
      attr(col, "sas.length") <- as.integer(len)
    }

    typ <- .scalar_or_null(sub[["type"]][[r]])
    if (!is.null(typ)) {
      attr(col, "xpt_type") <- typ
    }

    ds[[j]] <- col
  }
  ds
}

#' Return `x` as a non-empty character scalar, or NULL if absent/empty.
#' @noRd
.scalar_or_null <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) {
    return(NULL)
  }
  s <- as.character(x)
  if (!nzchar(s)) {
    return(NULL)
  }
  s
}
