#' Read a SAS Transport (XPT) file into a data frame
#'
#' Reads V5 (FDA standard) or V8 (extended) XPT transport files into R data
#' frames. Pure R implementation  --  no SAS or haven dependency.
#'
#' @param file File path to an \code{.xpt} file.
#' @param col_select Character vector of column names to read. `NULL` (default)
#'   reads all columns.
#' @param n_max Maximum number of rows to read. `Inf` (default) reads all rows.
#' @param encoding Character encoding of the XPT file. Defaults to
#'   `"wlatin1"` (SAS WLATIN1 = Windows-1252), which is the standard encoding
#'   for SAS on Windows and a superset of 7-bit ASCII. Accepts SAS encoding
#'   names (`"wlatin1"`, `"latin1"`, `"utf-8"`, `"shift-jis"`), aliases
#'   (`"wlt1"`, `"sjis"`), or standard names (`"WINDOWS-1252"`,
#'   `"ISO-8859-1"`). Set to `NULL` to pass bytes through without conversion.
#'
#' @details
#' ## Date/datetime conversion
#' Numeric columns with a SAS date or datetime format are automatically
#' converted to R `Date` or `POSIXct` classes using the SAS epoch
#' (1960-01-01). The conversion is based on the `format.sas` attribute
#' stored in the XPT file header (NAMESTR record).
#'
#' Date formats (e.g. `DATE9.`, `MMDDYY10.`, `YYMMDD10.`, `E8601DA.`)
#' produce R `Date` values. Datetime formats (e.g. `DATETIME20.`,
#' `E8601DT.`, `DATEAMPM.`) produce R `POSIXct` values in UTC.
#'
#' The `format.sas` attribute is preserved on converted columns for
#' round-trip fidelity with `write_xpt()`.
#'
#' ## SAS missing values
#' - Numeric SAS missing values (`.`, `.A`-`.Z`, `._`) are read as `NA_real_`.
#'   For date/datetime columns these become `NA` dates.
#' - Character blanks (all spaces) are read as `NA_character_`.
#'
#' ## Attributes
#' - Column labels are stored as the `"label"` attribute on each column.
#' - SAS formats are stored as the `"format.sas"` attribute on each column.
#' - The dataset label is stored as the `"label"` attribute on the data frame.
#'
#' ## Character encoding
#' XPT files contain no encoding metadata. SAS on Windows defaults to WLATIN1
#' (Windows-1252), an extended ASCII encoding that is a superset of 7-bit
#' ASCII. By default, `read_xpt()` converts WLATIN1 bytes to UTF-8. This is a
#' no-op for pure ASCII files (all bytes < 0x80 are identical) and correctly
#' handles extended characters commonly found in clinical data.
#'
#' Supported SAS encoding names:
#' \tabular{lll}{
#'   SAS name \tab Alias \tab Standard name \cr
#'   wlatin1  \tab wlt1  \tab WINDOWS-1252  \cr
#'   latin1   \tab lat1  \tab ISO-8859-1    \cr
#'   utf-8    \tab utf8  \tab UTF-8         \cr
#'   us-ascii \tab ansi  \tab US-ASCII      \cr
#'   wlatin2  \tab wlt2  \tab WINDOWS-1250  \cr
#'   wcyrillic\tab wcyr  \tab WINDOWS-1251  \cr
#'   shift-jis\tab sjis  \tab CP932         \cr
#'   euc-jp   \tab jeuc  \tab EUC-JP        \cr
#' }
#'
#' WLATIN1 extended ASCII characters commonly found in clinical data:
#' \tabular{lll}{
#'   Byte \tab Unicode \tab Description          \cr
#'   0x91 \tab U+2018  \tab Left single quote    \cr
#'   0x92 \tab U+2019  \tab Right single quote   \cr
#'   0x93 \tab U+201C  \tab Left double quote    \cr
#'   0x94 \tab U+201D  \tab Right double quote   \cr
#'   0x96 \tab U+2013  \tab En dash              \cr
#'   0x97 \tab U+2014  \tab Em dash              \cr
#'   0x85 \tab U+2026  \tab Horizontal ellipsis  \cr
#'   0x99 \tab U+2122  \tab Trademark            \cr
#'   0xA9 \tab U+00A9  \tab Copyright            \cr
#'   0xAE \tab U+00AE  \tab Registered           \cr
#'   0xB0 \tab U+00B0  \tab Degree sign          \cr
#'   0xB1 \tab U+00B1  \tab Plus-minus           \cr
#'   0xB5 \tab U+00B5  \tab Micro sign           \cr
#'   0xD7 \tab U+00D7  \tab Multiplication sign  \cr
#'   0xE9 \tab U+00E9  \tab Latin small e acute  \cr
#'   0xF1 \tab U+00F1  \tab Latin small n tilde  \cr
#'   0xFC \tab U+00FC  \tab Latin small u umlaut \cr
#' }
#' See the full WLATIN1 map at
#' \url{https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP1252.TXT}.
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
#' @return A data frame for single-member files (with `attr(df, "label")`,
#'   `attr(df, "dataset_name")`, and per-column `"label"`, `"format.sas"`,
#'   `"sas.length"`, `"xpt_type"` attributes populated from the XPT header),
#'   or a named list of data frames for multi-member files.
#'
#' @examples
#' dm  <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
#' spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
#' dm  <- apply_spec(dm, spec)
#' tmp <- tempfile(fileext = ".xpt")
#' on.exit(unlink(tmp))
#' write_xpt(dm, tmp)
#' dm2 <- read_xpt(tmp)
#' attr(dm2, "label")
#' attr(dm2$USUBJID, "label")
#'
#' @seealso [write_xpt()] to write, [read_json()], [read_parquet()],
#'   [apply_spec()] to stamp CDISC attributes after reading.
#' @family io
#' @export
read_xpt <- function(
  file,
  col_select = NULL,
  n_max = Inf,
  encoding = "wlatin1"
) {
  call <- rlang::caller_env()
  encoding <- resolve_encoding(encoding)
  path <- file # internal alias  --  internal helpers use 'path'

  if (!file.exists(file)) {
    herald_error_xpt(
      "File {.path {file}} does not exist.",
      call = call
    )
  }

  con <- base::file(file, "rb")
  on.exit(close(con))

  # Parse library header
  lib_header <- parse_library_header(con)
  version <- lib_header$version

  # Read all members
  members <- list()
  repeat {
    # Try to read next record
    next_rec <- tryCatch(read_bytes(con, 80L), error = function(e) NULL)
    if (is.null(next_rec)) {
      break
    }

    next_str <- rawToChar(next_rec)

    # Check if this is a MEMBER header
    if (
      !grepl("MEMBER", next_str, fixed = TRUE) &&
        !grepl("MEMBV8", next_str, fixed = TRUE)
    ) {
      break
    }

    # Read DSCRPTR/DSCPTV8 record
    read_bytes(con, 80L)

    # Read dataset identification (2 x 80 bytes)
    desc1 <- read_bytes(con, 80L)
    desc2 <- read_bytes(con, 80L)

    if (version == 5L) {
      ds_name <- raw_to_str(desc1[9:16])
    } else {
      ds_name <- raw_to_str(desc1[9:40])
    }
    ds_label <- raw_to_str(desc2[33:72])

    # Read NAMESTR/NAMSTV8 record
    namestr_rec_str <- read_record_str(con)
    nvars <- vctrs::vec_cast(
      as.numeric(substr(namestr_rec_str, 53L, 58L)),
      integer()
    )

    # Parse namestrs
    namestrs <- parse_namestr_block(con, nvars, version)

    # Check for label extension or OBS header
    next_hdr <- read_record_str(con)
    if (
      grepl("LABELV8", next_hdr, fixed = TRUE) ||
        grepl("LABELV9", next_hdr, fixed = TRUE)
    ) {
      namestrs <- parse_label_extension(con, next_hdr, namestrs)
      next_hdr <- read_record_str(con)
    }

    # Parse OBS header
    nobs <- parse_obs_header(next_hdr, version)

    # Compute observation length
    obs_length <- sum(vapply(namestrs, function(ns) ns$length, integer(1L)))

    # Read observation data
    df <- read_observations(
      con,
      namestrs,
      nobs,
      obs_length,
      col_select,
      n_max,
      version,
      path,
      encoding
    )

    # Set dataset-level attributes
    if (nzchar(ds_label)) {
      attr(df, "label") <- ds_label
    }
    attr(df, "dataset_name") <- ds_name

    members[[ds_name]] <- df
  }

  if (length(members) == 0L) {
    herald_error_xpt("No datasets found in {.path {path}}.", call = call)
  }

  if (length(members) == 1L) {
    members[[1L]]
  } else {
    members
  }
}

