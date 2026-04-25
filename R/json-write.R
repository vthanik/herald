# --------------------------------------------------------------------------
# json-write.R -- CDISC Dataset-JSON v1.1 writer + xpt->json converter
# --------------------------------------------------------------------------
# Spec: https://github.com/cdisc-org/DataExchange-DatasetJson

#' Write a data frame as CDISC Dataset-JSON v1.1
#'
#' @description
#' Writes a data frame to a CDISC Dataset-JSON v1.1 file following the
#' official CDISC specification. Column labels, types, and lengths are
#' extracted from attributes on each column. If the
#' \code{herald.sort_keys} attribute is set, the data is sorted before
#' writing. JSON is always UTF-8.
#'
#' @param x A data frame.
#' @param file Output file path (should end in \code{.json}).
#' @param dataset Dataset name (e.g., \code{"DM"}). Default: inferred from
#'   the \code{"dataset_name"} attribute or the file name.
#' @param label Dataset label. Default: from the \code{"label"} attribute.
#' @param study_oid Study OID for metadata. Default: \code{""}.
#' @param metadata_version_oid Metadata version OID. Default: \code{""}.
#' @param metadata_ref Path to define.xml. Default: \code{NULL}.
#' @param originator Originator name. Default: \code{"herald"}.
#'
#' @return \code{x} invisibly (the input data frame, not the file path).
#'
#' @examples
#' if (requireNamespace("pharmaversesdtm", quietly = TRUE)) {
#'   dm   <- pharmaversesdtm::dm
#'   file <- tempfile(fileext = ".json")
#'   on.exit(unlink(file))
#'   write_json(dm, file, dataset = "DM", label = "Demographics")
#' }
#'
#' @seealso [read_json()] for reading, [write_xpt()] for XPT I/O.
#'
#' @family io
#' @export
write_json <- function(
  x,
  file,
  dataset = NULL,
  label = NULL,
  study_oid = "",
  metadata_version_oid = "",
  metadata_ref = NULL,
  originator = "herald"
) {
  call <- rlang::caller_env()
  check_data_frame(x, call = call)
  check_scalar_chr(file, call = call)

  sort_keys <- attr(x, "herald.sort_keys")
  if (!is.null(sort_keys) && length(sort_keys) > 0L) {
    present_keys <- sort_keys[sort_keys %in% names(x)]
    if (length(present_keys) > 0L) {
      x <- x[do.call(order, x[present_keys]), , drop = FALSE]
      rownames(x) <- NULL
    }
  }

  data <- x

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    herald_error_io(
      c(
        "Package {.pkg jsonlite} is required to write Dataset-JSON files.",
        "i" = "Install with: {.code install.packages(\"jsonlite\")}"
      ),
      call = call
    )
  }

  if (is.null(dataset)) {
    ds_attr <- attr(data, "dataset_name")
    dataset <- if (!is.null(ds_attr) && length(ds_attr) == 1L) {
      ds_attr
    } else {
      toupper(tools::file_path_sans_ext(basename(file)))
    }
  }
  dataset <- toupper(dataset)

  if (is.null(label)) {
    label <- attr(data, "label") %||% ""
  }

  col_names <- names(data)
  n_cols <- length(col_names)
  columns <- vector("list", n_cols)

  for (k in seq_len(n_cols)) {
    col <- data[[col_names[k]]]
    col_label <- attr(col, "label") %||% ""

    sas_fmt <- attr(col, "format.sas") %||% ""
    if (is.integer(col)) {
      data_type <- "integer"
    } else if (inherits(col, "POSIXt") || is_sas_datetime_format(sas_fmt)) {
      data_type <- "datetime"
    } else if (inherits(col, "Date") || is_sas_date_format(sas_fmt)) {
      data_type <- "date"
    } else if (inherits(col, "difftime") || is_sas_time_format(sas_fmt)) {
      data_type <- "time"
    } else if (is.logical(col)) {
      data_type <- "boolean"
    } else if (is.numeric(col)) {
      data_type <- "double"
    } else {
      data_type <- "string"
    }

    col_len <- attr(col, "sas.length")
    if (is.null(col_len)) {
      if (is.character(col) && length(col) > 0L) {
        col_len <- max(
          nchar(col, type = "bytes", allowNA = TRUE),
          1L,
          na.rm = TRUE
        )
      } else {
        col_len <- 8L
      }
    }

    display_fmt <- if (nzchar(sas_fmt)) sas_fmt else NULL

    col_obj <- list(
      itemOID = paste0("IT.", dataset, ".", col_names[k]),
      name = col_names[k],
      label = col_label,
      dataType = data_type
    )

    if (data_type == "string") {
      col_obj$length <- as.integer(col_len)
    }

    if (!is.null(display_fmt)) {
      col_obj$displayFormat <- display_fmt
    }

    columns[[k]] <- col_obj
  }

  n_rows <- nrow(data)
  rows <- vector("list", n_rows)

  for (i in seq_len(n_rows)) {
    row <- vector("list", n_cols)
    for (k in seq_len(n_cols)) {
      val <- data[[k]][i]
      if (is.na(val)) {
        row[k] <- list(NULL)
      } else {
        row[[k]] <- val
      }
    }
    rows[[i]] <- row
  }

  json_obj <- list(
    datasetJSONCreationDateTime = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    datasetJSONVersion = "1.1.0"
  )

  json_obj$fileOID <- paste0("herald.", dataset)
  if (nzchar(originator)) {
    json_obj$originator <- originator
  }
  json_obj$sourceSystem <- list(
    name = "herald",
    version = as.character(utils::packageVersion("herald"))
  )
  if (nzchar(study_oid)) {
    json_obj$studyOID <- study_oid
  }
  if (nzchar(metadata_version_oid)) {
    json_obj$metaDataVersionOID <- metadata_version_oid
  }
  if (!is.null(metadata_ref)) {
    json_obj$metaDataRef <- metadata_ref
  }

  json_obj$itemGroupOID <- paste0("IG.", dataset)
  json_obj$records <- n_rows
  json_obj$name <- dataset
  json_obj$label <- label
  json_obj$columns <- columns
  json_obj$rows <- rows

  json_str <- jsonlite::toJSON(
    json_obj,
    auto_unbox = TRUE,
    null = "null",
    pretty = TRUE,
    digits = NA
  )
  writeLines(json_str, file)

  invisible(x)
}

