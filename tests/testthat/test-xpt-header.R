# --------------------------------------------------------------------------
# test-xpt-header.R -- tests for xpt-header.R (XPT header build/parse)
# --------------------------------------------------------------------------

# -- From test-build-header.R --------------------------------------------------

test_that("build_library_header produces 240 bytes for V5", {
  result <- build_library_header(version = 5L)
  expect_equal(length(result), 240L)
  # First record starts with LIBRARY marker
  rec1 <- rawToChar(result[1:20])
  expect_equal(rec1, "HEADER RECORD*******")
  expect_true(grepl("LIBRARY", rawToChar(result[1:80]), fixed = TRUE))
})

test_that("build_library_header produces 240 bytes for V8", {
  result <- build_library_header(version = 8L)
  expect_equal(length(result), 240L)
  expect_true(grepl("LIBV8", rawToChar(result[1:80]), fixed = TRUE))
})

test_that("build_library_header contains SAS identifier", {
  result <- build_library_header(version = 5L)
  rec2 <- rawToChar(result[81:160])
  expect_true(grepl("SAS", rec2, fixed = TRUE))
  expect_true(grepl("SASLIB", rec2, fixed = TRUE))
  expect_true(grepl("9.4", rec2, fixed = TRUE))
})

test_that("build_member_header produces 400 bytes for V5", {
  result <- build_member_header(
    name = "TEST",
    label = "My data",
    nvars = 3L,
    version = 5L
  )
  expect_equal(length(result), 400L)
  # Check MEMBER marker
  expect_true(grepl("MEMBER", rawToChar(result[1:80]), fixed = TRUE))
  # Check DSCRPTR marker
  expect_true(grepl("DSCRPTR", rawToChar(result[81:160]), fixed = TRUE))
  # Check NAMESTR marker with nvars
  rec5 <- rawToChar(result[321:400])
  expect_true(grepl("NAMESTR", rec5, fixed = TRUE))
  expect_true(grepl("000003", rec5, fixed = TRUE))
})

test_that("build_member_header uppercases name in V5", {
  result <- build_member_header(
    name = "mydata",
    label = "",
    nvars = 1L,
    version = 5L
  )
  rec3 <- rawToChar(result[161:240])
  expect_true(grepl("MYDATA", rec3, fixed = TRUE))
})

test_that("build_member_header preserves case in V8", {
  result <- build_member_header(
    name = "MyData",
    label = "",
    nvars = 1L,
    version = 8L
  )
  rec3 <- rawToChar(result[161:240])
  expect_true(grepl("MyData", rec3, fixed = TRUE))
})

test_that("build_member_header produces V8 markers", {
  result <- build_member_header(
    name = "TEST",
    label = "",
    nvars = 1L,
    version = 8L
  )
  expect_equal(length(result), 400L)
  expect_true(grepl("MEMBV8", rawToChar(result[1:80]), fixed = TRUE))
  expect_true(grepl("DSCPTV8", rawToChar(result[81:160]), fixed = TRUE))
  expect_true(grepl("NAMSTV8", rawToChar(result[321:400]), fixed = TRUE))
})

test_that("build_namestr produces exactly 140 bytes", {
  result <- build_namestr(
    vartype = 1L,
    var_length = 8L,
    varnum = 1L,
    name = "AGE",
    version = 5L
  )
  expect_equal(length(result), 140L)
})

test_that("build_namestr encodes numeric type correctly", {
  result <- build_namestr(
    vartype = 1L,
    var_length = 8L,
    varnum = 1L,
    name = "AGE",
    version = 5L
  )
  # First 2 bytes = type = 1 (big-endian)
  expect_equal(result[1:2], as.raw(c(0x00, 0x01)))
  # Bytes 5-6 = length = 8
  expect_equal(result[5:6], as.raw(c(0x00, 0x08)))
})

test_that("build_namestr encodes character type correctly", {
  result <- build_namestr(
    vartype = 2L,
    var_length = 20L,
    varnum = 2L,
    name = "NAME",
    version = 5L
  )
  # Type = 2
  expect_equal(result[1:2], as.raw(c(0x00, 0x02)))
  # Length = 20
  expect_equal(s370fpib2_to_int(result[5:6]), 20L)
  # Varnum = 2
  expect_equal(s370fpib2_to_int(result[7:8]), 2L)
})

