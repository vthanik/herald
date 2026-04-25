# --------------------------------------------------------------------------
# xpt-header.R — XPT binary header parsing + construction
# --------------------------------------------------------------------------
# Consolidates parse-header.R + build-header.R into one cohesive module.

#' Detect XPT version from the first 80-byte record
#' @noRd
detect_xpt_version <- function(rec1_str) {
  if (grepl("LIBRARY HEADER", rec1_str, fixed = TRUE)) {
    5L
  } else if (grepl("LIBV8", rec1_str, fixed = TRUE)) {
    8L
  } else {
    herald_error_xpt(
      "Not a valid XPT transport file: unrecognised library header."
    )
  }
}

#' Parse library header (reads 240 bytes = 3 x 80)
#' Returns list(version, created, modified)
#' @noRd
parse_library_header <- function(con) {
  rec1 <- read_bytes(con, 80L)
  rec1_str <- rawToChar(rec1)
  version <- detect_xpt_version(rec1_str)

  rec2 <- read_bytes(con, 80L)
  rec3 <- read_bytes(con, 80L)

  list(
    version = version,
    created = raw_to_str(rec2[65:80]),
    modified = raw_to_str(rec3[1:16])
  )
}

#' Read the next 80-byte record as a string
#' @noRd
read_record_str <- function(con) {
  rawToChar(read_bytes(con, 80L))
}

#' Parse member and descriptor headers
#' Returns list(name, label, type, nvars, version_markers)
#' or NULL if EOF
#' @noRd
parse_member_section <- function(con, version) {
  # Read MEMBER/MEMBV8 record
  rec <- tryCatch(read_bytes(con, 80L), error = function(e) NULL)
  if (is.null(rec)) {
    return(NULL)
  }

  rec_str <- rawToChar(rec)
  if (
    !grepl("MEMBER", rec_str, fixed = TRUE) &&
      !grepl("MEMBV8", rec_str, fixed = TRUE)
  ) {
    return(NULL)
  }

  # Read DSCRPTR/DSCPTV8 record
  read_bytes(con, 80L)

  # Read dataset identification (160 bytes = 2 x 80)
  desc1 <- read_bytes(con, 80L)
  desc2 <- read_bytes(con, 80L)

  if (version == 5L) {
    ds_name <- raw_to_str(desc1[9:16])
  } else {
    ds_name <- raw_to_str(desc1[9:40])
  }

  ds_label <- raw_to_str(desc2[33:72])
  ds_type <- raw_to_str(desc2[73:80])

  # Read NAMESTR/NAMSTV8 record
  namestr_rec <- read_record_str(con)
  nvars_str <- substr(namestr_rec, 53L, 58L)
  nvars <- vctrs::vec_cast(as.numeric(nvars_str), integer())

  list(
    name = ds_name,
    label = ds_label,
    type = ds_type,
    nvars = nvars
  )
}

#' Parse a single 140-byte namestr record
#' @noRd
parse_namestr <- function(raw140, version) {
  vartype <- s370fpib2_to_int(raw140[1:2])
  var_length <- s370fpib2_to_int(raw140[5:6])
  varnum <- s370fpib2_to_int(raw140[7:8])

  name <- raw_to_str(raw140[9:16])
  label <- raw_to_str(raw140[17:56])
  format_name <- raw_to_str(raw140[57:64])
  formatl <- s370fpib2_to_int(raw140[65:66])
  formatd <- s370fpib2_to_int(raw140[67:68])
  just <- s370fpib2_to_int(raw140[69:70])
  informat_name <- raw_to_str(raw140[73:80])
  informl <- s370fpib2_to_int(raw140[81:82])
  informd <- s370fpib2_to_int(raw140[83:84])
  npos <- s370fpib4_to_int(raw140[85:88])

  label_len <- nchar(label)
  fmtname_len <- nchar(format_name)
  infmtname_len <- nchar(informat_name)

  # V8: extended name from trailing area
  if (version == 8L) {
    name <- raw_to_str(raw140[89:120])
    label_len <- s370fpib2_to_int(raw140[121:122])
    fmtname_len <- s370fpib2_to_int(raw140[123:124])
    infmtname_len <- s370fpib2_to_int(raw140[125:126])
  }

  list(
    vartype = vartype,
    length = var_length,
    varnum = varnum,
    name = name,
    label = label,
    format_name = format_name,
    formatl = formatl,
    formatd = formatd,
    just = just,
    informat_name = informat_name,
    informl = informl,
    informd = informd,
    npos = npos,
    label_len = label_len,
    fmtname_len = fmtname_len,
    infmtname_len = infmtname_len
  )
}

