# ops-define-hrl.R -- Define-XML HRL-DD custom operators
#
# These ops work against the flat frames produced by the Define-XML builder
# layer (R/dataset-builders.R). Each follows the standard ops contract:
# TRUE = fires (violation), FALSE = pass, NA = advisory.

# ---- iso8601_data_type_match --------------------------------------------------
# --DTC / --DUR variables must declare an ISO 8601 DataType, not "text".

#' @noRd
op_iso8601_data_type_match <- function(data, ctx, ...) {
  var   <- data$variable
  dtype <- data$data_type
  # Variables whose names end with DTC or DUR represent ISO 8601 values.
  is_iso_var <- grepl("(DTC|DUR)$", var, perl = TRUE)
  # Fires when the variable is an ISO 8601 type but DataType is "text".
  is_iso_var & !is.na(dtype) & dtype == "text"
}
.register_op("iso8601_data_type_match", op_iso8601_data_type_match, meta = list(
  kind          = "compare",
  summary       = "--DTC/--DUR variables must not have DataType 'text'",
  arg_schema    = list(),
  cost_hint     = "O(n)",
  column_arg    = "variable",
  returns_na_ok = FALSE
))

# ---- define_version_matches_schema -------------------------------------------
# def:DefineVersion must be "2.0.0" or "2.1.0".

#' @noRd
op_define_version_matches_schema <- function(data, ctx, ...) {
  valid <- c("2.0.0", "2.1.0")
  v <- data$def_version
  !is.na(v) & !v %in% valid
}
.register_op("define_version_matches_schema", op_define_version_matches_schema,
  meta = list(
    kind          = "compare",
    summary       = "def:DefineVersion must be 2.0.0 or 2.1.0",
    arg_schema    = list(),
    cost_hint     = "O(n)",
    column_arg    = "def_version",
    returns_na_ok = FALSE
  )
)

# ---- assigned_value_matches_data_type ----------------------------------------
# If def:Origin/@def:AssignedValue is present, its apparent type must match
# the variable's declared DataType.

#' @noRd
op_assigned_value_matches_data_type <- function(data, ctx, ...) {
  assigned <- data$assigned_value
  dtype    <- data$data_type
  numeric_types  <- c("integer", "float", "decimal", "double")
  datetime_types <- c("datetime", "date", "time", "partialDate", "partialTime",
                      "partialDatetime", "incompleteDatetime",
                      "durationDatetime", "intervalDatetime")

  vapply(seq_len(nrow(data)), function(i) {
    av <- assigned[i]
    dt <- dtype[i]
    if (!nzchar(av)) return(FALSE)
    if (dt %in% numeric_types) {
      return(is.na(suppressWarnings(as.numeric(av))))
    }
    if (dt %in% datetime_types) {
      # ISO 8601 starts with a digit (date) or 'P' (duration)
      return(!grepl("^[0-9]|^P", av))
    }
    FALSE
  }, logical(1L))
}
.register_op("assigned_value_matches_data_type",
  op_assigned_value_matches_data_type, meta = list(
    kind          = "compare",
    summary       = "Assigned value type must match variable DataType",
    arg_schema    = list(),
    cost_hint     = "O(n)",
    column_arg    = "assigned_value",
    returns_na_ok = FALSE
  )
)

# ---- assigned_value_length_le_var_length -------------------------------------
# nchar(AssignedValue) must not exceed the variable's declared Length.

#' @noRd
op_assigned_value_length_le_var_length <- function(data, ctx, ...) {
  assigned   <- data$assigned_value
  length_col <- data$length

  vapply(seq_len(nrow(data)), function(i) {
    av <- assigned[i]
    if (!nzchar(av)) return(FALSE)
    max_len <- suppressWarnings(as.integer(length_col[i]))
    if (is.na(max_len)) return(FALSE)
    nchar(av, type = "bytes") > max_len
  }, logical(1L))
}
.register_op("assigned_value_length_le_var_length",
  op_assigned_value_length_le_var_length, meta = list(
    kind          = "compare",
    summary       = "Assigned value length must not exceed variable Length",
    arg_schema    = list(),
    cost_hint     = "O(n)",
    column_arg    = "assigned_value",
    returns_na_ok = FALSE
  )
)

# ---- valid_codelist_term -----------------------------------------------------
# When a variable has an assigned value and a linked codelist, the assigned
# value must be a term in that codelist.