test_that("build_namestr uppercases name in V5", {
  result <- build_namestr(
    vartype = 1L,
    var_length = 8L,
    varnum = 1L,
    name = "age",
    version = 5L
  )
  name_raw <- result[9:16]
  expect_equal(rawToChar(name_raw[1:3]), "AGE")
})

test_that("build_namestr_block is padded to 80-byte boundary", {
  df <- data.frame(X = 1:3, Y = c("a", "b", "c"))
  result <- build_namestr_block(df, version = 5L)
  expect_equal(length(result) %% 80L, 0L)
  # 2 vars x 140 bytes = 280 bytes, padded to 320 (4 x 80)
  expect_equal(length(result), 320L)
})

test_that("build_obs_header produces 80 bytes for V5", {
  result <- build_obs_header(version = 5L)
  expect_equal(length(result), 80L)
  expect_true(grepl("OBS", rawToChar(result), fixed = TRUE))
})

test_that("build_obs_header produces 80 bytes for V8", {
  result <- build_obs_header(nobs = 100L, version = 8L)
  expect_equal(length(result), 80L)
  expect_true(grepl("OBSV8", rawToChar(result), fixed = TRUE))
})

test_that("parse_format_str parses empty format", {
  result <- parse_format_str("")
  expect_equal(result$name, "")
  expect_equal(result$length, 0L)
  expect_equal(result$decimals, 0L)
})

test_that("parse_format_str parses numeric format", {
  result <- parse_format_str("8.2")
  expect_equal(result$length, 8L)
  expect_equal(result$decimals, 2L)
})

test_that("parse_format_str parses named format", {
  result <- parse_format_str("DATE9.")
  expect_equal(result$name, "DATE")
  expect_equal(result$length, 9L)
})

# -- From test-parse-header.R --------------------------------------------------

test_that("detect_xpt_version identifies V5", {
  rec <- rawToChar(str_to_raw(
    "HEADER RECORD*******LIBRARY HEADER RECORD!!!!!!!000000000000000000000000000000",
    80L
  ))
  expect_equal(detect_xpt_version(rec), 5L)
})

test_that("detect_xpt_version identifies V8", {
  rec <- rawToChar(str_to_raw(
    "HEADER RECORD*******LIBV8   HEADER RECORD!!!!!!!000000000000000000000000000000",
    80L
  ))
  expect_equal(detect_xpt_version(rec), 8L)
})

test_that("detect_xpt_version rejects invalid header", {
  expect_error(detect_xpt_version("GARBAGE"), class = "herald_error_xpt")
})

test_that("parse_library_header round-trips with build for V5", {
  tmp <- withr::local_tempfile()

  header <- build_library_header(version = 5L)
  writeBin(header, tmp)

  con <- file(tmp, "rb")
  on.exit(close(con), add = TRUE)
  result <- parse_library_header(con)

  expect_equal(result$version, 5L)
  expect_true(nzchar(result$created))
})

test_that("parse_library_header round-trips with build for V8", {
  tmp <- withr::local_tempfile()

  header <- build_library_header(version = 8L)
  writeBin(header, tmp)

  con <- file(tmp, "rb")
  on.exit(close(con), add = TRUE)
  result <- parse_library_header(con)

  expect_equal(result$version, 8L)
})

test_that("parse_namestr round-trips with build_namestr for V5", {
  raw140 <- build_namestr(
    vartype = 1L,
    var_length = 8L,
    varnum = 1L,
    name = "age",
    label = "Subject Age",
    format_name = "8.2",
    version = 5L
  )

  parsed <- parse_namestr(raw140, version = 5L)

  expect_equal(parsed$vartype, 1L)
  expect_equal(parsed$length, 8L)
  expect_equal(parsed$varnum, 1L)
  expect_equal(parsed$name, "AGE")
  expect_equal(parsed$label, "Subject Age")
})

test_that("parse_namestr round-trips for character variable", {
  raw140 <- build_namestr(
    vartype = 2L,
    var_length = 20L,
    varnum = 2L,
    name = "SITEID",
    version = 5L
  )

  parsed <- parse_namestr(raw140, version = 5L)

  expect_equal(parsed$vartype, 2L)
  expect_equal(parsed$length, 20L)
  expect_equal(parsed$name, "SITEID")
})

