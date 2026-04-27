#' Write a data frame to a SAS Transport (XPT) file
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Writes a data frame (or named list of data frames) to an XPT
#' transport file in V5 (FDA submission standard) or V8 (extended)
#' format. Pure R implementation -- no SAS, no haven, no Java
#' dependency. Round-trips dataset / variable labels, SAS formats,
#' SAS lengths, and `Date` / `POSIXct` columns.
#'
#' If the \code{herald.sort_keys} attribute is set on \code{x}, the data is
#' sorted by those keys before writing.
#'
#' @param x A data frame, or a named list of data frames for multiple
#'   members.
#' @param file File path for the output \code{.xpt} file.
#' @param version Transport format version: \code{5} (default, FDA standard) or
#'   \code{8} (extended names/labels).
#' @param dataset Dataset name (e.g., \code{"DM"}). Default: the
#'   \code{"dataset_name"} attribute of \code{x} (set by \code{read_xpt()},
#'   \code{read_json()}, or \code{apply_spec()}), then the uppercase file stem
#'   (\code{"sdtm/dm.xpt"} -> \code{"DM"}), then \code{"DATA"}.
#'   V5: max 8 characters, uppercased. V8: max 32 characters.
#' @param label Dataset label. Defaults to \code{attr(x, "label")} or \code{""}.
#' @param encoding Character encoding for the output file. Defaults to
#'   \code{"wlatin1"} (SAS WLATIN1 = Windows-1252), which converts UTF-8
#'   characters to extended ASCII for SAS compatibility. Accepts SAS encoding
#'   names (\code{"wlatin1"}, \code{"latin1"}, \code{"utf-8"}, \code{"shift-jis"})
#'   or standard names (\code{"WINDOWS-1252"}, \code{"ISO-8859-1"}). Set to
#'   \code{NULL} to write bytes as-is without conversion.
#'
#' @details
#' ## Date/datetime handling
#' R `Date` columns are converted to SAS date values (days since 1960-01-01)
#' and automatically assigned `format.sas = "DATE9."` unless the column
#' already has a `format.sas` attribute. Similarly, `POSIXct` columns are
#' converted to SAS datetime values (seconds since 1960-01-01 00:00:00 UTC)
#' with `format.sas = "DATETIME20."`. The `format.sas` attribute is written
#' into the XPT NAMESTR header so SAS recognizes the variable as a date.
#' Informats are not auto-set (matching SAS behaviour); set `informat.sas`
#' on the column before writing if needed.
#'
#' ## SAS missing values
#' - Numeric `NA`, `NaN`, `Inf`, `-Inf` are written as SAS missing (`.`).
#'   `NA` dates and datetimes are also written as SAS missing.
#' - Character `NA` values are written as blank strings (spaces).
#'
#' ## V5 constraints
#' Variable names must be at most 8 characters (A-Z, 0-9, underscore only),
#' character variables at most 200 bytes, labels at most 40 characters.
#' All names are uppercased.
#'
#' ## V8 extensions
#' Variable names up to 32 characters with mixed case. Labels up to 256
#' characters via LABELV8/LABELV9 extension records.
#'
#' ## Character encoding
#' By default, \code{write_xpt()} converts UTF-8 character data to WLATIN1
#' (Windows-1252) before writing. This ensures the XPT file is compatible
#' with SAS sessions using the default WLATIN1 encoding. For pure ASCII data,
#' the conversion is a no-op. See \code{\link{read_xpt}()} for the full
#' encoding reference table.
#'
#' @references
#' \itemize{
#'   \item SAS V5 transport format specification:
#'     \url{https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/movefile/n0167z9rttw8dyn15z1qqe8eiwzf.htm}
#'   \item SAS V8 transport format specification:
#'     \url{https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/movefile/p0ld1i106e1xm7n16eefi7qgj8m9.htm}
#'   \item Full WLATIN1 (Windows-1252) character map:
#'     \url{https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP1252.TXT}
#'   \item IANA character set registry:
#'     \url{https://www.iana.org/assignments/character-sets/character-sets.xhtml}
#' }
#'
#' @return `x` invisibly (the input data frame, not the file path).
#'
#' @examples
#' dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
#' spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
#' dm   <- apply_spec(dm, spec)
#' tmp  <- tempfile(fileext = ".xpt")
#' on.exit(unlink(tmp))
#'
#' # ---- V5 (FDA standard) -- dataset name inferred from variable symbol (dm -> "DM") ----
#' write_xpt(dm, tmp)
#' attr(read_xpt(tmp), "dataset_name")   # "DM"
#'
#' # ---- V8 (extended names up to 32 chars) ------------------------------
#' tmp8 <- tempfile(fileext = ".xpt")
#' on.exit(unlink(tmp8), add = TRUE)
#' write_xpt(dm, tmp8, version = 8L)
#'
#' # ---- Explicit dataset name and label overrides -----------------------
#' tmp3 <- tempfile(fileext = ".xpt")
#' on.exit(unlink(tmp3), add = TRUE)
#' write_xpt(dm, tmp3, dataset = "DM", label = "Demographics")
#' attr(read_xpt(tmp3), "label")
#'
#' # ---- Plain data frame (no prior apply_spec) -- name from file stem ----
#' ae <- data.frame(STUDYID = "X", USUBJID = "X-001", stringsAsFactors = FALSE)
#' tmp_ae <- tempfile(fileext = ".xpt")
#' on.exit(unlink(tmp_ae), add = TRUE)
#' write_xpt(ae, tmp_ae, dataset = "AE", label = "Adverse Events")
#' attr(read_xpt(tmp_ae), "dataset_name")  # "AE"
#'
#' @seealso [read_xpt()] to read, [write_json()], [write_parquet()],
#'   [convert_dataset()] to convert between formats.
#' @family io
#' @export
write_xpt <- function(
  x,
  file,
  version = 5,
  dataset = NULL,
  label = NULL,
  encoding = "wlatin1"
) {
  x_expr <- rlang::enexpr(x)
  call <- rlang::caller_env()
  encoding <- resolve_encoding(encoding)
  version <- vctrs::vec_cast(version, integer())

  # Sort by herald.sort_keys if set (from apply_spec or sort_keys)
  if (is.data.frame(x)) {
    sort_keys <- attr(x, "herald.sort_keys")
    if (!is.null(sort_keys) && length(sort_keys) > 0L) {
      present_keys <- sort_keys[sort_keys %in% names(x)]
      if (length(present_keys) > 0L) {
        x <- x[do.call(order, x[present_keys]), , drop = FALSE]
        rownames(x) <- NULL
      }
    }
  }

  data <- x # local alias for existing write logic below

  # Resolve dataset name: explicit arg -> dataset_name attr -> variable symbol -> file stem -> "DATA"
  name <- dataset
  if (is.null(name)) {
    ds_attr <- attr(x, "dataset_name")
    if (!is.null(ds_attr) && length(ds_attr) == 1L) {
      name <- ds_attr
    } else if (is.symbol(x_expr)) {
      cand <- as.character(x_expr)
      if (grepl("^[A-Za-z_][A-Za-z0-9_]*$", cand)) name <- toupper(cand)
    }
  }
  if (is.null(name)) {
    name <- toupper(tools::file_path_sans_ext(basename(file)))
    name <- gsub("[^A-Za-z0-9_]", "", name)
    if (!nzchar(name)) name <- "DATA"
  }
  if (version == 5L) {
    name <- toupper(substr(name, 1L, 8L))
  } else {
    name <- substr(name, 1L, 32L)
  }

  # Resolve label
  if (is.null(label)) {
    label <- attr(data, "label") %||% ""
  }

  # Handle list of data frames (multiple members)
  if (is.list(data) && !is.data.frame(data)) {
    write_xpt_multi(data, file, version, call, encoding)
    return(invisible(x))
  }

  # Coerce types
  data <- coerce_xpt_types(data, version, call)

  # Validate
  validate_write_inputs(data, file, version, name, label, call = call)

  # Write
  con <- base::file(file, "wb")
  on.exit(close(con))

  created <- Sys.time()

  writeBin(build_library_header(version, created), con)
  writeBin(
    build_member_header(name, label, "DATA", ncol(data), version, created),
    con
  )
  writeBin(build_namestr_block(data, version), con)
  ext <- build_label_extension(data, version)
  if (length(ext) > 0L) {
    writeBin(ext, con)
  }
  writeBin(build_obs_header(nrow(data), version), con)
  write_observations(data, con, version, encoding)

  invisible(x)
}

