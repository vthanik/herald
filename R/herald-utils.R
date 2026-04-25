# --------------------------------------------------------------------------
# herald-utils.R  --  shared internal utilities
# --------------------------------------------------------------------------
# Consolidates helpers.R + validate-input.R into one file.
# XPT binary helpers, byte conversion, SAS datetime, file I/O.

# -- String / raw byte helpers -----------------------------------------------

#' Pad or truncate a string to exact width
#' @noRd
pad_to <- function(x, width, fill = " ") {
  x <- vctrs::vec_cast(x, character())
  n <- nchar(x)
  if (n > width) {
    substr(x, 1L, width)
  } else if (n < width) {
    paste0(x, strrep(fill, width - n))
  } else {
    x
  }
}

#' Pad a raw vector to the next multiple of `boundary` with ASCII spaces
#' @noRd
pad_record <- function(raw_vec, boundary = 80L) {
  remainder <- length(raw_vec) %% boundary
  if (remainder == 0L) {
    return(raw_vec)
  }
  padding <- vctrs::vec_rep(as.raw(0x20), boundary - remainder)
  c(raw_vec, padding)
}

#' Convert string to raw vector of exact width, right-padded with ASCII spaces
#' @noRd
str_to_raw <- function(x, width) {
  x <- pad_to(vctrs::vec_cast(x, character()), width)
  charToRaw(x)
}

# -- Integer <-> raw byte conversion (S370 big-endian) -----------------------

#' Convert integer to 2-byte big-endian raw (S370FPIB2)
#' @noRd
int_to_s370fpib2 <- function(x) {
  writeBin(vctrs::vec_cast(x, integer()), raw(), size = 2L, endian = "big")
}

#' Convert integer to 4-byte big-endian raw (S370FPIB4)
#' @noRd
int_to_s370fpib4 <- function(x) {
  writeBin(vctrs::vec_cast(x, integer()), raw(), size = 4L, endian = "big")
}

#' Convert 2-byte big-endian raw to integer
#' @noRd
s370fpib2_to_int <- function(raw2) {
  readBin(raw2, what = integer(), size = 2L, n = 1L, endian = "big")
}

#' Convert 4-byte big-endian raw to integer
#' @noRd
s370fpib4_to_int <- function(raw4) {
  readBin(raw4, what = integer(), size = 4L, n = 1L, endian = "big")
}

# -- Raw -> string conversion ------------------------------------------------

#' Convert raw bytes to trimmed character string (headers  --  always ASCII)
#' @noRd
raw_to_str <- function(raw_vec) {
  raw_vec <- raw_vec[raw_vec != as.raw(0x00)]
  if (length(raw_vec) == 0L) {
    return("")
  }
  s <- rawToChar(raw_vec)
  sub(" +$", "", s)
}

#' Convert raw bytes to trimmed character string with optional encoding conversion
#' @noRd
raw_to_str_enc <- function(raw_vec, encoding = NULL) {
  raw_vec <- raw_vec[raw_vec != as.raw(0x00)]
  if (length(raw_vec) == 0L) {
    return("")
  }
  s <- rawToChar(raw_vec)
  if (!is.null(encoding) && nzchar(encoding)) {
    s <- iconv(s, from = encoding, to = "UTF-8", sub = "byte")
    sub(" +$", "", s)
  } else {
    sub(" +$", "", s, useBytes = TRUE)
  }
}

