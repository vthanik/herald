# --------------------------------------------------------------------------
# xpt-encoding.R — SAS encoding map and format classification
# --------------------------------------------------------------------------
# Consolidates encoding resolution from helpers.R and all SAS format
# classification from sas-formats.R into one cohesive module.

# -- SAS encoding name -> iconv name lookup (lowercase keys) ----------------

.sas_encoding_map <- c(
  # Western European
  "wlatin1" = "WINDOWS-1252",
  "wlt1" = "WINDOWS-1252",
  "latin1" = "ISO-8859-1",
  "lat1" = "ISO-8859-1",
  "latin9" = "ISO-8859-15",
  "lat9" = "ISO-8859-15",
  # Central European
  "wlatin2" = "WINDOWS-1250",
  "wlt2" = "WINDOWS-1250",
  "latin2" = "ISO-8859-2",
  "lat2" = "ISO-8859-2",
  # Cyrillic / Greek / Turkish / Arabic / Baltic / Vietnamese
  "wcyrillic" = "WINDOWS-1251",
  "wcyr" = "WINDOWS-1251",
  "wgreek" = "WINDOWS-1253",
  "wgrk" = "WINDOWS-1253",
  "wturkish" = "WINDOWS-1254",
  "wtur" = "WINDOWS-1254",
  "warabic" = "WINDOWS-1256",
  "wara" = "WINDOWS-1256",
  "wbaltic" = "WINDOWS-1257",
  "wbal" = "WINDOWS-1257",
  "wvietnamese" = "WINDOWS-1258",
  "wvie" = "WINDOWS-1258",
  # Unicode / ASCII
  "utf-8" = "UTF-8",
  "utf8" = "UTF-8",
  "us-ascii" = "US-ASCII",
  "ascii" = "US-ASCII",
  "ansi" = "US-ASCII",
  # Japanese
  "shift-jis" = "CP932",
  "sjis" = "CP932",
  "euc-jp" = "EUC-JP",
  "jeuc" = "EUC-JP",
  # Direct iconv names (pass through)
  "windows-1252" = "WINDOWS-1252",
  "windows-1250" = "WINDOWS-1250",
  "windows-1251" = "WINDOWS-1251",
  "iso-8859-1" = "ISO-8859-1",
  "iso-8859-2" = "ISO-8859-2",
  "iso-8859-15" = "ISO-8859-15",
  "cp1252" = "WINDOWS-1252",
  "cp932" = "CP932"
)

#' Resolve a SAS or IANA encoding name to an iconv-compatible name
#' @noRd
resolve_encoding <- function(encoding) {
  if (is.null(encoding)) {
    return(NULL)
  }
  key <- tolower(trimws(encoding))
  resolved <- .sas_encoding_map[key]
  if (is.na(resolved)) {
    return(encoding)
  }
  unname(resolved)
}

# -- SAS format classification -----------------------------------------------

# Private env for SAS epoch constants
.sas_env <- new.env(parent = emptyenv())
.sas_env$epoch_date <- as.Date("1960-01-01")
.sas_env$epoch_posixct <- as.POSIXct("1960-01-01 00:00:00", tz = "UTC")

# Date formats (days since 1960-01-01) — uppercase for case-insensitive match
.sas_date_formats <- c(
  "DATE",
  # Day-Month-Year
  "DDMMYY",
  "DDMMYYB",
  "DDMMYYC",
  "DDMMYYD",
  "DDMMYYN",
  "DDMMYYP",
  "DDMMYYS",
  # Month-Day-Year
  "MMDDYY",
  "MMDDYYB",
  "MMDDYYC",
  "MMDDYYD",
  "MMDDYYN",
  "MMDDYYP",
  "MMDDYYS",
  # Year-Month-Day
  "YYMMDD",
  "YYMMDDB",
  "YYMMDDC",
  "YYMMDDD",
  "YYMMDDN",
  "YYMMDDP",
  "YYMMDDS",
  # Year-Month
  "YYMM",
  "YYMMC",
  "YYMMD",
  "YYMMN",
  "YYMMP",
  "YYMMS",
  # Year-Quarter
  "YYQ",
  "YYQC",
  "YYQD",
  "YYQN",
  "YYQP",
  "YYQS",
  "YYQR",
  "YYQRC",
  "YYQRD",
  "YYQRN",
  "YYQRP",
  "YYQRS",
  # Month-Year
  "MMYY",
  "MMYYC",
  "MMYYD",
  "MMYYN",
  "MMYYP",
  "MMYYS",
  # Calendar component
  "MONYY",
  "MONNAME",
  "MONTH",
  "QTR",
  "QTRR",
  "YEAR",
  "WEEKDAY",
  # Word/week date
  "WEEKDATE",
  "WEEKDATX",
  "WORDDATE",
  "WORDDATX",
  # Julian
  "JULIAN",
  "JULDAY",
  # Asian calendar
  "NENGO",
  "MINGUO",
  # Hebrew
  "HDATE",
  "HEBDATE",
  # European
  "EURDFDD",
  "EURDFDE",
  "EURDFDN",
  "EURDFDT",
  "EURDFDWN",
  "EURDFMN",
  "EURDFMY",
  "EURDFWDX",
  "EURDFWKX",
  # National language
  "NLDATE",
  "NLDATEL",
  "NLDATEM",
  "NLDATEMD",
  "NLDATEMN",
  "NLDATES",
  "NLDATEW",
  "NLDATEWN",
  "NLDATEYM",
  "NLDATEYMW",
  "NLDDFDD",
  "NLDDFDE",
  "NLDDFDN",
  "NLDDFDT",
  "NLDDFDWN",
  "NLDDFMN",
  "NLDDFMY",
  "NLDDFWDX",
  "NLDDFWKX",
  # Packed Julian
  "PDJULG",
  "PDJULI",
  # ISO 8601
  "B8601DA",
  "E8601DA",
  # Datetime-extracted date display
  "DTDATE",
  "DTYEAR",
  "DTMONYY",
  "DTWKDATX",
  "DTYYQC"
)