#' Write multiple members to a single XPT file
#' @noRd
write_xpt_multi <- function(data_list, file, version, call, encoding = NULL) {
  member_names <- names(data_list)
  if (is.null(member_names)) {
    member_names <- paste0("DATA", seq_along(data_list))
  }

  con <- base::file(file, "wb")
  on.exit(close(con))
  created <- Sys.time()

  writeBin(build_library_header(version, created), con)

  for (i in seq_along(data_list)) {
    df <- data_list[[i]]
    if (!is.data.frame(df)) {
      herald_error_xpt(
        "Element {i} of {.arg data} must be a data frame.",
        call = call
      )
    }

    df <- coerce_xpt_types(df, version, call)
    nm <- member_names[i]
    if (version == 5L) {
      nm <- toupper(substr(nm, 1L, 8L))
    } else {
      nm <- substr(nm, 1L, 32L)
    }

    lbl <- attr(df, "label") %||% ""

    writeBin(
      build_member_header(nm, lbl, "DATA", ncol(df), version, created),
      con
    )
    writeBin(build_namestr_block(df, version), con)
    ext <- build_label_extension(df, version)
    if (length(ext) > 0L) {
      writeBin(ext, con)
    }
    writeBin(build_obs_header(nrow(df), version), con)
    write_observations(df, con, version, encoding)
  }
}