#' Vectorised conversion: raw matrix (var_len x nobs) -> character vector
#'
#' Encoding path: one `rawToChar` of the flat byte array, marked as `"latin1"`
#' so `substring` uses byte offsets (1 byte = 1 char in single-byte encodings).
#' Split first, then `iconv()` on the character vector at C level. Avoids
#' quadratic UTF-8 char-scanning of `substring()` on an iconv'd UTF-8 string,
#' and avoids O(nobs) R-level dispatch of `apply(rawToChar)`.
#'
#' No-encoding path: `apply(raw_mat, 2L, rawToChar)`  --  safe for non-UTF-8 bytes.
#' @noRd
.raw_mat_to_strvec <- function(raw_mat, encoding = NULL) {
  var_len <- nrow(raw_mat)
  nobs <- ncol(raw_mat)
  if (nobs == 0L) {
    return(character(0L))
  }

  # Replace null bytes (SAS pad) with spaces so rawToChar sees full-width cells.
  raw_mat[raw_mat == as.raw(0x00)] <- as.raw(0x20)

  if (!is.null(encoding) && nzchar(encoding)) {
    # Mark as latin1 so substring uses byte offsets, not UTF-8 char scanning.
    # SAS source encodings (WLATIN1, latin1, ASCII) are single-byte: 1 byte = 1 char.
    # Split first at byte boundaries, then iconv each piece at C level.
    flat <- rawToChar(as.raw(raw_mat))
    Encoding(flat) <- "latin1"
    starts <- (seq_len(nobs) - 1L) * var_len + 1L
    out <- substring(flat, starts, starts + var_len - 1L)
    out <- iconv(out, from = encoding, to = "UTF-8", sub = "byte")
    sub(" +$", "", out)
  } else {
    # No encoding conversion  --  pass bytes through unchanged.
    # apply gives one rawToChar per observation, safe for non-UTF-8 bytes.
    out <- apply(raw_mat, 2L, rawToChar)
    sub(" +$", "", out, useBytes = TRUE)
  }
}

# -- SAS datetime formatting -------------------------------------------------

#' Format POSIXct as 16-char SAS datetime string (ddMMMyy:hh:mm:ss)
#' @noRd
sas_datetime_str <- function(time = Sys.time()) {
  toupper(format(time, "%d%b%y:%H:%M:%S", tz = "UTC"))
}

# -- File I/O helpers --------------------------------------------------------

#' Read exactly n bytes from a connection, error if short
#' @noRd
read_bytes <- function(con, n) {
  raw_vec <- readBin(con, what = "raw", n = n)
  if (length(raw_vec) < n) {
    herald_error_xpt(
      "Unexpected end of file: expected {n} bytes, got {length(raw_vec)}."
    )
  }
  raw_vec
}

# -- HTML escape (used by val-report.R) --------------------------------------

#' Escape HTML special characters
#' @noRd
htmlesc <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}

# -- XPT write input validation ----------------------------------------------

#' Master validation for write_xpt() inputs
#' @noRd
validate_write_inputs <- function(
  data,
  path,
  version,
  name,
  label,
  call = rlang::caller_env()
) {
  check_data_frame(data, call = call)
  check_scalar_chr(path, call = call)

  parent_dir <- dirname(path)
  if (!dir.exists(parent_dir)) {
    herald_error_file(
      "Directory {.path {parent_dir}} does not exist.",
      path = parent_dir,
      call = call
    )
  }

  check_scalar_int(version, call = call)
  version <- vctrs::vec_cast(version, integer())
  if (!version %in% c(5L, 8L)) {
    herald_error_xpt(
      "{.arg version} must be 5 or 8, not {version}.",
      call = call
    )
  }

  check_scalar_chr(name, call = call)
  check_scalar_chr(label, call = call)

  # Column types must be numeric or character (or coercible)
  col_types <- vapply(
    data,
    function(col) {
      if (is.numeric(col)) {
        "numeric"
      } else if (is.character(col)) {
        "character"
      } else if (is.factor(col)) {
        "factor"
      } else if (inherits(col, "Date")) {
        "Date"
      } else if (inherits(col, "POSIXct")) {
        "POSIXct"
      } else {
        class(col)[[1L]]
      }
    },
    character(1L)
  )

  unsupported <- col_types[
    !col_types %in% c("numeric", "character", "factor", "Date", "POSIXct")
  ]
  if (length(unsupported) > 0L) {
    bad_cols <- names(unsupported)
    bad_types <- unname(unsupported)
    detail <- paste0(bad_cols, " (", bad_types, ")", collapse = ", ")
    herald_error_xpt(
      c(
        "All columns must be numeric, character, factor, Date, or POSIXct.",
        "x" = "Unsupported columns: {detail}."
      ),
      call = call
    )
  }

  if (version == 5L) {
    validate_v5_compliance(data, name, call = call)
  } else {
    validate_v8_compliance(data, name, call = call)
  }

  invisible(TRUE)
}

