# --------------------------------------------------------------------------
# parquet-write.R -- write Apache Parquet with CDISC column attributes
# --------------------------------------------------------------------------
# Inverse of parquet-read.R. Serialises `attr(col, "label")`, `"format.sas"`,
# `"sas.length"`, `"xpt_type"` into the file's key/value metadata under
# `herald.*` keys so a round-trip preserves CDISC metadata alongside the
# Parquet-native schema.

#' Write a data frame to Apache Parquet with CDISC column attributes
#'
#' @description
#' Writes a data frame to a Parquet file, embedding CDISC metadata
#' (column labels, SAS formats, lengths, and XPT types) in the file's
#' key/value metadata under `herald.*` keys. This ensures a full
#' round-trip: `read_parquet()` restores every attribute that
#' `write_parquet()` saved.
#'
#' Requires the `arrow` package.
#'
#' @param x A data frame. Column attributes (`label`, `format.sas`,
#'   `sas.length`, `xpt_type`) are written to Parquet key/value
#'   metadata when present.
#' @param file Output path (should end in `.parquet`).
#' @param dataset Dataset name (e.g., `"DM"`). Default: inferred from
#'   the variable name (`dm` -> `"DM"`), then
#'   `attr(x, "dataset_name")`, then the uppercase file stem.
#' @param label Dataset label. Default: `attr(x, "label")`.
#'
#' @return `x` invisibly.
#'
#' @examplesIf requireNamespace("arrow", quietly = TRUE)
#' dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
#' spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
#' dm   <- apply_spec(dm, spec)
#' out  <- tempfile(fileext = ".parquet")
#' on.exit(unlink(out))
#' write_parquet(dm, out, label = "Demographics")
#'
#' @seealso [read_parquet()], [write_xpt()], [write_json()].
#' @family io
#' @export
write_parquet <- function(x, file, dataset = NULL, label = NULL) {
  .x_expr <- rlang::enexpr(x)
  call <- rlang::caller_env()
  check_data_frame(x, call = call)
  check_scalar_chr(file, call = call)
  .require_arrow(call)

  if (is.null(dataset)) {
    ds_attr <- attr(x, "dataset_name")
    dataset <- if (
      !is.null(ds_attr) && length(ds_attr) == 1L && nzchar(ds_attr)
    ) {
      toupper(ds_attr)
    } else if (is.symbol(.x_expr)) {
      cand <- as.character(.x_expr)
      if (grepl("^[A-Za-z_][A-Za-z0-9_]*$", cand)) toupper(cand) else NULL
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
      meta[[paste0("herald.col.", nm, ".label")]] <- as.character(lbl)
    }
    if (!is.null(fmt) && length(fmt) == 1L && nzchar(fmt)) {
      meta[[paste0("herald.col.", nm, ".format")]] <- as.character(fmt)
    }
    if (!is.null(len) && length(len) == 1L && !is.na(len)) {
      meta[[paste0("herald.col.", nm, ".length")]] <- as.character(as.integer(
        len
      ))
    }
    if (!is.null(typ) && length(typ) == 1L && nzchar(typ)) {
      meta[[paste0("herald.col.", nm, ".type")]] <- as.character(typ)
    }
  }

  tbl <- arrow::arrow_table(x)
  if (length(meta) > 0L) {
    tbl <- tbl$ReplaceSchemaMetadata(meta)
  }
  arrow::write_parquet(tbl, file)
  invisible(x)
}