#' Convert an XPT file to Dataset-JSON
#'
#' @description
#' Reads an XPT transport file and writes it as CDISC Dataset-JSON v1.1.
#' All metadata (labels, formats, lengths) is preserved.
#'
#' @param xpt_path Path to a \code{.xpt} file.
#' @param json_path Output path for the \code{.json} file.
#' @param dataset Dataset name override. Default: inferred from file name.
#' @param label Dataset label override. Default: from XPT header.
#'
#' @return The output path, invisibly.
#'
#' @examples
#' if (requireNamespace("pharmaversesdtm", quietly = TRUE)) {
#'   dm   <- pharmaversesdtm::dm
#'   xpt  <- tempfile(fileext = ".xpt")
#'   json <- tempfile(fileext = ".json")
#'   on.exit(unlink(c(xpt, json)))
#'   write_xpt(dm, xpt, dataset = "DM", label = "Demographics")
#'   xpt_to_json(xpt, json)
#'   read_json(json)
#' }
#'
#' @seealso [json_to_xpt()] for the reverse, [read_xpt()], [write_json()].
#'
#' @family io
#' @export
xpt_to_json <- function(xpt_path, json_path, dataset = NULL, label = NULL) {
  call <- rlang::caller_env()
  check_scalar_chr(xpt_path, call = call)
  check_scalar_chr(json_path, call = call)

  data <- read_xpt(xpt_path)

  if (is.null(dataset)) {
    dataset <- toupper(tools::file_path_sans_ext(basename(xpt_path)))
  }
  if (is.null(label)) {
    label <- attr(data, "label")
  }

  write_json(data, json_path, dataset = dataset, label = label)
  invisible(json_path)
}

#' Convert an Apache Parquet file to Dataset-JSON
#'
#' Reads an Apache Parquet file and writes it as CDISC Dataset-JSON v1.1.
#' All CDISC column attributes (labels, formats, lengths) stored in the Parquet
#' metadata are preserved.
#'
#' @param parquet_path Path to the input \code{.parquet} file.
#' @param json_path Output path for the \code{.json} file.
#' @param dataset Dataset name override. Default: inferred from Parquet metadata.
#' @param label Dataset label override. Default: from Parquet metadata.
#'
#' @return \code{json_path} invisibly.
#'
#' @examples
#' if (requireNamespace("arrow", quietly = TRUE) &&
#'     requireNamespace("pharmaversesdtm", quietly = TRUE)) {
#'   dm   <- pharmaversesdtm::dm
#'   pq   <- tempfile(fileext = ".parquet")
#'   json <- tempfile(fileext = ".json")
#'   on.exit(unlink(c(pq, json)))
#'   write_parquet(dm, pq, dataset = "DM", label = "Demographics")
#'   parquet_to_json(pq, json)
#' }
#'
#' @seealso [xpt_to_json()] for XPT-to-JSON, [json_to_parquet()] for the reverse,
#'   [read_parquet()], [write_json()].
#' @family io
#' @export
parquet_to_json <- function(parquet_path, json_path, dataset = NULL, label = NULL) {
  call <- rlang::caller_env()
  check_scalar_chr(parquet_path, call = call)
  check_scalar_chr(json_path, call = call)

  data <- read_parquet(parquet_path)

  if (is.null(dataset)) {
    dataset <- attr(data, "dataset_name") %||%
      toupper(tools::file_path_sans_ext(basename(parquet_path)))
  }
  if (is.null(label)) {
    label <- attr(data, "label")
  }

  write_json(data, json_path, dataset = dataset, label = label)
  invisible(json_path)
}