#' Parse the complete namestr block (all variables + padding)
#' @noRd
parse_namestr_block <- function(con, nvars, version) {
  namestr_size <- 140L
  total_bytes <- nvars * namestr_size

  raw_block <- read_bytes(con, total_bytes)

  namestrs <- vector("list", nvars)
  for (i in seq_len(nvars)) {
    offset <- (i - 1L) * namestr_size
    raw140 <- raw_block[(offset + 1L):(offset + namestr_size)]
    namestrs[[i]] <- parse_namestr(raw140, version)
  }

  # Consume padding to 80-byte boundary
  remainder <- total_bytes %% 80L
  if (remainder > 0L) {
    read_bytes(con, 80L - remainder)
  }

  namestrs
}

#' Parse optional label extension records (V8 only)
#' @noRd
parse_label_extension <- function(con, rec_str, namestrs) {
  if (grepl("LABELV9", rec_str, fixed = TRUE)) {
    ext_type <- "LABELV9"
  } else if (grepl("LABELV8", rec_str, fixed = TRUE)) {
    ext_type <- "LABELV8"
  } else {
    return(namestrs)
  }

  n_ext <- vctrs::vec_cast(
    as.numeric(trimws(substr(rec_str, 49L, 80L))),
    integer()
  )

  total_bytes <- 0L
  for (i in seq_len(n_ext)) {
    if (ext_type == "LABELV8") {
      header <- read_bytes(con, 6L)
      total_bytes <- total_bytes + 6L
      varnum <- s370fpib2_to_int(header[1:2])
      name_len <- s370fpib2_to_int(header[3:4])
      label_len <- s370fpib2_to_int(header[5:6])
      data_raw <- read_bytes(con, name_len + label_len)
      total_bytes <- total_bytes + name_len + label_len
      new_label <- raw_to_str(data_raw[(name_len + 1L):(name_len + label_len)])
      namestrs[[varnum]]$label <- new_label
    } else {
      header <- read_bytes(con, 10L)
      total_bytes <- total_bytes + 10L
      varnum <- s370fpib2_to_int(header[1:2])
      name_len <- s370fpib2_to_int(header[3:4])
      label_len <- s370fpib2_to_int(header[5:6])
      fmt_len <- s370fpib2_to_int(header[7:8])
      infmt_len <- s370fpib2_to_int(header[9:10])
      data_len <- name_len + label_len + fmt_len + infmt_len
      data_raw <- read_bytes(con, data_len)
      total_bytes <- total_bytes + data_len
      pos <- 1L
      pos <- pos + name_len # skip name
      if (label_len > 0L) {
        namestrs[[varnum]]$label <- raw_to_str(data_raw[
          pos:(pos + label_len - 1L)
        ])
        pos <- pos + label_len
      }
      if (fmt_len > 0L) {
        # LABELV9 format is the full format string (e.g. "DATETIME20.")
        # Parse it to update name, length, and decimals consistently
        fmt_full <- raw_to_str(data_raw[pos:(pos + fmt_len - 1L)])
        fmt_parsed <- parse_format_str(fmt_full)
        namestrs[[varnum]]$format_name <- fmt_parsed$name
        namestrs[[varnum]]$formatl <- fmt_parsed$length
        namestrs[[varnum]]$formatd <- fmt_parsed$decimals
        pos <- pos + fmt_len
      }
      if (infmt_len > 0L) {
        infmt_full <- raw_to_str(data_raw[pos:(pos + infmt_len - 1L)])
        infmt_parsed <- parse_format_str(infmt_full)
        namestrs[[varnum]]$informat_name <- infmt_parsed$name
        namestrs[[varnum]]$informl <- infmt_parsed$length
        namestrs[[varnum]]$informd <- infmt_parsed$decimals
      }
    }
  }

  # Consume padding to 80-byte boundary
  remainder <- total_bytes %% 80L
  if (remainder > 0L) {
    read_bytes(con, 80L - remainder)
  }

  namestrs
}

#' Parse OBS header and determine observation count
#' @noRd
parse_obs_header <- function(rec_str, version) {
  if (grepl("OBSV8", rec_str, fixed = TRUE)) {
    nobs_str <- trimws(substr(rec_str, 49L, 63L))
    if (nzchar(nobs_str) && !grepl("^0+$", nobs_str)) {
      vctrs::vec_cast(as.numeric(nobs_str), integer())
    } else {
      NA_integer_
    }
  } else {
    NA_integer_
  }
}
# Binary header construction for XPT transport files
# All functions are @noRd (not exported)