#' Validate V5 transport compliance
#' @noRd
validate_v5_compliance <- function(data, name, call = rlang::caller_env()) {
  valid_chars_re <- "^[A-Z0-9_]+$"

  if (nchar(name) > 8L) {
    herald_error_xpt(
      c(
        "V5 transport requires dataset name {.le 8} characters.",
        "x" = "Dataset name {.val {name}} is {nchar(name)} characters."
      ),
      call = call
    )
  }
  if (!grepl(valid_chars_re, toupper(name))) {
    herald_error_xpt(
      c(
        "V5 transport requires dataset name to contain only A-Z, 0-9, and underscore.",
        "x" = "Dataset name {.val {name}} contains invalid characters."
      ),
      call = call
    )
  }

  col_names <- names(data)
  long_names <- col_names[nchar(col_names) > 8L]
  if (length(long_names) > 0L) {
    herald_error_xpt(
      c(
        "V5 transport requires variable names {.le 8} characters.",
        "x" = "Variable{?s} {.var {long_names}} exceed{?s/} 8 characters."
      ),
      call = call
    )
  }

  bad_names <- col_names[!grepl(valid_chars_re, toupper(col_names))]
  if (length(bad_names) > 0L) {
    herald_error_xpt(
      c(
        "V5 transport requires variable names to contain only A-Z, 0-9, and underscore.",
        "x" = "Variable{?s} {.var {bad_names}} contain{?s/} invalid characters."
      ),
      call = call
    )
  }

  for (nm in col_names) {
    col <- data[[nm]]
    if (is.character(col)) {
      max_bytes <- max(
        nchar(col, type = "bytes", allowNA = TRUE),
        0L,
        na.rm = TRUE
      )
      if (max_bytes > 200L) {
        herald_error_xpt(
          c(
            "V5 transport requires character variables {.le 200} bytes.",
            "x" = "Variable {.var {nm}} has maximum length {max_bytes} bytes."
          ),
          call = call
        )
      }
    }
  }

  for (nm in col_names) {
    lbl <- attr(data[[nm]], "label")
    if (!is.null(lbl) && nchar(lbl) > 40L) {
      herald_error_xpt(
        c(
          "V5 transport requires variable labels {.le 40} characters.",
          "x" = "Label for {.var {nm}} is {nchar(lbl)} characters."
        ),
        call = call
      )
    }
  }

  for (nm in col_names) {
    fmt <- attr(data[[nm]], "format.sas")
    if (!is.null(fmt)) {
      fmt_name <- extract_format_name(fmt)
      if (nchar(fmt_name) > 8L) {
        herald_error_xpt(
          c(
            "V5 transport requires format names {.le 8} characters.",
            "x" = "Format name {.val {fmt_name}} for {.var {nm}} is {nchar(fmt_name)} characters."
          ),
          call = call
        )
      }
    }
  }

  invisible(TRUE)
}

#' Validate V8 transport compliance
#' @noRd
validate_v8_compliance <- function(data, name, call = rlang::caller_env()) {
  if (nchar(name) > 32L) {
    herald_error_xpt(
      c(
        "V8 transport requires dataset name {.le 32} characters.",
        "x" = "Dataset name {.val {name}} is {nchar(name)} characters."
      ),
      call = call
    )
  }

  col_names <- names(data)
  long_names <- col_names[nchar(col_names) > 32L]
  if (length(long_names) > 0L) {
    herald_error_xpt(
      c(
        "V8 transport requires variable names {.le 32} characters.",
        "x" = "Variable{?s} {.var {long_names}} exceed{?s/} 32 characters."
      ),
      call = call
    )
  }

  invisible(TRUE)
}