#' @noRd
op_valid_codelist_term <- function(data, ctx, ...) {
  cl_meta <- .ref_ds(ctx, "Define_Codelist_Metadata")
  if (is.null(cl_meta)) return(rep(NA_integer_, nrow(data)) == 1L)

  has_assigned <- nzchar(data$assigned_value)
  has_codelist <- nzchar(data$codelist_oid)

  vapply(seq_len(nrow(data)), function(i) {
    if (!has_assigned[i] || !has_codelist[i]) return(FALSE)
    cl_items <- cl_meta$coded_value[cl_meta$codelist_oid == data$codelist_oid[i]]
    !data$assigned_value[i] %in% cl_items
  }, logical(1L))
}
.register_op("valid_codelist_term", op_valid_codelist_term, meta = list(
  kind          = "cross",
  summary       = "Assigned value must be a valid codelist term",
  arg_schema    = list(),
  cost_hint     = "O(n*m)",
  column_arg    = "assigned_value",
  returns_na_ok = TRUE
))

# ---- where_clause_value_in_codelist ------------------------------------------
# A WhereClauseDef RangeCheck value must be a term in the variable's codelist.

#' @noRd
op_where_clause_value_in_codelist <- function(data, ctx, ...) {
  var_meta <- .ref_ds(ctx, "Define_Variable_Metadata")
  cl_meta  <- .ref_ds(ctx, "Define_Codelist_Metadata")
  if (is.null(var_meta) || is.null(cl_meta)) {
    return(rep(NA_integer_, nrow(data)) == 1L)
  }

  vapply(seq_len(nrow(data)), function(i) {
    cv    <- data$check_value[i]
    c_var <- data$check_var[i]
    if (!nzchar(cv) || !nzchar(c_var)) return(FALSE)
    var_row <- var_meta[var_meta$oid == c_var, , drop = FALSE]
    if (nrow(var_row) == 0L) return(NA)
    cl_oid <- var_row$codelist_oid[1L]
    if (!nzchar(cl_oid)) return(NA)
    cl_items <- cl_meta$coded_value[cl_meta$codelist_oid == cl_oid]
    !cv %in% cl_items
  }, logical(1L))
}
.register_op("where_clause_value_in_codelist",
  op_where_clause_value_in_codelist, meta = list(
    kind          = "cross",
    summary       = "Where clause check value must be in the variable's codelist",
    arg_schema    = list(),
    cost_hint     = "O(n*m)",
    column_arg    = "check_value",
    returns_na_ok = TRUE
  )
)

# ---- arm_absent_in_non_adam_define -------------------------------------------
# arm:AnalysisResultDisplays must not be present in SDTM/SEND defines.
# Fires for every ARM row when the study is not ADaM-based.

#' @noRd
op_arm_absent_in_non_adam_define <- function(data, ctx, ...) {
  study_meta <- .ref_ds(ctx, "Define_Study_Metadata")
  if (is.null(study_meta) || nrow(study_meta) == 0L) {
    return(rep(FALSE, nrow(data)))
  }
  is_adam <- isTRUE(study_meta$is_adam[1L])
  rep(!is_adam, nrow(data))
}
.register_op("arm_absent_in_non_adam_define",
  op_arm_absent_in_non_adam_define, meta = list(
    kind          = "cross",
    summary       = "ARM metadata must not appear in non-ADaM defines",
    arg_schema    = list(),
    cost_hint     = "O(n)",
    column_arg    = "display_oid",
    returns_na_ok = FALSE
  )
)

# ---- arm_oid_unique ----------------------------------------------------------
# arm:ResultDisplay OID must be unique within arm:AnalysisResultDisplays.

#' @noRd
op_arm_oid_unique <- function(data, ctx, ...) {
  oids <- data$display_oid
  duplicated(oids) | duplicated(oids, fromLast = TRUE)
}
.register_op("arm_oid_unique", op_arm_oid_unique, meta = list(
  kind          = "compare",
  summary       = "arm:ResultDisplay OID must be unique",
  arg_schema    = list(),
  cost_hint     = "O(n)",
  column_arg    = "display_oid",
  returns_na_ok = FALSE
))

# ---- arm_name_unique ---------------------------------------------------------
# arm:ResultDisplay Name must be unique across all displays.