#' Build library header (3 x 80 = 240 bytes)
#' @noRd
build_library_header <- function(version = 5L, created = Sys.time()) {
  if (version == 5L) {
    rec1 <- str_to_raw(
      "HEADER RECORD*******LIBRARY HEADER RECORD!!!!!!!000000000000000000000000000000",
      80L
    )
  } else {
    rec1 <- str_to_raw(
      "HEADER RECORD*******LIBV8   HEADER RECORD!!!!!!!000000000000000000000000000000",
      80L
    )
  }

  # Record 2: SAS identifier + OS + datetime
  os_id <- pad_to(substr(Sys.info()[["sysname"]], 1L, 8L), 8L)
  dt_str <- sas_datetime_str(created)
  rec2_str <- paste0(
    "SAS     SAS     SASLIB  9.4     ",
    os_id,
    strrep(" ", 24L),
    dt_str
  )
  rec2 <- str_to_raw(rec2_str, 80L)

  # Record 3: modified datetime + spaces
  rec3 <- str_to_raw(dt_str, 80L)

  c(rec1, rec2, rec3)
}

#' Build member header (5 x 80 = 400 bytes)
#' @noRd
build_member_header <- function(
  name,
  label = "",
  type = "DATA",
  nvars,
  version = 5L,
  created = Sys.time()
) {
  os_id <- pad_to(substr(Sys.info()[["sysname"]], 1L, 8L), 8L)
  dt_str <- sas_datetime_str(created)

  if (version == 5L) {
    rec1 <- str_to_raw(
      "HEADER RECORD*******MEMBER  HEADER RECORD!!!!!!!000000000000000001600000000140",
      80L
    )
    rec2 <- str_to_raw(
      "HEADER RECORD*******DSCRPTR HEADER RECORD!!!!!!!000000000000000000000000000000",
      80L
    )
    # Record 3: dataset identification
    ds_name <- pad_to(toupper(substr(name, 1L, 8L)), 8L)
    rec3_str <- paste0(
      "SAS     ",
      ds_name,
      "SASDATA 9.4     ",
      os_id,
      strrep(" ", 24L),
      dt_str
    )
  } else {
    rec1 <- str_to_raw(
      "HEADER RECORD*******MEMBV8  HEADER RECORD!!!!!!!000000000000000001600000000140",
      80L
    )
    rec2 <- str_to_raw(
      "HEADER RECORD*******DSCPTV8 HEADER RECORD!!!!!!!000000000000000000000000000000",
      80L
    )
    ds_name <- pad_to(substr(name, 1L, 32L), 32L)
    rec3_str <- paste0(
      "SAS     ",
      ds_name,
      "SASDATA 9.4     ",
      os_id,
      dt_str
    )
  }
  rec3 <- str_to_raw(rec3_str, 80L)

  # Record 4: datetime + spaces(16) + label(40) + type(8)
  rec4_str <- paste0(
    dt_str,
    strrep(" ", 16L),
    pad_to(label, 40L),
    pad_to(type, 8L)
  )
  rec4 <- str_to_raw(rec4_str, 80L)

  # Record 5: NAMESTR marker with nvars count
  # V5 spec: 6 zeros then 4-digit count at positions 55-58
  # V8: same layout with 6-digit count field at positions 53-58
  # Trailing positions filled with zeros (ASCII '0', not space)
  nvars_str <- formatC(nvars, width = 4L, format = "d", flag = "0")
  if (version == 5L) {
    rec5_str <- paste0(
      "HEADER RECORD*******NAMESTR HEADER RECORD!!!!!!!000000",
      nvars_str,
      "0000000000000000000000"
    )
  } else {
    nvars_str <- formatC(nvars, width = 6L, format = "d", flag = "0")
    rec5_str <- paste0(
      "HEADER RECORD*******NAMSTV8 HEADER RECORD!!!!!!!0000",
      nvars_str,
      "0000000000000000000000"
    )
  }
  rec5 <- str_to_raw(rec5_str, 80L)

  c(rec1, rec2, rec3, rec4, rec5)
}