#' Read observation data from the XPT file
#' @noRd
read_observations <- function(
  con,
  namestrs,
  nobs,
  obs_length,
  col_select,
  n_max,
  version,
  path,
  encoding
) {
  nvars <- length(namestrs)

  # If nobs unknown (V5), compute from data section size
  if (is.na(nobs)) {
    if (obs_length > 0L) {
      nobs <- compute_v5_nobs(con, obs_length, path)
    } else {
      nobs <- 0L
    }
  }

  # Apply n_max
  nobs_to_read <- min(nobs, n_max)

  if (nobs_to_read == 0L || obs_length == 0L) {
    # Build empty data frame with correct columns
    cols <- vector("list", nvars)
    col_names <- character(nvars)
    for (j in seq_len(nvars)) {
      ns <- namestrs[[j]]
      col_names[j] <- ns$name
      if (ns$vartype == 1L) {
        cols[[j]] <- numeric(0L)
      } else {
        cols[[j]] <- character(0L)
      }
    }
    names(cols) <- col_names
    return(set_column_attrs(vctrs::new_data_frame(cols), namestrs, col_select))
  }

  # Read all observation data at once
  total_data_bytes <- nobs_to_read * obs_length
  all_data <- read_bytes(con, total_data_bytes)

  # Skip remaining rows and padding
  remaining_obs <- nobs - nobs_to_read
  skip_bytes <- remaining_obs * obs_length
  total_written <- nobs * obs_length
  padding <- (80L - (total_written %% 80L)) %% 80L
  skip_total <- skip_bytes + padding
  if (skip_total > 0L) {
    tryCatch(read_bytes(con, skip_total), error = function(e) NULL)
  }

  # Parse into columns
  cols <- vector("list", nvars)
  col_names <- character(nvars)

  # Reshape the flat byte stream into a matrix (obs_length rows x nobs_to_read
  # columns). Each column is one observation record. Row-slice extraction then
  # replaces per-column strided index vectors, eliminating large integer
  # allocations that scale with nobs x var_len.
  raw_mat <- matrix(all_data, nrow = obs_length, ncol = nobs_to_read)

  for (j in seq_len(nvars)) {
    ns <- namestrs[[j]]
    col_names[j] <- ns$name

    var_len <- ns$length
    row_from <- ns$npos + 1L
    row_to <- ns$npos + var_len

    if (ns$vartype == 1L) {
      # Numeric: extract var_len bytes per observation and zero-pad to 8 bytes.
      # as.vector() unrolls column-major -> [b0..bN 0..0 b0..bN 0..0 ...],
      # which is the flat layout expected by ibm_to_ieee().
      var_rows <- raw_mat[row_from:row_to, , drop = FALSE]
      if (var_len < 8L) {
        var_rows <- rbind(
          var_rows,
          matrix(as.raw(0x00), nrow = 8L - var_len, ncol = nobs_to_read)
        )
      }
      cols[[j]] <- ibm_to_ieee(as.vector(var_rows))
    } else {
      # Character: pass the raw matrix slice directly to .raw_mat_to_strvec.
      cols[[j]] <- .raw_mat_to_strvec(
        raw_mat[row_from:row_to, , drop = FALSE],
        encoding
      )
    }
  }

  names(cols) <- col_names

  # Detect non-UTF-8 bytes when no encoding specified
  if (is.null(encoding) && nobs_to_read > 0L) {
    bad_cols <- character(0L)
    for (j in seq_len(nvars)) {
      if (is.character(cols[[j]])) {
        if (any(!vapply(cols[[j]], validUTF8, logical(1L)))) {
          bad_cols <- c(bad_cols, col_names[j])
        }
      }
    }
    if (length(bad_cols) > 0L) {
      cli::cli_inform(c(
        "!" = "Non-UTF-8 bytes detected in column{?s}: {.field {bad_cols}}.",
        "i" = paste0(
          "Set {.arg encoding} to convert, e.g. ",
          "{.code read_xpt(path, encoding = \"latin1\")}."
        )
      ))
    }
  }

  df <- vctrs::new_data_frame(
    cols,
    n = vctrs::vec_cast(nobs_to_read, integer())
  )
  set_column_attrs(df, namestrs, col_select)
}