test_that("parse_namestr_block reads correct number of vars", {
  df <- data.frame(X = 1:3, Y = c("a", "b", "c"))
  block <- build_namestr_block(df, version = 5L)

  tmp <- withr::local_tempfile()
  writeBin(block, tmp)

  con <- file(tmp, "rb")
  on.exit(close(con), add = TRUE)
  namestrs <- parse_namestr_block(con, 2L, version = 5L)

  expect_length(namestrs, 2L)
  expect_equal(namestrs[[1]]$name, "X")
  expect_equal(namestrs[[2]]$name, "Y")
  expect_equal(namestrs[[1]]$vartype, 1L)
  expect_equal(namestrs[[2]]$vartype, 2L)
})

# -- From test-xpt-header-extra.R ----------------------------------------------

# Helper: build a V8 namestr for a given name/label
make_v8_namestr <- function(
  name = "STUDYID",
  label = "Study ID",
  vartype = 2L,
  var_length = 12L,
  varnum = 1L,
  format_name = "",
  npos = 0L
) {
  herald:::build_namestr(
    vartype = vartype,
    var_length = var_length,
    varnum = varnum,
    name = name,
    label = label,
    format_name = format_name,
    version = 8L,
    npos = npos
  )
}

# -- parse_member_section: V5 (ds_name bytes 9:16) ----------------------------