#' Build a single namestr record (exactly 140 bytes)
#' @noRd
build_namestr <- function(
  vartype,
  var_length,
  varnum,
  name,
  label = "",
  format_name = "",
  formatl = 0L,
  formatd = 0L,
  informat_name = "",
  informl = 0L,
  informd = 0L,
  npos = 0L,
  version = 5L
) {
  # Justification: numeric = right (1), character = left (0)
  just <- if (vartype == 1L) 1L else 0L

  # V5: uppercase names
  if (version == 5L) {
    name <- toupper(name)
  }

  buf <- c(
    int_to_s370fpib2(vartype), # type (2)
    as.raw(c(0x00, 0x00)), # padding (2)
    int_to_s370fpib2(var_length), # length (2)
    int_to_s370fpib2(varnum), # varnum (2)
    str_to_raw(name, 8L), # name (8) - always 8 in namestr
    str_to_raw(label, 40L), # label (40)
    str_to_raw(format_name, 8L), # format name (8)
    int_to_s370fpib2(formatl), # format length (2)
    int_to_s370fpib2(formatd), # format decimals (2)
    int_to_s370fpib2(just), # justification (2)
    as.raw(c(0x00, 0x00)), # padding (2)
    str_to_raw(informat_name, 8L), # informat name (8)
    int_to_s370fpib2(informl), # informat length (2)
    int_to_s370fpib2(informd), # informat decimals (2)
    int_to_s370fpib4(npos) # byte position (4)
  )

  if (version == 5L) {
    # 52 zero bytes trailer
    buf <- c(buf, raw(52L))
  } else {
    # V8: 32-char extended name + 2 bytes label_len + 2 bytes fmtname_len +
    # 2 bytes infmtname_len + 14 zero bytes
    buf <- c(
      buf,
      str_to_raw(name, 32L), # extended name (32)
      int_to_s370fpib2(nchar(label)), # label length (2)
      int_to_s370fpib2(nchar(format_name)), # format name length (2)
      int_to_s370fpib2(nchar(informat_name)), # informat name length (2)
      raw(14L) # padding (14)
    )
  }

  buf
}

#' Build the complete namestr block for a data.frame
#' @noRd
build_namestr_block <- function(data, version = 5L) {
  col_names <- names(data)
  ncols <- length(col_names)
  npos <- 0L

  namestr_list <- vector("list", ncols)

  for (i in seq_len(ncols)) {
    col <- data[[i]]
    nm <- col_names[i]

    if (is.numeric(col)) {
      vartype <- 1L
      var_length <- 8L
    } else {
      vartype <- 2L
      max_len <- max(
        nchar(col, type = "bytes", allowNA = TRUE),
        1L,
        na.rm = TRUE
      )
      var_length <- vctrs::vec_cast(max_len, integer())
    }

    col_label <- attr(col, "label") %||% ""
    col_format <- attr(col, "format.sas") %||% ""
    col_informat <- attr(col, "informat.sas") %||% ""

    # Parse format into name, length, decimals
    fmt_parsed <- parse_format_str(col_format)
    infmt_parsed <- parse_format_str(col_informat)

    namestr_list[[i]] <- build_namestr(
      vartype = vartype,
      var_length = var_length,
      varnum = vctrs::vec_cast(i, integer()),
      name = nm,
      label = col_label,
      format_name = fmt_parsed$name,
      formatl = fmt_parsed$length,
      formatd = fmt_parsed$decimals,
      informat_name = infmt_parsed$name,
      informl = infmt_parsed$length,
      informd = infmt_parsed$decimals,
      npos = npos,
      version = version
    )

    npos <- npos + var_length
  }

  # Concatenate all namestrs and pad to 80-byte boundary
  raw_block <- unlist(namestr_list, use.names = FALSE)
  pad_record(raw_block, 80L)
}

#' Parse a SAS format string like "8.2", "DATE9.", "$CHAR20.", or "E8601DT26.6"
#'
#' SAS format names can contain embedded digits (e.g. E8601DT, B8601DA).
#' The format string structure is: name + optional_width + "." + optional_decimals.
#' We parse by finding the trailing ".decimals" then separating the width digits
#' from the name working backwards.
#' @noRd
parse_format_str <- function(fmt) {
  if (is.null(fmt) || !nzchar(fmt)) {
    return(list(name = "", length = 0L, decimals = 0L))
  }

  # Find trailing period (with optional decimals after it)
  dot_match <- regexpr("\\.[0-9]*$", fmt)

  if (dot_match > 0L) {
    before_dot <- substr(fmt, 1L, dot_match - 1L)
    after_dot <- substr(fmt, dot_match + 1L, nchar(fmt))

    fmt_dec <- if (nzchar(after_dot)) as.integer(after_dot) else 0L

    # Extract trailing digits from before_dot as the width
    width_match <- regexpr("[0-9]+$", before_dot)
    if (width_match > 0L) {
      fmt_name <- substr(before_dot, 1L, width_match - 1L)
      fmt_len <- as.integer(substr(before_dot, width_match, nchar(before_dot)))
    } else {
      fmt_name <- before_dot
      fmt_len <- 0L
    }
  } else {
    # No period (e.g. haven stores "DATETIME16" not "DATETIME16.").
    # Try to split trailing digits as the width so the name is recoverable.
    width_match <- regexpr("[0-9]+$", fmt)
    if (width_match > 0L) {
      fmt_name <- substr(fmt, 1L, width_match - 1L)
      fmt_len <- as.integer(substr(fmt, width_match, nchar(fmt)))
    } else {
      fmt_name <- fmt
      fmt_len <- 0L
    }
    fmt_dec <- 0L
  }

  list(name = fmt_name, length = fmt_len, decimals = fmt_dec)
}