#' Set column attributes (label, format.sas) and apply column selection
#' @noRd
set_column_attrs <- function(df, namestrs, col_select) {
  for (j in seq_along(namestrs)) {
    ns <- namestrs[[j]]
    nm <- ns$name

    # Set label
    if (nzchar(ns$label)) {
      attr(df[[nm]], "label") <- ns$label
    }

    # Set sas.length
    if (ns$length > 0L) {
      attr(df[[nm]], "sas.length") <- ns$length
    }

    # Set format / informat
    fmt_str <- build_format_string(ns$format_name, ns$formatl, ns$formatd)
    if (nzchar(fmt_str)) {
      attr(df[[nm]], "format.sas") <- fmt_str
    }
    infmt_str <- build_format_string(ns$informat_name, ns$informl, ns$informd)
    if (nzchar(infmt_str)) {
      attr(df[[nm]], "informat.sas") <- infmt_str
    }

    # Convert date/datetime/time numerics (format_name is already the parsed name)
    if (ns$vartype == 1L && nzchar(ns$format_name)) {
      if (is_sas_date_format(ns$format_name)) {
        df <- convert_preserving_attrs(df, nm, sas_date_to_r)
      } else if (is_sas_datetime_format(ns$format_name)) {
        df <- convert_preserving_attrs(df, nm, sas_datetime_to_r)
      } else if (is_sas_time_format(ns$format_name)) {
        df <- convert_preserving_attrs(df, nm, sas_time_to_r)
      }
    }

    # Convert character blanks to NA
    if (ns$vartype == 2L) {
      df[[nm]][!nzchar(df[[nm]])] <- NA_character_
    }
  }

  # Column selection
  if (!is.null(col_select)) {
    keep <- intersect(col_select, names(df))
    df <- df[keep]
  }

  df
}