# Datetime formats (seconds since 1960-01-01 00:00:00)
.sas_datetime_formats <- c(
  "DATETIME",
  "DATEAMPM",
  "MDYAMPM",
  # ISO 8601
  "B8601DN",
  "B8601DT",
  "B8601DZ",
  "B8601LZ",
  "E8601DN",
  "E8601DT",
  "E8601DZ",
  "E8601LZ",
  # National language
  "NLDATM",
  "NLDATMAP",
  "NLDATMDT",
  "NLDATMMD",
  "NLDATMMN",
  "NLDATMS",
  "NLDATMTM",
  "NLDATMW",
  "NLDATMWN",
  "NLDATMWZ",
  "NLDATMYM",
  "NLDATMYW",
  "NLDATMZ",
  # Time extraction
  "DTTIME"
)

# Time formats (seconds since midnight)
.sas_time_formats <- c(
  "TIME",
  "TIMEAMPM",
  "HHMM",
  "HOUR",
  "MMSS",
  "TOD",
  # ISO 8601
  "B8601TM",
  "B8601TZ",
  "B8601LZ",
  "E8601TM",
  "E8601TZ",
  "E8601LZ",
  # National language
  "NLTIME",
  "NLTIMMAP",
  "NLTIMAP"
)

#' Check if a SAS format name indicates a date variable
#' @noRd
is_sas_date_format <- function(fmt_name) {
  toupper(fmt_name) %in% .sas_date_formats
}

#' Check if a SAS format name indicates a datetime variable
#' @noRd
is_sas_datetime_format <- function(fmt_name) {
  toupper(fmt_name) %in% .sas_datetime_formats
}

#' Check if a SAS format name indicates a time variable
#' @noRd
is_sas_time_format <- function(fmt_name) {
  toupper(fmt_name) %in% .sas_time_formats
}

#' Extract the alphabetic format name from a full SAS format string
#' "DATE9." -> "DATE", "E8601DT26.6" -> "E8601DT", "" -> ""
#' @noRd
extract_format_name <- function(fmt_str) {
  if (!nzchar(fmt_str)) {
    return("")
  }
  parse_format_str(fmt_str)$name
}

# -- SAS date/time conversion ------------------------------------------------

#' Convert SAS date values (days since 1960-01-01) to R Date
#' @noRd
sas_date_to_r <- function(x) {
  as.Date(x, origin = "1960-01-01")
}

#' Convert SAS datetime values (seconds since 1960-01-01 00:00:00) to R POSIXct
#' @noRd
sas_datetime_to_r <- function(x) {
  as.POSIXct(x, origin = "1960-01-01", tz = "UTC")
}

#' Convert SAS time values (seconds since midnight) to R difftime
#' @noRd
sas_time_to_r <- function(x) {
  as.difftime(x, units = "secs")
}

#' Convert a column in-place, preserving label/format.sas/informat.sas attrs
#' @noRd
convert_preserving_attrs <- function(df, nm, convert_fn) {
  saved_label <- attr(df[[nm]], "label")
  saved_fmt <- attr(df[[nm]], "format.sas")
  saved_infmt <- attr(df[[nm]], "informat.sas")
  df[[nm]] <- convert_fn(df[[nm]])
  if (!is.null(saved_label)) {
    attr(df[[nm]], "label") <- saved_label
  }
  if (!is.null(saved_fmt)) {
    attr(df[[nm]], "format.sas") <- saved_fmt
  }
  if (!is.null(saved_infmt)) {
    attr(df[[nm]], "informat.sas") <- saved_infmt
  }
  df
}