test_that("parse_member_section V5: dataset name and row count round-trip", {
  tmp <- withr::local_tempfile(fileext = ".xpt")

  df <- data.frame(STUDYID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  suppressMessages(suppressWarnings(
    write_xpt(df, tmp, dataset = "DM", version = 5L)
  ))
  expect_true(file.exists(tmp))

  result <- suppressMessages(suppressWarnings(read_xpt(tmp)))
  expect_equal(nrow(result), 1L)
  expect_true("STUDYID" %in% names(result))
  expect_true("AGE" %in% names(result))
  expect_equal(result$STUDYID, "S1", ignore_attr = TRUE)
})

test_that("parse_member_section V5: multiple rows round-trip", {
  tmp <- withr::local_tempfile(fileext = ".xpt")

  df <- data.frame(
    STUDYID = c("S1", "S1", "S1"),
    USUBJID = c("S1-001", "S1-002", "S1-003"),
    stringsAsFactors = FALSE
  )
  suppressMessages(suppressWarnings(
    write_xpt(df, tmp, dataset = "AE", version = 5L)
  ))

  result <- suppressMessages(suppressWarnings(read_xpt(tmp)))
  expect_equal(nrow(result), 3L)
  expect_equal(
    result$USUBJID,
    c("S1-001", "S1-002", "S1-003"),
    ignore_attr = TRUE
  )
})

# -- parse_member_section: V8 (ds_name bytes 9:40) ----------------------------

test_that("parse_member_section V8: dataset name byte slice (9:40) round-trip", {
  tmp <- withr::local_tempfile(fileext = ".xpt")

  df <- data.frame(STUDYID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  suppressMessages(suppressWarnings(
    write_xpt(df, tmp, dataset = "DM", version = 8L)
  ))
  expect_true(file.exists(tmp))

  result <- suppressMessages(suppressWarnings(read_xpt(tmp)))
  expect_equal(nrow(result), 1L)
  expect_true("STUDYID" %in% names(result))
})

test_that("parse_member_section V8: dataset name with spaces round-trip", {
  tmp <- withr::local_tempfile(fileext = ".xpt")

  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  suppressMessages(suppressWarnings(
    write_xpt(df, tmp, dataset = "LB", version = 8L)
  ))

  result <- suppressMessages(suppressWarnings(read_xpt(tmp)))
  expect_equal(nrow(result), 1L)
  expect_true("X" %in% names(result))
})

# -- parse_label_extension: LABELV8 (label > 40 chars, format <= 8 chars) -----
# Also exercises build_label_extension lines 628-634 (LABELV8 chunk building)

test_that("parse_label_extension LABELV8: long label (>40) preserved on read", {
  tmp <- withr::local_tempfile(fileext = ".xpt")

  long_label <- paste(rep("A", 55), collapse = "") # 55 chars > 40
  df <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  attr(df$STUDYID, "label") <- long_label

  suppressMessages(suppressWarnings(
    write_xpt(df, tmp, dataset = "DM", version = 8L)
  ))
  expect_true(file.size(tmp) > 0L)

  result <- suppressMessages(suppressWarnings(read_xpt(tmp)))
  expect_true("STUDYID" %in% names(result))
  recovered <- attr(result$STUDYID, "label")
  expect_true(!is.null(recovered) && nchar(recovered) > 0L)
})

test_that("build_label_extension LABELV8 chunk + parse_label_extension LABELV8: multiple columns", {
  tmp <- withr::local_tempfile(fileext = ".xpt")

  long_label1 <- strrep("X", 45L) # > 40 chars, triggers LABELV8
  long_label2 <- strrep("Y", 42L)
  df <- data.frame(
    VARONE = "A",
    VARTWO = 1L,
    stringsAsFactors = FALSE
  )
  attr(df$VARONE, "label") <- long_label1
  attr(df$VARTWO, "label") <- long_label2

  suppressMessages(suppressWarnings(
    write_xpt(df, tmp, dataset = "DM", version = 8L)
  ))

  result <- suppressMessages(suppressWarnings(read_xpt(tmp)))
  expect_equal(nrow(result), 1L)
  expect_true("VARONE" %in% names(result))
  expect_true("VARTWO" %in% names(result))
  # Labels should be non-empty (truncation or full preservation)
  lbl1 <- attr(result$VARONE, "label")
  lbl2 <- attr(result$VARTWO, "label")
  expect_true(!is.null(lbl1) && nchar(lbl1) > 0L)
  expect_true(!is.null(lbl2) && nchar(lbl2) > 0L)
})

test_that("build_label_extension LABELV8: short format does not promote to LABELV9", {
  tmp <- withr::local_tempfile(fileext = ".xpt")

  df <- data.frame(DT = "2024-01-01", stringsAsFactors = FALSE)
  attr(df$DT, "label") <- strrep("B", 50L) # long label => LABELV8
  attr(df$DT, "format.sas") <- "DATE9." # format <= 8 chars, stays LABELV8

  suppressMessages(suppressWarnings(
    write_xpt(df, tmp, dataset = "DM", version = 8L)
  ))

  result <- suppressMessages(suppressWarnings(read_xpt(tmp)))
  expect_true("DT" %in% names(result))
  lbl <- attr(result$DT, "label")
  expect_true(!is.null(lbl) && nchar(lbl) > 0L)
})

# -- parse_label_extension: LABELV9 (format > 8 chars) ------------------------
# Also exercises build_label_extension else branch (LABELV9 chunk with fmt/infmt)

test_that("parse_label_extension LABELV9: long format name, label, and informat preserved", {
  tmp <- withr::local_tempfile(fileext = ".xpt")

  df <- data.frame(ADTM = as.character(Sys.time()), stringsAsFactors = FALSE)
  attr(df$ADTM, "label") <- "Analysis Datetime"
  attr(df$ADTM, "format.sas") <- "DATETIME20." # > 8 chars => LABELV9

  suppressMessages(suppressWarnings(
    write_xpt(df, tmp, dataset = "ADSL", version = 8L)
  ))
  expect_true(file.size(tmp) > 0L)

  result <- suppressMessages(suppressWarnings(read_xpt(tmp)))
  expect_true("ADTM" %in% names(result))
  lbl <- attr(result$ADTM, "label")
  expect_true(!is.null(lbl) && nchar(lbl) > 0L)
})

test_that("parse_label_extension LABELV9: informat > 8 chars preserved", {
  tmp <- withr::local_tempfile(fileext = ".xpt")

  df <- data.frame(STARTDT = "2024-01-01", stringsAsFactors = FALSE)
  attr(df$STARTDT, "label") <- "Start Date"
  attr(df$STARTDT, "informat.sas") <- "DATETIME20." # > 8 chars => LABELV9

  suppressMessages(suppressWarnings(
    write_xpt(df, tmp, dataset = "DM", version = 8L)
  ))

  result <- suppressMessages(suppressWarnings(read_xpt(tmp)))
  expect_true("STARTDT" %in% names(result))
})

test_that("parse_label_extension LABELV9: mixed columns (some with long format)", {
  tmp <- withr::local_tempfile(fileext = ".xpt")

  df <- data.frame(
    STUDYID = "S1",
    ADTM = as.character(Sys.time()),
    AGE = 30L,
    stringsAsFactors = FALSE
  )
  # Only ADTM has a long format  --  triggers LABELV9 for all columns with ext
  attr(df$ADTM, "label") <- "Analysis Datetime"
  attr(df$ADTM, "format.sas") <- "E8601DT26.6" # > 8 chars
  attr(df$AGE, "label") <- "Age at Baseline"

  suppressMessages(suppressWarnings(
    write_xpt(df, tmp, dataset = "ADSL", version = 8L)
  ))

  result <- suppressMessages(suppressWarnings(read_xpt(tmp)))
  expect_equal(nrow(result), 1L)
  expect_true("STUDYID" %in% names(result))
  expect_true("ADTM" %in% names(result))
  expect_true("AGE" %in% names(result))
  lbl_age <- attr(result$AGE, "label")
  expect_true(!is.null(lbl_age) && nchar(lbl_age) > 0L)
})

test_that("parse_label_extension LABELV9: fmt_len and infmt_len both > 0", {
  tmp <- withr::local_tempfile(fileext = ".xpt")

  df <- data.frame(DTC = as.character(Sys.time()), stringsAsFactors = FALSE)
  attr(df$DTC, "label") <- "Date/Time of Collection"
  attr(df$DTC, "format.sas") <- "DATETIME26.6" # > 8 chars
  attr(df$DTC, "informat.sas") <- "DATETIME26.6" # > 8 chars

  suppressMessages(suppressWarnings(
    write_xpt(df, tmp, dataset = "LB", version = 8L)
  ))

  result <- suppressMessages(suppressWarnings(read_xpt(tmp)))
  expect_true("DTC" %in% names(result))
  lbl <- attr(result$DTC, "label")
  expect_true(!is.null(lbl) && nchar(lbl) > 0L)
})

# -- From test-xpt-header-v8.R -------------------------------------------------

# -- parse_namestr V8 branch ---------------------------------------------------

test_that("parse_namestr V8 reads extended name from bytes 89-120", {
  long_name <- "LONGVARIABLENAMEHERE"
  raw140 <- make_v8_namestr(
    name = long_name,
    vartype = 2L,
    var_length = 20L,
    varnum = 1L
  )
  result <- herald:::parse_namestr(raw140, version = 8L)
  expect_equal(trimws(result$name), long_name)
})

test_that("parse_namestr V8 reads label_len, fmtname_len, infmtname_len", {
  raw140 <- make_v8_namestr(
    name = "AGE",
    label = "Subject Age",
    vartype = 1L,
    var_length = 8L,
    varnum = 1L
  )
  result <- herald:::parse_namestr(raw140, version = 8L)
  expect_equal(result$label_len, nchar("Subject Age"))
  expect_equal(result$name, "AGE")
})

test_that("parse_namestr V8 returns correct label", {
  raw140 <- make_v8_namestr(
    name = "SEX",
    label = "Sex at Birth",
    vartype = 2L,
    var_length = 1L,
    varnum = 3L
  )
  result <- herald:::parse_namestr(raw140, version = 8L)
  expect_equal(trimws(result$label), "Sex at Birth")
})

test_that("parse_namestr V5 still works correctly", {
  raw140 <- herald:::build_namestr(
    vartype = 1L,
    var_length = 8L,
    varnum = 1L,
    name = "AGE",
    label = "Age in years",
    version = 5L
  )
  result <- herald:::parse_namestr(raw140, version = 5L)
  expect_equal(result$name, "AGE")
  expect_equal(trimws(result$label), "Age in years")
  expect_equal(result$vartype, 1L)
})

# -- parse_namestr_block V8 ---------------------------------------------------

test_that("parse_namestr_block V8 reads multiple variables", {
  df <- data.frame(STUDYID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  block <- herald:::build_namestr_block(df, version = 8L)

  tmp <- withr::local_tempfile()
  writeBin(block, tmp)

  con <- file(tmp, "rb")
  on.exit(close(con), add = TRUE)
  result <- herald:::parse_namestr_block(con, 2L, version = 8L)

  expect_length(result, 2L)
  expect_equal(trimws(result[[1L]]$name), "STUDYID")
  expect_equal(trimws(result[[2L]]$name), "AGE")
})

# -- parse_obs_header: OBSV8 vs regular ---------------------------------------

test_that("parse_obs_header returns NA for V5 OBS header", {
  rec <- rawToChar(herald:::str_to_raw(
    "HEADER RECORD*******OBS     HEADER RECORD!!!!!!!000000000000000000000000000000",
    80L
  ))
  result <- herald:::parse_obs_header(rec, version = 5L)
  expect_true(is.na(result))
})

test_that("parse_obs_header returns integer from OBSV8 header", {
  # Build a realistic OBSV8 record with nobs at position 49-63
  rec_str <- paste0(
    "HEADER RECORD*******OBSV8   HEADER RECORD!!!!!!!", # 48 chars
    "          100  ", # 15 chars (nobs at 49-63)
    strrep(" ", 17L) # pad to 80
  )
  result <- herald:::parse_obs_header(rec_str, version = 8L)
  expect_false(is.na(result))
  expect_equal(result, 100L)
})

test_that("parse_obs_header returns NA for OBSV8 with all zeros nobs", {
  rec_str <- paste0(
    "HEADER RECORD*******OBSV8   HEADER RECORD!!!!!!!", # 48 chars
    "000000000000000", # 15 zeros
    strrep(" ", 17L) # pad to 80
  )
  result <- herald:::parse_obs_header(rec_str, version = 8L)
  expect_true(is.na(result))
})

# -- build_library_header: V8 -------------------------------------------------

test_that("build_library_header V8 produces 240 bytes", {
  result <- herald:::build_library_header(version = 8L)
  expect_equal(length(result), 240L)
})

test_that("build_library_header V8 contains LIBV8 marker", {
  result <- herald:::build_library_header(version = 8L)
  rec1_str <- rawToChar(result[1:80])
  expect_true(grepl("LIBV8", rec1_str, fixed = TRUE))
})

# -- build_member_header: V8 --------------------------------------------------

test_that("build_member_header V8 produces 400 bytes", {
  result <- herald:::build_member_header(
    name = "DM",
    label = "Demographics",
    type = "DATA",
    nvars = 3L,
    version = 8L
  )
  expect_equal(length(result), 400L)
})

test_that("build_member_header V8 contains MEMBV8 marker", {
  result <- herald:::build_member_header(
    name = "DM",
    label = "",
    type = "DATA",
    nvars = 1L,
    version = 8L
  )
  rec1_str <- rawToChar(result[1:80])
  expect_true(grepl("MEMBV8", rec1_str, fixed = TRUE))
})

# -- parse_label_extension: no extension (neither LABELV8 nor LABELV9) --------

test_that("parse_label_extension returns namestrs unchanged for non-label record", {
  namestrs <- list(
    list(name = "X", label = "old label", varnum = 1L)
  )

  # Write a fake OBS record to a temp connection
  rec_str <- rawToChar(herald:::str_to_raw(
    "HEADER RECORD*******OBS     HEADER RECORD!!!!!!!000000000000000000000000000000",
    80L
  ))

  tmp <- withr::local_tempfile()
  writeBin(as.raw(0x00), tmp) # dummy content
  con <- file(tmp, "rb")
  on.exit(close(con), add = TRUE)

  result <- herald:::parse_label_extension(con, rec_str, namestrs)
  expect_identical(result, namestrs)
})

# -- From test-xpt-labelv9.R ---------------------------------------------------

# LABELV9 is triggered when a column has format or informat > 8 chars.
# We write an XPT V8 with a long format string then read it back.

test_that("LABELV9 round-trip: long format name is preserved", {
  # DATETIME26.6 is > 8 chars for the format name
  dm <- data.frame(
    RFSTDTC = as.character(Sys.time()),
    stringsAsFactors = FALSE
  )
  attr(dm$RFSTDTC, "label") <- "Reference Start Date/Time"
  attr(dm$RFSTDTC, "format.sas") <- "DATETIME26.6" # > 8 chars

  tmp <- withr::local_tempfile(fileext = ".xpt")

  write_xpt(dm, tmp, dataset = "DM", version = 8L)
  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0L)

  dm2 <- read_xpt(tmp)
  expect_true("RFSTDTC" %in% names(dm2))
})

test_that("LABELV9 round-trip: multiple columns with long formats", {
  dm <- data.frame(
    RFSTDTC = as.character(Sys.time()),
    RFENDTC = as.character(Sys.time()),
    STUDYID = "S1",
    stringsAsFactors = FALSE
  )
  attr(dm$RFSTDTC, "format.sas") <- "E8601DT26.6" # > 8 chars (E8601DT format)
  attr(dm$RFENDTC, "format.sas") <- "DATETIME26.6"
  attr(dm$RFSTDTC, "label") <- "Reference Start Date/Time"
  attr(dm$RFENDTC, "label") <- "Reference End Date/Time"

  tmp <- withr::local_tempfile(fileext = ".xpt")

  write_xpt(dm, tmp, dataset = "DM", version = 8L)
  dm2 <- read_xpt(tmp)
  expect_equal(nrow(dm2), 1L)
  expect_true("RFSTDTC" %in% names(dm2))
  expect_true("RFENDTC" %in% names(dm2))
})

# -- detect_xpt_version: error on unknown header ------------------------------

test_that("detect_xpt_version errors on unrecognised header", {
  expect_error(
    herald:::detect_xpt_version("HEADER RECORD*******UNKNOWN HEADER RECORD"),
    class = "herald_error_xpt"
  )
})

# -- parse_format_str: various format strings ----------------------------------

test_that("parse_format_str handles format with dot and decimals", {
  result <- herald:::parse_format_str("8.2")
  expect_equal(result$length, 8L)
  expect_equal(result$decimals, 2L)
})

test_that("parse_format_str handles DATE format with dot", {
  result <- herald:::parse_format_str("DATE9.")
  expect_equal(result$name, "DATE")
  expect_equal(result$length, 9L)
  expect_equal(result$decimals, 0L)
})

test_that("parse_format_str handles $ prefix format", {
  result <- herald:::parse_format_str("$CHAR20.")
  expect_equal(result$name, "$CHAR")
  expect_equal(result$length, 20L)
})

test_that("parse_format_str handles format without dot (haven-style)", {
  result <- herald:::parse_format_str("DATETIME16")
  expect_equal(result$name, "DATETIME")
  expect_equal(result$length, 16L)
})

test_that("parse_format_str handles E8601DT format with embedded digits", {
  result <- herald:::parse_format_str("E8601DT26.6")
  # Name should contain the format name part before the width
  expect_true(nzchar(result$name))
  expect_equal(result$length, 26L)
  expect_equal(result$decimals, 6L)
})

test_that("parse_format_str returns empty for NULL input", {
  result <- herald:::parse_format_str(NULL)
  expect_equal(result$name, "")
  expect_equal(result$length, 0L)
})

test_that("parse_format_str returns empty for empty string", {
  result <- herald:::parse_format_str("")
  expect_equal(result$name, "")
  expect_equal(result$length, 0L)
})

# -- build_obs_header: V8 path ------------------------------------------------

test_that("build_obs_header V8 includes nobs count in header", {
  hdr <- herald:::build_obs_header(nobs = 42L, version = 8L)
  expect_equal(length(hdr), 80L)
  hdr_str <- rawToChar(hdr)
  expect_true(grepl("OBSV8", hdr_str, fixed = TRUE))
  expect_true(grepl("42", hdr_str, fixed = TRUE))
})

# -- parse_obs_header: OBSV8 non-zero nobs ------------------------------------

test_that("parse_obs_header returns integer for OBSV8 with non-zero count", {
  # Build a OBSV8 header with count=5
  hdr <- herald:::build_obs_header(nobs = 5L, version = 8L)
  hdr_str <- rawToChar(hdr)
  result <- herald:::parse_obs_header(hdr_str, version = 8L)
  expect_equal(result, 5L)
})

test_that("parse_obs_header returns NA for OBSV8 zero count", {
  hdr <- herald:::build_obs_header(nobs = 0L, version = 8L)
  hdr_str <- rawToChar(hdr)
  result <- herald:::parse_obs_header(hdr_str, version = 8L)
  expect_true(is.na(result))
})

test_that("parse_obs_header returns NA for V5 OBS header", {
  hdr <- herald:::build_obs_header(nobs = 0L, version = 5L)
  hdr_str <- rawToChar(hdr)
  result <- herald:::parse_obs_header(hdr_str, version = 5L)
  expect_true(is.na(result))
})

# -- read_record_str -----------------------------------------------------------

test_that("read_record_str reads exactly 80 bytes as string", {
  # Build a known 80-byte record and write it, then read back
  payload <- herald:::str_to_raw(
    "HEADER RECORD*******OBS     HEADER RECORD!!!!!!!000000000000000000000000000000",
    80L
  )
  tmp <- withr::local_tempfile()
  writeBin(payload, tmp)
  con <- file(tmp, "rb")
  on.exit(close(con), add = TRUE)
  result <- herald:::read_record_str(con)
  expect_type(result, "character")
  expect_equal(nchar(result), 80L)
  expect_true(grepl("OBS", result, fixed = TRUE))
})

# -- parse_member_section: NULL on EOF ----------------------------------------

test_that("parse_member_section returns NULL on EOF", {
  tmp <- withr::local_tempfile()
  writeBin(raw(0L), tmp)
  con <- file(tmp, "rb")
  on.exit(close(con), add = TRUE)
  result <- herald:::parse_member_section(con, version = 5L)
  expect_null(result)
})

test_that("parse_member_section returns NULL when record has no MEMBER marker", {
  # Write an OBS record (no MEMBER/MEMBV8) to trick parse_member_section
  payload <- herald:::str_to_raw(
    "HEADER RECORD*******OBS     HEADER RECORD!!!!!!!000000000000000000000000000000",
    80L
  )
  tmp <- withr::local_tempfile()
  writeBin(payload, tmp)
  con <- file(tmp, "rb")
  on.exit(close(con), add = TRUE)
  result <- herald:::parse_member_section(con, version = 5L)
  expect_null(result)
})

# -- parse_format_str: no dot, no trailing digits -----------------------------

test_that("parse_format_str handles pure-alpha format with no dot and no digits", {
  # e.g. a bare name like "CHAR" -- no dot, no trailing digits
  result <- herald:::parse_format_str("CHAR")
  expect_equal(result$name, "CHAR")
  expect_equal(result$length, 0L)
  expect_equal(result$decimals, 0L)
})

test_that("parse_format_str handles dot-only format (no width, no decimals)", {
  # Formats like "." -- dot at position 1, nothing before or after
  result <- herald:::parse_format_str(".")
  expect_equal(result$length, 0L)
  expect_equal(result$decimals, 0L)
})

# -- build_namestr: V8 extended name area -------------------------------------

test_that("build_namestr V8 includes 32-byte extended name in trailer", {
  long_name <- "LONGVARIABLENAME01"
  result <- herald:::build_namestr(
    vartype = 2L,
    var_length = 20L,
    varnum = 1L,
    name = long_name,
    version = 8L
  )
  # V8 namestr = 88 (fixed) + 32 (ext name) + 2+2+2 (lengths) + 14 (pad) = 140
  expect_equal(length(result), 140L)
  # Extended name occupies bytes 89:120 -- check it contains our name
  ext_name_bytes <- result[89:120]
  ext_name_str <- trimws(rawToChar(ext_name_bytes))
  expect_equal(ext_name_str, long_name)
})

test_that("build_namestr V8 encodes label_len and fmtname_len in trailer", {
  label <- "A label for the variable"
  fmt <- "DATE9."
  result <- herald:::build_namestr(
    vartype = 1L,
    var_length = 8L,
    varnum = 1L,
    name = "AGE",
    label = label,
    format_name = fmt,
    version = 8L
  )
  expect_equal(length(result), 140L)
  label_len <- herald:::s370fpib2_to_int(result[121:122])
  expect_equal(label_len, nchar(label))
  fmtname_len <- herald:::s370fpib2_to_int(result[123:124])
  expect_equal(fmtname_len, nchar(fmt))
})

# -- build_label_extension: V5 returns empty raw ------------------------------

test_that("build_label_extension returns empty raw for V5", {
  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  attr(df$X, "label") <- "Some label"
  result <- herald:::build_label_extension(df, version = 5L)
  expect_equal(length(result), 0L)
})

test_that("build_label_extension returns empty raw when no columns need extension", {
  df <- data.frame(X = 1L, Y = "a", stringsAsFactors = FALSE)
  attr(df$X, "label") <- "Short"
  attr(df$Y, "label") <- "Also short"
  result <- herald:::build_label_extension(df, version = 8L)
  expect_equal(length(result), 0L)
})

test_that("build_label_extension LABELV9 chunk: long fmt and infmt both included", {
  # Trigger LABELV9 by having format > 8 chars
  df <- data.frame(DTC = "2024-01-01", stringsAsFactors = FALSE)
  attr(df$DTC, "label") <- "Datetime field"
  attr(df$DTC, "format.sas") <- "DATETIME26.6"
  attr(df$DTC, "informat.sas") <- "DATETIME26.6"
  result <- herald:::build_label_extension(df, version = 8L)
  # Should be non-empty and padded to 80-byte boundary
  expect_true(length(result) > 0L)
  expect_equal(length(result) %% 80L, 0L)
  hdr_str <- rawToChar(result[1:80])
  expect_true(grepl("LABELV9", hdr_str, fixed = TRUE))
})

test_that("build_label_extension LABELV8: no long format, only long label", {
  df <- data.frame(STUDYID = "S1", stringsAsFactors = FALSE)
  attr(df$STUDYID, "label") <- strrep("X", 45L)  # > 40 chars
  result <- herald:::build_label_extension(df, version = 8L)
  expect_true(length(result) > 0L)
  expect_equal(length(result) %% 80L, 0L)
  hdr_str <- rawToChar(result[1:80])
  expect_true(grepl("LABELV8", hdr_str, fixed = TRUE))
})
