# --------------------------------------------------------------------------
# json-read.R -- CDISC Dataset-JSON v1.1 reader
# --------------------------------------------------------------------------
# Spec: https://github.com/cdisc-org/DataExchange-DatasetJson

#' Read a CDISC Dataset-JSON file
#'
#' @description
#' Reads a CDISC Dataset-JSON v1.1 file into a data frame, restoring
#' column and dataset metadata from the JSON structure: column labels,
#' lengths, display formats, and the dataset name are all preserved
#' as R attributes.
#'
#' @param file Path to a `.json` Dataset-JSON file.
#'
#' @return A data frame with:
#'   \describe{
#'     \item{`attr(df, "label")`}{Dataset label.}
#'     \item{`attr(df, "dataset_name")`}{Dataset name.}
#'     \item{per-column `"label"`}{Column label from the JSON
#'       `columns[].label` field.}
#'     \item{per-column `"sas.length"`}{Column length from
#'       `columns[].length`.}
#'     \item{per-column `"format.sas"`}{Display format from
#'       `columns[].displayFormat`.}
#'     \item{per-column `"xpt_type"`}{Logical type from
#'       `columns[].dataType`.}
#'   }
#'
#' @examples
#' dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
#' spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
#' dm   <- apply_spec(dm, spec)
#' file <- tempfile(fileext = ".json")
#' on.exit(unlink(file))
#' write_json(dm, file, label = "Demographics")
#'
#' # ---- Read back and inspect dataset-level attributes ------------------
#' dm2 <- read_json(file)
#' attr(dm2, "label")          # "Demographics"
#' attr(dm2, "dataset_name")   # "DM"
#'
#' # ---- Inspect column-level attributes preserved from write_json -------
#' attr(dm2$USUBJID, "label")
#' attr(dm2$STUDYID, "sas.length")
#'
#' # ---- Read then apply_spec to overwrite/supplement attributes from spec ----
#' dm3 <- read_json(file) |> apply_spec(spec)
#' attr(dm3$USUBJID, "label")
#'
#' # ---- Read then validate immediately ----------------------------------
#' r <- validate(files = dm2, quiet = TRUE)
#' r$datasets_checked
#'
#' @seealso [write_json()] for writing, [read_xpt()], [read_parquet()],
#'   [apply_spec()] to stamp CDISC attributes after reading.
#' @family io
#' @export
read_json <- function(file) {
  call <- rlang::caller_env()
  check_scalar_chr(file, call = call)

  if (!file.exists(file)) {
    herald_error_io(
      "File {.path {file}} does not exist.",
      path = file,
      call = call
    )
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
