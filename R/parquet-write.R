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
#'
#' @return `x` invisibly.
#'
#' @seealso [read_parquet()], [write_xpt()], [write_json()].
#' @family io
#' @export
write_parquet <- function(x, file) {
  call <- rlang::caller_env()
  check_data_frame(x, call = call)
  check_scalar_chr(file, call = call)
  .require_arrow(call)

  meta <- list()
  ds_lbl <- attr(x, "label")
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
