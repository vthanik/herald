# --------------------------------------------------------------------------
# herald-conditions.R — structured error and warning conditions
# --------------------------------------------------------------------------
# Every herald error inherits from "herald_error" so callers can catch
# broadly or narrowly:
#   tryCatch(validate(...), herald_error_spec = handler, herald_error = fallback)

# -- Base conditions --------------------------------------------------------

#' Signal a herald error
#' @noRd
herald_error <- function(
  message,
  ...,
  class = character(),
  call = caller_env(),
  .envir = parent.frame()
) {
  cli::cli_abort(
    message,
    class = c(class, "herald_error"),
    ...,
    call = call,
    .envir = .envir
  )
}

#' Signal a herald warning
#' @noRd
herald_warning <- function(
  message,
  ...,
  class = character(),
  call = caller_env(),
  .envir = parent.frame()
) {
  cli::cli_warn(
    message,
    class = c(class, "herald_warning"),
    ...,
    call = call,
    .envir = .envir
  )
}

# -- File I/O ---------------------------------------------------------------

#' Signal a file-related error
#' @noRd
herald_error_file <- function(message, path = NULL, call = caller_env()) {
  herald_error(
    message,
    path = path,
    class = "herald_error_file",
    call = call,
    .envir = parent.frame()
  )
}

# -- Specification ----------------------------------------------------------

#' Signal a spec validation error
#' @noRd
herald_error_spec <- function(message, slot = NULL, call = caller_env()) {
  herald_error(
    message,
    slot = slot,
    class = "herald_error_spec",
    call = call,
    .envir = parent.frame()
  )
}

# -- XPT binary format ------------------------------------------------------

#' Signal an XPT format error
#' @noRd
herald_error_xpt <- function(message, call = caller_env()) {
  herald_error(
    message,
    class = "herald_error_xpt",
    call = call,
    .envir = parent.frame()
  )
}

# -- Rule engine -------------------------------------------------------------

#' Signal a rule parsing or execution error
#' @noRd
herald_error_rule <- function(message, rule_id = NULL, call = caller_env()) {
  herald_error(
    message,
    rule_id = rule_id,
    class = "herald_error_rule",
    call = call,
    .envir = parent.frame()
  )
}

# -- Validation engine -------------------------------------------------------

#' Signal a validation engine error
#' @noRd
herald_error_validation <- function(message, call = caller_env()) {
  herald_error(
    message,
    class = "herald_error_validation",
    call = call,
    .envir = parent.frame()
  )
}

# -- Define-XML --------------------------------------------------------------

#' Signal a Define-XML generation error
#' @noRd
herald_error_define <- function(message, call = caller_env()) {
  herald_error(
    message,
    class = "herald_error_define",
    call = call,
    .envir = parent.frame()
  )
}

# -- I/O (format-agnostic) --------------------------------------------------

#' Signal a generic I/O error (JSON, Parquet, CSV, etc.)
#' @noRd
herald_error_io <- function(message, path = NULL, call = caller_env()) {
  herald_error(
    message,
    path = path,
    class = "herald_error_io",
    call = call,
    .envir = parent.frame()
  )
}

# -- Runtime (internal assertion failures) -----------------------------------

#' Signal an unexpected internal/runtime error
#' @noRd
herald_error_runtime <- function(message, call = caller_env()) {
  herald_error(
    message,
    class = "herald_error_runtime",
    call = call,
    .envir = parent.frame()
  )
}

# -- Report generation -------------------------------------------------------

#' Signal a report-generation error
#' @noRd
herald_error_report <- function(message, call = caller_env()) {
  herald_error(
    message,
    class = "herald_error_report",
    call = call,
    .envir = parent.frame()
  )
}

# -- Missing soft dependency -------------------------------------------------

#' Signal that a suggested package is required but missing
#' @noRd
herald_error_missing_pkg <- function(pkg, purpose, call = caller_env()) {
  herald_error(
    c(
      "Package {.pkg {pkg}} is required {purpose}.",
      "i" = "Install with: {.code install.packages(\"{pkg}\")}"
    ),
    pkg = pkg,
    class = "herald_error_missing_pkg",
    call = call,
    .envir = parent.frame()
  )
}

# -- Convenience: require a soft dependency ----------------------------------

#' Check that a suggested package is available
#' @noRd
require_pkg <- function(pkg, purpose, call = caller_env()) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    herald_error_missing_pkg(pkg, purpose, call = call)
  }
}

# -- Input validation helpers ------------------------------------------------

#' Assert x is a scalar character string
#' @noRd
check_scalar_chr <- function(x, arg = caller_arg(x), call = caller_env()) {
  if (!rlang::is_scalar_character(x)) {
    herald_error(
      "{.arg {arg}} must be a single character string, not {.obj_type_friendly {x}}.",
      class = "herald_error_input",
      call = call
    )
  }
}

#' Assert x is a scalar positive integer
#' @noRd
check_scalar_int <- function(x, arg = caller_arg(x), call = caller_env()) {
  if (
    !is.numeric(x) ||
      length(x) != 1L ||
      is.na(x) ||
      x != as.integer(x) ||
      x < 1L
  ) {
    herald_error(
      "{.arg {arg}} must be a single positive integer.",
      class = "herald_error_input",
      call = call
    )
  }
}

#' Assert x is a data.frame
#' @noRd
check_data_frame <- function(x, arg = caller_arg(x), call = caller_env()) {
  if (!is.data.frame(x)) {
    herald_error(
      "{.arg {arg}} must be a data frame, not {.cls {class(x)}}.",
      class = "herald_error_input",
      call = call
    )
  }
}

#' Assert x is a herald_spec
#' @noRd
check_herald_spec <- function(x, arg = caller_arg(x), call = caller_env()) {
  if (!inherits(x, "herald_spec")) {
    herald_error(
      "{.arg {arg}} must be a {.cls herald_spec} object.",
      class = "herald_error_input",
      call = call
    )
  }
}

#' Assert x is a herald_validation
#' @noRd
check_herald_validation <- function(
  x,
  arg = caller_arg(x),
  call = caller_env()
) {
  if (!inherits(x, "herald_validation")) {
    herald_error(
      "{.arg {arg}} must be a {.cls herald_validation} object.",
      class = "herald_error_input",
      call = call
    )
  }
}

#' Assert a file exists and is readable
#' @noRd
check_file_exists <- function(path, call = caller_env()) {
  check_scalar_chr(path, arg = "path", call = call)
  if (!file.exists(path)) {
    herald_error_file(
      "File not found: {.path {path}}",
      path = path,
      call = call
    )
  }
}

#' Assert a directory exists
#' @noRd
check_dir_exists <- function(path, call = caller_env()) {
  check_scalar_chr(path, arg = "path", call = call)
  if (!dir.exists(path)) {
    herald_error_file(
      "Directory not found: {.path {path}}",
      path = path,
      call = call
    )
  }
}
