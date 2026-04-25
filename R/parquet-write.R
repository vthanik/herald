# --------------------------------------------------------------------------
# parquet-write.R -- write Apache Parquet with CDISC column attributes
# --------------------------------------------------------------------------
# Inverse of parquet-read.R. Serialises `attr(col, "label")`, `"format.sas"`,
# `"sas.length"`, `"xpt_type"` into the file's key/value metadata under
# `herald.*` keys so a round-trip preserves CDISC metadata alongside the
# Parquet-native schema.

#' Write a data frame to Apache Parquet with CDISC column attributes
#'
#' @param x A data frame. Column and dataset attributes
#'   (`label`, `format.sas`, `sas.length`, `xpt_type`) are serialised to
#'   the file's key/value metadata when present.
#' @param file Output path (should end in `.parquet`).
#' @param dataset Dataset name (e.g., `"DM"`). Default: the
#'   `"dataset_name"` attribute of `x`, then the uppercase file stem,
#'   then `NULL` (omitted from metadata).
#' @param label Dataset label. Default: the `"label"` attribute of `x`.
#'
#' @return `x` invisibly.
#'
#' @examples
#' if (requireNamespace("arrow", quietly = TRUE) &&
#'     requireNamespace("pharmaversesdtm", quietly = TRUE)) {
#'   dm  <- pharmaversesdtm::dm
#'   out <- tempfile(fileext = ".parquet")
#'   on.exit(unlink(out))
#'   write_parquet(dm, out, dataset = "DM", label = "Demographics")
#' }
#'
#' @seealso [read_parquet()], [write_xpt()], [write_json()].
#' @family io
#' @export
write_parquet <- function(x, file, dataset = NULL, label = NULL) {
  call <- rlang::caller_env()
  check_data_frame(x, call = call)
  check_scalar_chr(file, call = call)
  .require_arrow(call)

  if (is.null(dataset)) {
    ds_attr <- attr(x, "dataset_name")
    dataset <- if (!is.null(ds_attr) && length(ds_attr) == 1L && nzchar(ds_attr)) {
      toupper(ds_attr)
    } else {
      stem <- tools::file_path_sans_ext(basename(file))
      if (nzchar(stem)) toupper(stem) else NULL
    }
  } else {
    dataset <- toupper(dataset)
  }

  if (is.null(label)) {
    label <- attr(x, "label") %||% NULL
  }

  meta <- list()
  if (!is.null(dataset) && nzchar(dataset)) {
    meta[["herald.dataset.name"]] <- as.character(dataset)
  }
  ds_lbl <- label
  if (!is.null(ds_lbl) && length(ds_lbl) == 1L && nzchar(ds_lbl)) {
    meta[["herald.dataset.label"]] <- as.character(ds_lbl)
  }

  for (nm in names(x)) {
    col <- x[[nm]]
    lbl <- attr(col, "label")
    fmt <- attr(col, "format.sas")
    len <- attr(col, "sas.length")
    typ <- attr(col, "xpt_type")
    if (!is.null(lbl) && length(lbl) == 1L && nzchar(lbl)) {
      meta[[paste0("herald.col.", nm, ".label")]]  <- as.character(lbl)
    }
    if (!is.null(fmt) && length(fmt) == 1L && nzchar(fmt)) {
      meta[[paste0("herald.col.", nm, ".format")]] <- as.character(fmt)
    }
    if (!is.null(len) && length(len) == 1L && !is.na(len)) {
      meta[[paste0("herald.col.", nm, ".length")]] <- as.character(as.integer(len))
    }
    if (!is.null(typ) && length(typ) == 1L && nzchar(typ)) {
      meta[[paste0("herald.col.", nm, ".type")]]   <- as.character(typ)
    }
  }

  tbl <- arrow::arrow_table(x)
  if (length(meta) > 0L) {
    tbl <- tbl$ReplaceSchemaMetadata(meta)
  }
  arrow::write_parquet(tbl, file)
  invisible(x)
}

#' Convert an XPT file to Apache Parquet
#'
#' Reads a SAS transport (.xpt) file and writes it as Apache Parquet.
#' All CDISC column attributes (labels, formats, lengths) are preserved.
#'
#' @param xpt_path Path to the input \code{.xpt} file.
#' @param parquet_path Output path for the \code{.parquet} file.
#' @param dataset Dataset name override. Default: inferred from the XPT header.
#' @param label Dataset label override. Default: from the XPT header.
#'
#' @return \code{parquet_path} invisibly.
#'
#' @examples
#' if (requireNamespace("arrow", quietly = TRUE) &&
#'     requireNamespace("pharmaversesdtm", quietly = TRUE)) {
#'   dm  <- pharmaversesdtm::dm
#'   xpt <- tempfile(fileext = ".xpt")
#'   pq  <- tempfile(fileext = ".parquet")
#'   on.exit(unlink(c(xpt, pq)))
#'   write_xpt(dm, xpt, dataset = "DM")
#'   xpt_to_parquet(xpt, pq)
#' }
#'
#' @seealso [parquet_to_xpt()] for the reverse, [xpt_to_json()], [read_xpt()],
#'   [write_parquet()].
#' @family io
#' @export
xpt_to_parquet <- function(xpt_path, parquet_path, dataset = NULL, label = NULL) {
  call <- rlang::caller_env()
  check_scalar_chr(xpt_path, call = call)
  check_scalar_chr(parquet_path, call = call)

  data <- read_xpt(xpt_path)

  if (is.null(dataset)) {
    dataset <- attr(data, "dataset_name") %||%
      toupper(tools::file_path_sans_ext(basename(xpt_path)))
  }
  if (is.null(label)) {
    label <- attr(data, "label")
  }

  write_parquet(data, parquet_path, dataset = dataset, label = label)
  invisible(parquet_path)
}

#' Convert a Dataset-JSON file to Apache Parquet
#'
#' Reads a CDISC Dataset-JSON v1.1 file and writes it as Apache Parquet.
#' All CDISC column attributes (labels, lengths) are preserved.
#'
#' @param json_path Path to the input \code{.json} dataset file.
#' @param parquet_path Output path for the \code{.parquet} file.
#' @param dataset Dataset name override. Default: inferred from the JSON metadata.
#' @param label Dataset label override. Default: from the JSON metadata.
#'
#' @return \code{parquet_path} invisibly.
#'
#' @examples
#' if (requireNamespace("arrow", quietly = TRUE) &&
#'     requireNamespace("pharmaversesdtm", quietly = TRUE)) {
#'   dm   <- pharmaversesdtm::dm
#'   json <- tempfile(fileext = ".json")
#'   pq   <- tempfile(fileext = ".parquet")
#'   on.exit(unlink(c(json, pq)))
#'   write_json(dm, json, dataset = "DM", label = "Demographics")
#'   json_to_parquet(json, pq)
#' }
#'
#' @seealso [parquet_to_json()] for the reverse, [json_to_xpt()], [read_json()],
#'   [write_parquet()].
#' @family io
#' @export
json_to_parquet <- function(json_path, parquet_path, dataset = NULL, label = NULL) {
  call <- rlang::caller_env()
  check_scalar_chr(json_path, call = call)
  check_scalar_chr(parquet_path, call = call)

  data <- read_json(json_path)

  if (is.null(dataset)) {
    dataset <- attr(data, "dataset_name") %||%
      toupper(tools::file_path_sans_ext(basename(json_path)))
  }
  if (is.null(label)) {
    label <- attr(data, "label")
  }

  write_parquet(data, parquet_path, dataset = dataset, label = label)
  invisible(parquet_path)
}