#' Coerce data frame columns for XPT compatibility
#' @noRd
coerce_xpt_types <- function(data, version, call) {
  for (nm in names(data)) {
    col <- data[[nm]]

    if (is.factor(col)) {
      herald_error_xpt(
        c(
          "Column {.var {nm}} is a factor.",
          "i" = "Convert to character first with {.code as.character()}."
        ),
        call = call
      )
    } else if (inherits(col, "POSIXct")) {
      default_fmt <- attr(col, "format.sas") %||% "DATETIME20."
      data <- convert_preserving_attrs(data, nm, function(x) {
        as.numeric(x) - as.numeric(.sas_env$epoch_posixct)
      })
      attr(data[[nm]], "format.sas") <- default_fmt
    } else if (inherits(col, "Date")) {
      default_fmt <- attr(col, "format.sas") %||% "DATE9."
      data <- convert_preserving_attrs(data, nm, function(x) {
        as.numeric(x - .sas_env$epoch_date)
      })
      attr(data[[nm]], "format.sas") <- default_fmt
    } else if (inherits(col, "difftime")) {
      # Time values (e.g. ATM from ADaM)  --  store as seconds since midnight
      default_fmt <- attr(col, "format.sas") %||% "TIME8."
      data <- convert_preserving_attrs(data, nm, function(x) {
        as.numeric(x, units = "secs")
      })
      attr(data[[nm]], "format.sas") <- default_fmt
    } else if (is.logical(col)) {
      data[[nm]] <- vctrs::vec_cast(col, double())
    }
  }

  data
}

#' Write observation data to connection
#' @noRd
write_observations <- function(data, con, version, encoding = NULL) {
  nrows <- nrow(data)
  ncols <- ncol(data)

  if (nrows == 0L || ncols == 0L) {
    return(invisible(NULL))
  }

  # Pre-compute column metadata and pre-convert all column data
  col_info <- vector("list", ncols)
  ibm_data <- vector("list", ncols)
  char_raw_data <- vector("list", ncols)

  for (j in seq_len(ncols)) {
    col <- data[[j]]
    if (is.numeric(col)) {
      col_info[[j]] <- list(type = "numeric", length = 8L)
      ibm_data[[j]] <- ieee_to_ibm(col)
    } else {
      # Vectorized iconv  --  one call per column instead of per cell
      if (!is.null(encoding) && nzchar(encoding)) {
        col <- iconv(col, from = "UTF-8", to = encoding, sub = "byte")
      }
      bytes_per_val <- nchar(col, type = "bytes", allowNA = TRUE)
      bytes_per_val[is.na(bytes_per_val)] <- 0L
      max_len <- max(c(bytes_per_val, 1L), na.rm = TRUE)
      len <- vctrs::vec_cast(max_len, integer())
      col_info[[j]] <- list(type = "character", length = len)

      # Vectorised packing: NA -> empty, truncate to len bytes, right-pad with spaces.
      # One charToRaw call for the whole column; strrep handles variable-width padding.
      col_clean <- col
      col_clean[is.na(col_clean)] <- ""
      needs_trunc <- bytes_per_val > len
      if (any(needs_trunc)) {
        col_clean[needs_trunc] <- substr(col_clean[needs_trunc], 1L, len)
        bytes_per_val[needs_trunc] <- len
      }
      col_clean <- paste0(col_clean, strrep(" ", len - bytes_per_val))
      char_raw_data[[j]] <- charToRaw(paste0(col_clean, collapse = ""))
    }
  }

  obs_length <- sum(vapply(col_info, function(ci) ci$length, integer(1L)))

  # Vectorised observation assembly: place each column's bytes at strided
  # positions in the output buffer rather than looping row-by-row.
  # For column j with byte width `len` starting at `col_offset` within each
  # observation record, the destination bytes for all nrows observations are:
  #   rep(row_starts, each=len) + rep.int(0:(len-1), nrows)
  # This is equivalent to as.integer(outer(0:(len-1), row_starts-1, "+")) + 1
  # but avoids the intermediate matrix allocation and as.integer() copy.
  buf <- raw(obs_length * nrows)
  col_offset <- 0L

  for (j in seq_len(ncols)) {
    len <- col_info[[j]]$length
    row_starts <- seq(col_offset + 1L, by = obs_length, length.out = nrows)
    dest_idx <- rep(row_starts, each = len) + rep.int(0L:(len - 1L), nrows)

    if (col_info[[j]]$type == "numeric") {
      buf[dest_idx] <- ibm_data[[j]]
    } else {
      buf[dest_idx] <- char_raw_data[[j]]
    }

    col_offset <- col_offset + len
  }

  writeBin(buf, con)

  # Pad to 80-byte boundary
  total_bytes <- nrows * obs_length
  remainder <- total_bytes %% 80L
  if (remainder > 0L) {
    writeBin(rep(as.raw(0x20), 80L - remainder), con)
  }
}
