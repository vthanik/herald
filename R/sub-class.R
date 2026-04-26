# --------------------------------------------------------------------------
# sub-class.R  --  herald_submission S7 class
# --------------------------------------------------------------------------

herald_submission_class <- S7::new_class(
  "herald_submission",
  package = NULL,
  properties = list(
    output_dir = S7::class_character,
    files = S7::class_data.frame,
    validation = S7::class_any,
    manifest = S7::class_list,
    timestamp = S7::class_any,
    herald_version = S7::class_character
  )
)

#' Create a herald_submission object
#' @noRd
new_herald_submission <- function(
  output_dir = character(),
  xpt_files = character(),
  json_files = character(),
  define_path = NULL,
  validation = NULL,
  manifest = list(),
  report_paths = character(),
  timestamp = Sys.time(),
  herald_version = as.character(utils::packageVersion("herald"))
) {
  all_paths <- c(
    xpt_files,
    json_files,
    if (!is.null(define_path)) define_path,
    report_paths
  )
  all_types <- c(
    rep.int("xpt", length(xpt_files)),
    rep.int("json", length(json_files)),
    if (!is.null(define_path)) "define-xml",
    vapply(
      report_paths,
      function(p) {
        ext <- tolower(tools::file_ext(p))
        switch(
          ext,
          html = "report-html",
          xlsx = "report-xlsx",
          csv = "report-csv",
          json = "report-json",
          ext
        )
      },
      character(1),
      USE.NAMES = FALSE
    )
  )

  files_df <- if (length(all_paths) > 0L) {
    data.frame(
      path = all_paths,
      type = all_types,
      size = vapply(
        all_paths,
        function(p) {
          if (file.exists(p)) file.size(p) else NA_real_
        },
        double(1),
        USE.NAMES = FALSE
      ),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      path = character(),
      type = character(),
      size = double(),
      stringsAsFactors = FALSE
    )
  }

  herald_submission_class(
    output_dir = output_dir,
    files = files_df,
    validation = validation,
    manifest = manifest,
    timestamp = timestamp,
    herald_version = herald_version
  )
}

# -- $ / [[ dispatch ---------------------------------------------------------

#' Access and modify herald_submission properties
#'
#' S3 methods for `$`, `$<-`, `[[`, and `print` on `herald_submission` objects.
#' `$` provides derived views (`xpt_files`, `json_files`, `define_path`,
#' `report_paths`) in addition to the raw S7 properties.
#'
#' @param x A `herald_submission` object.
#' @param name Property name.
#' @param value Replacement value.
#' @param i Index (character).
#' @param ... Passed to underlying methods.
#'
#' @return `$` returns the property value or a derived field.
#'   `$<-` returns the modified object. `[[` returns the property value.
#'   `print` returns `x` invisibly.
#'
#' @examples
#' # Requires a real submission directory produced by submit()
#' if (interactive()) {
#'   sub <- submit("/path/to/sdtm", spec = my_spec)
#'
#'   # $ accessor -- raw S7 properties
#'   sub$output_dir
#'   sub$herald_version
#'   sub$timestamp
#'
#'   # $ accessor -- derived file-type views
#'   sub$xpt_files        # character vector of XPT paths
#'   sub$json_files       # character vector of JSON dataset paths
#'   sub$define_path      # single path or NULL
#'   sub$report_paths     # HTML / XLSX report paths
#'
#'   # [[ works the same as $
#'   sub[["xpt_files"]]
#'
#'   # Raw files table (path, type, size columns)
#'   sub$files
#'   sub$files[sub$files$type == "xpt", ]
#'
#'   # Print summary
#'   print(sub)
#'
#'   # Validation summary (if validate = TRUE was used in submit())
#'   sub$validation$summary
#'   sub$validation$findings[sub$validation$findings$status == "fired", ]
#' }
#'
#' @name herald_submission-methods
#' @keywords internal
#' @export
`$.herald_submission` <- function(x, name) {
  # Derived views from unified files table
  if (name == "xpt_files") {
    return(x@files$path[x@files$type == "xpt"])
  }
  if (name == "json_files") {
    return(x@files$path[x@files$type == "json"])
  }
  if (name == "define_path") {
    paths <- x@files$path[x@files$type == "define-xml"]
    return(if (length(paths) > 0L) paths[[1L]] else NULL)
  }
  if (name == "report_paths") {
    return(x@files$path[grepl("^report-", x@files$type)])
  }
  S7::prop(x, name)
}

#' @rdname herald_submission-methods
#' @export
`$<-.herald_submission` <- function(x, name, value) {
  S7::prop(x, name) <- value
  x
}

#' @rdname herald_submission-methods
#' @export
`[[.herald_submission` <- function(x, i, ...) {
  `$.herald_submission`(x, i)
}

# -- Print method ------------------------------------------------------------

#' @rdname herald_submission-methods
#' @export
print.herald_submission <- function(x, ...) {
  cli::cli_h2("herald submission")
  cli::cli_text("Output: {.path {x@output_dir}}")

  n_xpt <- sum(x@files$type == "xpt")
  n_json <- sum(x@files$type == "json")
  has_define <- any(x@files$type == "define-xml")

  if (n_xpt > 0L) {
    cli::cli_text("XPT files: {n_xpt}")
  }
  if (n_json > 0L) {
    cli::cli_text("JSON files: {n_json}")
  }
  if (has_define) {
    dp <- x@files$path[x@files$type == "define-xml"][[1L]]
    cli::cli_text("Define-XML: {.path {dp}}")
  }

  if (!is.null(x@validation) && inherits(x@validation, "herald_validation")) {
    v <- x@validation
    s <- v$summary
    n_err <- (s$reject %||% 0L) + (s$high %||% 0L)
    n_warn <- s$medium %||% 0L
    cli::cli_text(
      "Validation: {n_err} high-impact issue{?s}, {n_warn} medium-impact issue{?s}"
    )
  }

  if (length(x@manifest) > 0L) {
    cli::cli_text("Manifest: included")
  }

  invisible(x)
}
