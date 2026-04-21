# --------------------------------------------------------------------------
# parquet-read.R -- read Apache Parquet with CDISC column attributes
# --------------------------------------------------------------------------
# GSK standard format for ADaM / SDTM interchange. Parquet's schema carries
# column types natively; labels / formats / lengths are stored in the file's
# key/value metadata map under CDISC-convention keys:
#
#   herald.dataset.label          -- dataset label
#   herald.col.<NAME>.label       -- column label
#   herald.col.<NAME>.format      -- column SAS format
#   herald.col.<NAME>.length      -- column SAS length
#   herald.col.<NAME>.type        -- column XPT type (text/integer/float/...)
#
# If the file lacks those entries, only the schema-derived type survives
# and the user will typically call `apply_spec()` afterwards to stamp
# labels/formats/lengths from a `herald_spec`.
#
# Requires the `arrow` package (Suggests). If not installed, read_parquet()
# raises an informative error.

#' Read an Apache Parquet dataset with CDISC column attributes
#'
#' @param file Path to a `.parquet` file.
#'
#' @return A data.frame with `attr(col, "label")`, `attr(col, "format.sas")`,
#'   `attr(col, "sas.length")`, and `attr(col, "xpt_type")` populated from
#'   the file's key/value metadata when present.
#'
#' @examples
#' \dontrun{
#' dm <- read_parquet("path/to/dm.parquet")
#' attr(dm, "label")
#' attr(dm$USUBJID, "label")
#' }
#'
#' @seealso [write_parquet()], [read_xpt()], [read_json()].
#' @family io
#' @export
read_parquet <- function(file) {
  call <- rlang::caller_env()
  check_scalar_chr(file, call = call)
  if (!file.exists(file)) {
    cli::cli_abort("File {.path {file}} does not exist.", call = call)
  }
  .require_arrow(call)

  tbl  <- arrow::read_parquet(file, as_data_frame = FALSE)
  meta <- tbl$schema$metadata %||% list()
  df   <- as.data.frame(tbl, stringsAsFactors = FALSE)

  ds_lbl <- meta[["herald.dataset.label"]]
  if (!is.null(ds_lbl) && nzchar(ds_lbl)) attr(df, "label") <- ds_lbl

  for (nm in names(df)) {
    col <- df[[nm]]
    lbl <- meta[[paste0("herald.col.", nm, ".label")]]
    fmt <- meta[[paste0("herald.col.", nm, ".format")]]
    len <- meta[[paste0("herald.col.", nm, ".length")]]
    typ <- meta[[paste0("herald.col.", nm, ".type")]]
    if (!is.null(lbl) && nzchar(lbl)) attr(col, "label")      <- lbl
    if (!is.null(fmt) && nzchar(fmt)) attr(col, "format.sas") <- fmt
    if (!is.null(len) && nzchar(len)) {
      n <- suppressWarnings(as.integer(len))
      if (!is.na(n)) attr(col, "sas.length") <- n
    }
    if (!is.null(typ) && nzchar(typ)) attr(col, "xpt_type")   <- typ
    df[[nm]] <- col
  }
  df
}

#' @noRd
.require_arrow <- function(call) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    cli::cli_abort(
      c(
        "Package {.pkg arrow} is required for Parquet I/O.",
        "i" = "Install with: {.code install.packages(\"arrow\")}"
      ),
      call = call
    )
  }
}