#' Build OBS header record (80 bytes)
#' @noRd
build_obs_header <- function(nobs = 0L, version = 5L) {
  if (version == 5L) {
    str_to_raw(
      paste0(
        "HEADER RECORD*******OBS     HEADER RECORD!!!!!!!",
        strrep("0", 32L)
      ),
      80L
    )
  } else {
    nobs_str <- formatC(nobs, width = 15L, format = "d", flag = " ")
    str_to_raw(
      paste0(
        "HEADER RECORD*******OBSV8   HEADER RECORD!!!!!!!",
        nobs_str,
        strrep(" ", 17L)
      ),
      80L
    )
  }
}

#' Build label extension records (V8 only)
#' Returns empty raw if no extensions needed
#' @noRd
build_label_extension <- function(data, version = 5L) {
  if (version == 5L) {
    return(raw(0L))
  }

  col_names <- names(data)
  needs_ext <- logical(length(col_names))
  has_long_fmt <- FALSE

  for (i in seq_along(col_names)) {
    col <- data[[col_names[i]]]
    lbl <- attr(col, "label") %||% ""
    fmt <- attr(col, "format.sas") %||% ""
    infmt <- attr(col, "informat.sas") %||% ""

    if (nchar(lbl) > 40L || nchar(fmt) > 8L || nchar(infmt) > 8L) {
      needs_ext[i] <- TRUE
      if (nchar(fmt) > 8L || nchar(infmt) > 8L) has_long_fmt <- TRUE
    }
  }

  n_ext <- sum(needs_ext)
  if (n_ext == 0L) {
    return(raw(0L))
  }

  ext_type <- if (has_long_fmt) "LABELV9" else "LABELV8"

  # Header record
  header_str <- paste0(
    "HEADER RECORD*******",
    pad_to(ext_type, 7L),
    " HEADER RECORD!!!!!!!",
    formatC(n_ext, width = 30L, format = "d", flag = " ")
  )
  header_raw <- str_to_raw(header_str, 80L)

  # Collect extension chunks in a list, then unlist once (avoids O(n^2) c())
  ext_chunks <- vector("list", n_ext)
  chunk_idx <- 0L
  for (i in seq_along(col_names)) {
    if (!needs_ext[i]) {
      next
    }
    chunk_idx <- chunk_idx + 1L

    col <- data[[col_names[i]]]
    nm <- col_names[i]
    lbl <- attr(col, "label") %||% ""
    fmt <- attr(col, "format.sas") %||% ""
    infmt <- attr(col, "informat.sas") %||% ""

    name_raw <- charToRaw(nm)
    label_raw <- charToRaw(lbl)
    varnum_raw <- int_to_s370fpib2(vctrs::vec_cast(i, integer()))

    if (ext_type == "LABELV8") {
      ext_chunks[[chunk_idx]] <- c(
        varnum_raw,
        int_to_s370fpib2(length(name_raw)),
        int_to_s370fpib2(length(label_raw)),
        name_raw,
        label_raw
      )
    } else {
      fmt_raw <- charToRaw(fmt)
      infmt_raw <- charToRaw(infmt)
      ext_chunks[[chunk_idx]] <- c(
        varnum_raw,
        int_to_s370fpib2(length(name_raw)),
        int_to_s370fpib2(length(label_raw)),
        int_to_s370fpib2(length(fmt_raw)),
        int_to_s370fpib2(length(infmt_raw)),
        name_raw,
        label_raw,
        fmt_raw,
        infmt_raw
      )
    }
  }

  # Pad extension data to 80-byte boundary
  ext_data <- pad_record(unlist(ext_chunks, use.names = FALSE), 80L)

  c(header_raw, ext_data)
}
