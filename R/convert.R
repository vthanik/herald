# --------------------------------------------------------------------------
# convert.R -- unified format conversion for XPT, Dataset-JSON, Parquet
# --------------------------------------------------------------------------

#' Convert a dataset between XPT, Dataset-JSON, and Parquet
#'
#' @description
#' Reads a dataset file in one CDISC-friendly format and writes it in
#' another, preserving all CDISC column attributes (label, format, length,
#' type) and dataset-level attributes (\code{dataset_name}, \code{label}).
#'
#' Formats are inferred from the file extensions of \code{input} and
#' \code{output}; pass \code{from} / \code{to} to override. All nine
#' directions are supported, including same-format round-trips (useful
#' as attribute sanity checks):
#'
#' \tabular{ll}{
#'   \strong{input} \tab \strong{output} \cr
#'   xpt     \tab xpt     \cr
#'   xpt     \tab json    \cr
#'   xpt     \tab parquet \cr
#'   json    \tab xpt     \cr
#'   json    \tab json    \cr
#'   json    \tab parquet \cr
#'   parquet \tab xpt     \cr
#'   parquet \tab json    \cr
#'   parquet \tab parquet \cr
#' }
#'
#' @param input Path to the input dataset file.
#' @param output Path to the output dataset file.
#' @param to One of \code{"xpt"}, \code{"json"}, \code{"parquet"}.
#'   Default: inferred from \code{tools::file_ext(output)}.
#' @param from One of \code{"xpt"}, \code{"json"}, \code{"parquet"}.
#'   Default: inferred from \code{tools::file_ext(input)}.
#' @param dataset Dataset name override. Default: the
#'   \code{"dataset_name"} attribute of the input data, falling back to
#'   the uppercased file stem of \code{input}.
#' @param label Dataset label override. Default: the \code{"label"}
#'   attribute of the input data.
#' @param version XPT version (\code{5L} or \code{8L}). Only used when
#'   \code{to == "xpt"}; ignored otherwise.
#'
#' @return `output` (the path to the written file) invisibly.
#'
#' @examples
#' dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
#' spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
#' dm   <- apply_spec(dm, spec)
#' xpt  <- tempfile(fileext = ".xpt")
#' json <- tempfile(fileext = ".json")
#' on.exit(unlink(c(xpt, json)))
#' write_xpt(dm, xpt)
#' convert_dataset(xpt, json)
#' # round-trip back
#' dm2 <- read_json(json)
#' attr(dm2, "dataset_name")
#'
#' @seealso [read_xpt()], [read_json()], [read_parquet()],
#'   [write_xpt()], [write_json()], [write_parquet()].
#' @family io
#' @export
convert_dataset <- function(
  input,
  output,
  to = NULL,
  from = NULL,
  dataset = NULL,
  label = NULL,
  version = 5L
) {
  call <- rlang::caller_env()
  check_scalar_chr(input, call = call)
  check_scalar_chr(output, call = call)

  from <- .resolve_io_format(from, input,  "from", call = call)
  to   <- .resolve_io_format(to,   output, "to",   call = call)

  data <- switch(
    from,
    xpt     = read_xpt(input),
    json    = read_json(input),
    parquet = read_parquet(input)
  )

  if (is.null(dataset)) {
    dataset <- attr(data, "dataset_name") %||%
      toupper(tools::file_path_sans_ext(basename(input)))
  }
  if (is.null(label)) {
    label <- attr(data, "label")
  }

  switch(
    to,
    xpt     = write_xpt(data, output, version = version,
                        dataset = dataset, label = label),
    json    = write_json(data, output, dataset = dataset, label = label),
    parquet = write_parquet(data, output, dataset = dataset, label = label)
  )

  invisible(output)
}

#' Resolve a format token from an explicit value or a file extension.
#' @noRd
.resolve_io_format <- function(fmt, path, arg, call) {
  valid <- c("xpt", "json", "parquet")
  if (is.null(fmt)) {
    ext <- tolower(tools::file_ext(path))
    if (!nzchar(ext)) {
      herald_error_io(
        c(
          "Could not infer format for {.arg {arg}}.",
          "x" = "Path {.path {path}} has no extension.",
          "i" = "Pass {.arg {arg}} = {.val xpt}, {.val json}, or {.val parquet}."
        ),
        call = call
      )
    }
    fmt <- ext
  } else {
    check_scalar_chr(fmt, call = call)
    fmt <- tolower(fmt)
  }
  if (!fmt %in% valid) {
    herald_error_io(
      c(
        "Unknown format {.val {fmt}} for {.arg {arg}}.",
        "i" = "Supported formats: {.val {valid}}."
      ),
      call = call
    )
  }
  fmt
}
