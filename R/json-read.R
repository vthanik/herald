# --------------------------------------------------------------------------
# json-read.R -- CDISC Dataset-JSON v1.1 reader
# --------------------------------------------------------------------------
# Spec: https://github.com/cdisc-org/DataExchange-DatasetJson

#' Read a CDISC Dataset-JSON file
#'
#' @description
#' Reads a CDISC Dataset-JSON v1.1 file and returns a data frame with
#' metadata preserved as attributes (labels, lengths).
#'
#' @param file Path to a \code{.json} dataset file.
#'
#' @return A data frame with attributes:
#' \describe{
#'   \item{label}{Dataset label.}
#'   \item{column labels}{Per-column \code{"label"} attributes.}
#'   \item{dataset_name}{Dataset name stored as \code{"dataset_name"} attribute.}
#' }
#'
#' @examples
#' if (requireNamespace("pharmaversesdtm", quietly = TRUE)) {
#'   dm   <- pharmaversesdtm::dm
#'   file <- tempfile(fileext = ".json")
#'   on.exit(unlink(file))
#'   write_json(dm, file, dataset = "DM", label = "Demographics")
#'   dm2  <- read_json(file)
#'   dm2
#' }
#'
#' @seealso [write_json()] for writing, [read_xpt()] for XPT I/O.
#'
#' @family io
#' @export
read_json <- function(file) {
  call <- rlang::caller_env()
  check_scalar_chr(file, call = call)

  if (!file.exists(file)) {
    herald_error_io("File {.path {file}} does not exist.", path = file, call = call)
  }

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    herald_error_io(
      c(
        "Package {.pkg jsonlite} is required to read Dataset-JSON files.",
        "i" = "Install with: {.code install.packages(\"jsonlite\")}"
      ),
      call = call
    )
  }

  raw <- jsonlite::fromJSON(file, simplifyVector = FALSE)

  if (is.null(raw[["columns"]]) || is.null(raw[["rows"]])) {
    herald_error_io(
      c(
        "Unrecognised Dataset-JSON structure.",
        "i" = "Expected v1.1 flat structure with {.field columns} and {.field rows}."
      ),
      path = file,
      call = call
    )
  }

  .read_dataset_json_v11(raw)
}

#' Parse v1.1 flat Dataset-JSON
#' @noRd
.read_dataset_json_v11 <- function(raw) {
  columns <- raw[["columns"]]
  rows <- raw[["rows"]]
  ds_name <- raw[["name"]] %||% ""
  ds_label <- raw[["label"]] %||% ""

  n_cols <- length(columns)
  col_names <- vapply(columns, function(c) c[["name"]] %||% "", character(1))
  col_labels <- vapply(columns, function(c) c[["label"]] %||% "", character(1))
  col_types <- vapply(
    columns,
    function(c) c[["dataType"]] %||% "string",
    character(1)
  )
  col_lengths <- vapply(
    columns,
    function(c) as.integer(c[["length"]] %||% NA_integer_),
    integer(1)
  )
  col_formats <- vapply(
    columns,
    function(c) c[["displayFormat"]] %||% "",
    character(1)
  )

  .build_dataframe(
    rows,
    n_cols,
    col_names,
    col_labels,
    col_types,
    col_lengths,
    col_formats,
    ds_name,
    ds_label
  )
}

#' Build a data frame from parsed JSON components
#' @noRd
.build_dataframe <- function(
  rows,
  n_cols,
  col_names,
  col_labels,
  col_types,
  col_lengths,
  col_formats,
  ds_name,
  ds_label
) {
  numeric_types <- c("integer", "float", "double", "decimal")

  if (is.null(rows) || length(rows) == 0L) {
    cols <- vector("list", n_cols)
    for (k in seq_len(n_cols)) {
      cols[[k]] <- if (col_types[k] %in% numeric_types) {
        numeric(0L)
      } else {
        character(0L)
      }
    }
    names(cols) <- col_names
    out <- as.data.frame(cols, stringsAsFactors = FALSE)
  } else {
    n_rows <- length(rows)
    cols <- vector("list", n_cols)
    for (k in seq_len(n_cols)) {
      cols[[k]] <- vector(
        if (col_types[k] %in% numeric_types) "numeric" else "character",
        n_rows
      )
    }

    for (i in seq_len(n_rows)) {
      row <- rows[[i]]
      row_len <- length(row)
      for (k in seq_len(n_cols)) {
        val <- if (k <= row_len) row[[k]] else NULL
        if (is.null(val)) {
          cols[[k]][i] <- NA
        } else if (col_types[k] %in% numeric_types) {
          cols[[k]][i] <- as.numeric(val)
        } else {
          cols[[k]][i] <- as.character(val)
        }
      }
    }

    names(cols) <- col_names
    out <- as.data.frame(cols, stringsAsFactors = FALSE)
  }

  for (k in seq_len(n_cols)) {
    if (col_types[k] == "integer") {
      out[[k]] <- as.integer(out[[k]])
    }
  }

  if (nzchar(ds_label)) {
    attr(out, "label") <- ds_label
  }
  attr(out, "dataset_name") <- ds_name

  for (k in seq_len(n_cols)) {
    if (nzchar(col_labels[k])) {
      attr(out[[col_names[k]]], "label") <- col_labels[k]
    }
    if (!is.na(col_lengths[k])) {
      attr(out[[col_names[k]]], "sas.length") <- col_lengths[k]
    }
    if (nzchar(col_formats[k])) {
      attr(out[[col_names[k]]], "format.sas") <- col_formats[k]
    }
  }

  out
}

#' Convert a Dataset-JSON file to XPT
#'
#' @description
#' Reads a CDISC Dataset-JSON v1.1 file and writes it as a SAS V5 transport
#' file. All metadata (labels, lengths) is preserved.
#'
#' @param json_path Path to a \code{.json} dataset file.
#' @param xpt_path Output path for the \code{.xpt} file.
#' @param version XPT version: 5 (FDA standard, default) or 8.
#'
#' @return The output path, invisibly.
#'
#' @examples
#' if (requireNamespace("pharmaversesdtm", quietly = TRUE)) {
#'   dm   <- pharmaversesdtm::dm
#'   json <- tempfile(fileext = ".json")
#'   xpt  <- tempfile(fileext = ".xpt")
#'   on.exit(unlink(c(json, xpt)))
#'   write_json(dm, json, dataset = "DM", label = "Demographics")
#'   json_to_xpt(json, xpt)
#'   read_xpt(xpt)
#' }
#'
#' @seealso [xpt_to_json()] for the reverse, [write_xpt()], [read_json()].
#'
#' @family io
#' @export
json_to_xpt <- function(json_path, xpt_path, version = 5L) {
  call <- rlang::caller_env()
  check_scalar_chr(json_path, call = call)
  check_scalar_chr(xpt_path, call = call)

  data <- read_json(json_path)
  ds_name <- attr(data, "dataset_name") %||%
    toupper(tools::file_path_sans_ext(basename(json_path)))
  ds_label <- attr(data, "label")

  write_xpt(
    data,
    xpt_path,
    version = version,
    dataset = ds_name,
    label = ds_label
  )
  invisible(xpt_path)
}