#' Compute V5 nobs by reading data and scanning for member boundary or EOF
#'
#' Reads remaining data in 80-byte records, looking for the next MEMBER header
#' to determine where data ends. Then trims trailing all-space observations
#' (which are padding bytes). Seeks back to the original position.
#' @noRd
compute_v5_nobs <- function(con, obs_length, path) {
  start_pos <- seek(con, where = NA)
  file_size <- file.info(path)$size
  remaining <- file_size - start_pos

  if (remaining <= 0L) {
    return(0L)
  }

  # Read all remaining bytes
  all_raw <- readBin(con, what = "raw", n = remaining)

  # Scan 80-byte records for a MEMBER header
  data_bytes <- length(all_raw)
  n_records <- data_bytes %/% 80L

  # The MEMBER header starts with "HEADER RECORD*******MEMBER" (ASCII, no nulls)
  # Compare raw bytes directly to avoid rawToChar null issues
  member_v5_sig <- charToRaw("HEADER RECORD*******MEMBER")
  member_v8_sig <- charToRaw("HEADER RECORD*******MEMBV8")
  sig_len <- length(member_v5_sig)

  for (r in seq_len(n_records)) {
    rec_start <- (r - 1L) * 80L + 1L
    rec_sig <- all_raw[rec_start:(rec_start + sig_len - 1L)]
    if (
      identical(rec_sig, member_v5_sig) || identical(rec_sig, member_v8_sig)
    ) {
      data_bytes <- (r - 1L) * 80L
      break
    }
  }

  # Now data_bytes is the total data section (data + padding, up to the next member)
  max_nobs <- data_bytes %/% obs_length

  # Trim trailing all-space observations (padding)
  if (obs_length < 80L && max_nobs > 0L) {
    while (max_nobs > 0L) {
      obs_start <- (max_nobs - 1L) * obs_length + 1L
      obs_end <- max_nobs * obs_length
      if (all(all_raw[obs_start:obs_end] == as.raw(0x20))) {
        max_nobs <- max_nobs - 1L
      } else {
        break
      }
    }
  }

  # Seek back to start so read_observations can read the data
  seek(con, where = start_pos)

  max_nobs
}

#' Build a SAS format string from name, length, decimals
#' @noRd
build_format_string <- function(name, len, dec) {
  if (!nzchar(name) && len == 0L && dec == 0L) {
    return("")
  }
  out <- name
  if (len > 0L) {
    out <- paste0(out, len)
  }
  out <- paste0(out, ".")
  if (dec > 0L) {
    out <- paste0(out, dec)
  }
  out
}