#' @noRd
op_arm_name_unique <- function(data, ctx, ...) {
  nms <- data$display_name
  duplicated(nms) | duplicated(nms, fromLast = TRUE)
}
.register_op("arm_name_unique", op_arm_name_unique, meta = list(
  kind          = "compare",
  summary       = "arm:ResultDisplay Name must be unique",
  arg_schema    = list(),
  cost_hint     = "O(n)",
  column_arg    = "display_name",
  returns_na_ok = FALSE
))

# ---- arm_description_required ------------------------------------------------
# Each arm:ResultDisplay must have a Description child.

#' @noRd
op_arm_description_required <- function(data, ctx, ...) {
  !data$has_description
}
.register_op("arm_description_required", op_arm_description_required, meta = list(
  kind          = "existence",
  summary       = "arm:ResultDisplay must have a Description",
  arg_schema    = list(),
  cost_hint     = "O(n)",
  column_arg    = "has_description",
  returns_na_ok = FALSE
))

# ---- arm_analysisresult_oid_unique -------------------------------------------
# arm:AnalysisResult OID must be unique within its parent arm:ResultDisplay.

#' @noRd
op_arm_analysisresult_oid_unique <- function(data, ctx, ...) {
  key <- paste(data$display_oid, data$result_oid, sep = "|")
  duplicated(key) | duplicated(key, fromLast = TRUE)
}
.register_op("arm_analysisresult_oid_unique",
  op_arm_analysisresult_oid_unique, meta = list(
    kind          = "compare",
    summary       = "arm:AnalysisResult OID must be unique within its ResultDisplay",
    arg_schema    = list(),
    cost_hint     = "O(n)",
    column_arg    = "result_oid",
    returns_na_ok = FALSE
  )
)

# ---- key_not_unique_per_define (was ops-define.R) --------------------------------
# --------------------------------------------------------------------------
# --------------------------------------------------------------------------
# ctx$define is a herald_define object populated when validate() is called
# with a define = read_define_xml("define.xml") argument.
# All ops here return NA (advisory) when ctx$define is absent so they
# degrade gracefully on submissions without a define.xml path.

# --------------------------------------------------------------------------
# op_key_not_unique_per_define
# --------------------------------------------------------------------------
# CG0019: each record is unique per sponsor-defined key variables as
# documented in the define.xml (ItemGroupDef[@def:KeyVariables]).
#
# Resolution order:
#   1. ctx$define$key_vars[[ds_name]] -- from parsed define.xml
#   2. NA advisory if define or key_vars absent (logged to missing_refs)
#
# When key_vars are found but some are absent from data, those columns
# are silently dropped (the remaining subset is still checked). If no
# valid key columns remain, NA advisory is returned.

#' @noRd
op_key_not_unique_per_define <- function(data, ctx) {
  n <- nrow(data)
  if (n == 0L) return(logical(0L))

  # Obtain define metadata
  def <- if (!is.null(ctx)) ctx$define else NULL
  if (is.null(def)) {
    .record_missing_ref(ctx,
      rule_id = ctx$current_rule_id %||% "",
      kind    = "define",
      name    = "define.xml")
    return(rep(NA_integer_, n) != 0L)  # NA logical
  }

  ds_name <- toupper(ctx$current_dataset %||% "")
  key_vars <- def$key_vars[[ds_name]]

  if (is.null(key_vars) || length(key_vars) == 0L) {
    # No key variables documented for this dataset -- skip (advisory)
    return(rep(NA_integer_, n) != 0L)
  }

  # Filter to columns present in data
  available <- intersect(key_vars, names(data))
  if (length(available) == 0L) {
    # All key columns are absent from data -- advisory
    return(rep(NA_integer_, n) != 0L)
  }

  # Check uniqueness of the composite key
  key <- do.call(paste, c(data[, available, drop = FALSE], list(sep = "\x1f")))
  counts    <- table(key)
  rep_count <- as.integer(counts[key])
  # fires (TRUE) when duplicated
  rep_count > 1L
}
.register_op(
  "key_not_unique_per_define", op_key_not_unique_per_define,
  meta = list(
    kind          = "cross",
    summary       = "Record not unique per sponsor-defined key variables from define.xml",
    arg_schema    = list(),
    cost_hint     = "O(n)",
    column_arg    = NA_character_,
    returns_na_ok = TRUE
  )
)
