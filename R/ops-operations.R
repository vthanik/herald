# ops-operations.R -- Operations pre-compute registry
#
# Operations run before the Check tree and stamp results as $id columns on the
# evaluation frame. Registered via .register_operation() (not .register_op()).
# Each receives (data, ctx, params) and returns a scalar, vector, or array.
#
# Consolidated from the former ops-operation-*.R files.

# ---- domain_label ------------------------------------------------------------
# Scalar: dataset label attribute string.
# Unlocks: CG0336 (--CAT = domain label), CG0350 (--SCAT = domain label).

.op_operation_domain_label <- function(data, ctx, params) {
  ds_name <- ctx$current_dataset %||% ""
  if (nzchar(ds_name) && !is.null(ctx$datasets)) {
    lbl <- attr(ctx$datasets[[ds_name]], "label")
    if (!is.null(lbl) && nzchar(as.character(lbl))) return(as.character(lbl))
  }
  lbl <- attr(data, "label")
  if (!is.null(lbl) && nzchar(as.character(lbl))) {
    return(as.character(lbl))
  }
  NA_character_
}

.register_operation(
  "domain_label",
  .op_operation_domain_label,
  meta = list(
    kind = "cross",
    summary = "Dataset label attribute as a scalar string.",
    returns = "scalar",
    cost_hint = "O(1)"
  )
)

# ---- distinct ----------------------------------------------------------------
# Array: unique non-NA values of a named column.
# Unlocks: CG0656, CG0225, CG0545, CG0147, CG0148, CG0349, CG0350, CG0336,
#          CG0540, CG0214, CG0531, CG0412, CG0370, CG0109.

.op_operation_distinct <- function(data, ctx, params) {
  col <- as.character(params[["name"]] %||% "")
  if (!nzchar(col)) {
    return(character(0))
  }
  idx <- which(toupper(names(data)) == toupper(col))
  if (length(idx) == 0L) {
    return(character(0))
  }
  vals <- as.character(data[[idx[[1L]]]])
  unique(vals[!is.na(vals) & nzchar(vals)])
}

.register_operation(
  "distinct",
  .op_operation_distinct,
  meta = list(
    kind = "cross",
    summary = "Unique non-NA values of a column from the target dataset.",
    returns = "array",
    cost_hint = "O(n)"
  )
)

# ---- record_count ------------------------------------------------------------
# Scalar: row count of target dataset.
# Unlocks: CG0272, CG0408, CG0281, CG0531, CG0562.

.op_operation_record_count <- function(data, ctx, params) nrow(data)

.register_operation(
  "record_count",
  .op_operation_record_count,
  meta = list(
    kind = "cross",
    summary = "Number of rows in the target dataset.",
    returns = "scalar",
    cost_hint = "O(1)"
  )
)

# ---- study_domains / dataset_names -------------------------------------------
# Array: uppercase names of all datasets in the current validate() call.
# Unlocks: CG0369, CG0332, CG0333.

.op_operation_study_domains <- function(data, ctx, params) {
  if (!is.null(ctx$datasets)) toupper(names(ctx$datasets)) else character(0)
}

.register_operation(
  "study_domains",
  .op_operation_study_domains,
  meta = list(
    kind = "cross",
    summary = "Uppercase dataset names in the current validate() call.",
    returns = "array",
    cost_hint = "O(1)"
  )
)
.register_operation(
  "dataset_names",
  .op_operation_study_domains,
  meta = list(
    kind = "cross",
    summary = "Alias for study_domains: uppercase dataset names.",
    returns = "array",
    cost_hint = "O(1)"
  )
)

# ---- max_date / min_date -----------------------------------------------------
# Scalar: lexicographic max/min of ISO-8601 date strings in a named column.
# Unlocks: CG0147, CG0148, CG0172, CG0143.

.op_operation_max_date <- function(data, ctx, params) {
  col <- as.character(params[["name"]] %||% "")
  if (!nzchar(col)) {
    return(NA_character_)
  }
  idx <- which(toupper(names(data)) == toupper(col))
  if (length(idx) == 0L) {
    return(NA_character_)
  }
  vals <- as.character(data[[idx[[1L]]]])
  vals <- vals[!is.na(vals) & nzchar(vals)]
  if (length(vals) == 0L) {
    return(NA_character_)
  }
  max(vals)
}

.op_operation_min_date <- function(data, ctx, params) {
  col <- as.character(params[["name"]] %||% "")
  if (!nzchar(col)) {
    return(NA_character_)
  }
  idx <- which(toupper(names(data)) == toupper(col))
  if (length(idx) == 0L) {
    return(NA_character_)
  }
  vals <- as.character(data[[idx[[1L]]]])
  vals <- vals[!is.na(vals) & nzchar(vals)]
  if (length(vals) == 0L) {
    return(NA_character_)
  }
  min(vals)
}

.register_operation(
  "max_date",
  .op_operation_max_date,
  meta = list(
    kind = "temporal",
    summary = "Lexicographic max of ISO-8601 date strings in a column.",
    returns = "scalar",
    cost_hint = "O(n)"
  )
)
.register_operation(
  "min_date",
  .op_operation_min_date,
  meta = list(
    kind = "temporal",
    summary = "Lexicographic min of ISO-8601 date strings in a column.",
    returns = "scalar",
    cost_hint = "O(n)"
  )
)

# ---- study_day_from_dates (dy) -----------------------------------------------
# Vector: per-row CDISC study day relative to DM.RFSTDTC.
# Unlocks: CG0006.

.op_operation_study_day <- function(data, ctx, params) {
  col <- as.character(params[["name"]] %||% "")
  if (!nzchar(col)) {
    return(rep(NA_integer_, nrow(data)))
  }
  idx <- which(toupper(names(data)) == toupper(col))
  if (length(idx) == 0L) {
    return(rep(NA_integer_, nrow(data)))
  }

  dm <- ctx$datasets[["DM"]] %||% ctx$datasets[["dm"]]
  if (is.null(dm)) {
    return(rep(NA_integer_, nrow(data)))
  }
  rfstdtc_col <- which(toupper(names(dm)) == "RFSTDTC")
  usubjid_dm <- which(toupper(names(dm)) == "USUBJID")
  if (length(rfstdtc_col) == 0L || length(usubjid_dm) == 0L) {
    return(rep(NA_integer_, nrow(data)))
  }

  rf_map <- stats::setNames(
    as.character(dm[[rfstdtc_col[[1L]]]]),
    as.character(dm[[usubjid_dm[[1L]]]])
  )

  usubjid_data <- which(toupper(names(data)) == "USUBJID")
  subj <- if (length(usubjid_data) > 0L) {
    as.character(data[[usubjid_data[[1L]]]])
  } else {
    rep(NA_character_, nrow(data))
  }

  .sdtm_study_day <- function(dt_str, ref_str) {
    if (
      is.na(dt_str) || is.na(ref_str) || !nzchar(dt_str) || !nzchar(ref_str)
    ) {
      return(NA_integer_)
    }
    dt <- tryCatch(as.Date(substr(dt_str, 1L, 10L)), error = function(e) NA)
    ref <- tryCatch(as.Date(substr(ref_str, 1L, 10L)), error = function(e) NA)
    if (is.na(dt) || is.na(ref)) {
      return(NA_integer_)
    }
    diff <- as.integer(dt - ref)
    if (diff >= 0L) diff + 1L else diff
  }

  mapply(
    function(dt, subj_id) {
      rf <- rf_map[[subj_id]]
      .sdtm_study_day(dt, rf)
    },
    as.character(data[[idx[[1L]]]]),
    subj,
    USE.NAMES = FALSE
  )
}

.register_operation(
  "dy",
  .op_operation_study_day,
  meta = list(
    kind = "temporal",
    summary = "Per-row CDISC study day (--DY formula) relative to DM.RFSTDTC.",
    returns = "vector",
    cost_hint = "O(n)"
  )
)

# ---- column-order family -----------------------------------------------------
# Array: variable lists for column-ordering and variable-presence rules.
# Unlocks: CG0016, CG0014, CG0219, CG0330, CG0662, CG0664, CG0013, CG0351,
#          CG0314.

.op_operation_col_order_dataset <- function(data, ctx, params) names(data)
.op_operation_expected_variables <- function(data, ctx, params) names(data)
.op_operation_dataset_filtered_variables <- function(data, ctx, params) {
  names(data)
}

.op_operation_required_variables <- function(data, ctx, params) {
  spec <- ctx$spec
  if (is.null(spec)) {
    return(character(0))
  }
  ds <- ctx$current_dataset %||% ""
  .spec_cols(spec, ds, c("required", "Required"))
}

# Model/library ops: return empty pending CDISC SDTM model integration.
.op_operation_model_col_order <- function(data, ctx, params) character(0)
.op_operation_parent_model_col_order <- function(data, ctx, params) character(0)
.op_operation_library_col_order <- function(data, ctx, params) character(0)
.op_operation_model_filtered_variables <- function(data, ctx, params) {
  character(0)
}

.register_operation(
  "get_column_order_from_dataset",
  .op_operation_col_order_dataset,
  meta = list(
    kind = "cross",
    summary = "Variable names in current dataset.",
    returns = "array",
    cost_hint = "O(1)"
  )
)
.register_operation(
  "expected_variables",
  .op_operation_expected_variables,
  meta = list(
    kind = "cross",
    summary = "Variable names present in dataset.",
    returns = "array",
    cost_hint = "O(1)"
  )
)
.register_operation(
  "required_variables",
  .op_operation_required_variables,
  meta = list(
    kind = "cross",
    summary = "Required variables from spec.",
    returns = "array",
    cost_hint = "O(1)"
  )
)
.register_operation(
  "get_dataset_filtered_variables",
  .op_operation_dataset_filtered_variables,
  meta = list(
    kind = "cross",
    summary = "Filtered variable names in dataset.",
    returns = "array",
    cost_hint = "O(1)"
  )
)
.register_operation(
  "get_model_column_order",
  .op_operation_model_col_order,
  meta = list(
    kind = "cross",
    summary = "SDTM model variable order (pending library integration).",
    returns = "array",
    cost_hint = "O(1)"
  )
)
.register_operation(
  "get_parent_model_column_order",
  .op_operation_parent_model_col_order,
  meta = list(
    kind = "cross",
    summary = "Parent SDTM model variable order (pending library integration).",
    returns = "array",
    cost_hint = "O(1)"
  )
)
.register_operation(
  "get_column_order_from_library",
  .op_operation_library_col_order,
  meta = list(
    kind = "cross",
    summary = "CDISC library variable order (pending library integration).",
    returns = "array",
    cost_hint = "O(1)"
  )
)
.register_operation(
  "get_model_filtered_variables",
  .op_operation_model_filtered_variables,
  meta = list(
    kind = "cross",
    summary = "Model-filtered variable list (pending library integration).",
    returns = "array",
    cost_hint = "O(1)"
  )
)

# ---- get_codelist_attributes / extract_metadata ------------------------------
# Array: codelist submission values from CT provider; variable name list.
# Unlocks: CG0288, CG0334.

.op_operation_get_codelist_attributes <- function(data, ctx, params) {
  cl_name <- as.character(params[["name"]] %||% "")
  if (!nzchar(cl_name)) {
    return(character(0))
  }
  tryCatch(
    {
      provider <- ctx$ct[[cl_name]] %||% NULL
      if (is.null(provider) && !is.null(ctx$dictionaries)) {
        provider <- ctx$dictionaries[["ct"]]
      }
      if (is.null(provider)) {
        return(character(0))
      }
      terms <- ct_info(provider, cl_name)
      if (is.null(terms)) {
        return(character(0))
      }
      as.character(terms)
    },
    error = function(e) character(0)
  )
}

.op_operation_extract_metadata <- function(data, ctx, params) names(data)

.register_operation(
  "get_codelist_attributes",
  .op_operation_get_codelist_attributes,
  meta = list(
    kind = "cross",
    summary = "Codelist submission values from the session CT provider.",
    returns = "array",
    cost_hint = "O(1)"
  )
)
.register_operation(
  "extract_metadata",
  .op_operation_extract_metadata,
  meta = list(
    kind = "cross",
    summary = "Dataset variable names (used for metadata-context checks).",
    returns = "array",
    cost_hint = "O(1)"
  )
)

# ---- domain_is_custom --------------------------------------------------------
# Scalar: TRUE when current dataset is a custom (non-standard) SDTM domain.
# Unlocks: CG0349.

.SDTM_STANDARD_DOMAINS <- c(
  "AE",
  "AG",
  "AP",
  "APTE",
  "CE",
  "CM",
  "CO",
  "CV",
  "DA",
  "DD",
  "DM",
  "DO",
  "DS",
  "DV",
  "EC",
  "EG",
  "EX",
  "FA",
  "FT",
  "GF",
  "HO",
  "IE",
  "IS",
  "LB",
  "MB",
  "MH",
  "MI",
  "MK",
  "ML",
  "MO",
  "MS",
  "NV",
  "OE",
  "PC",
  "PE",
  "PF",
  "PG",
  "PK",
  "PP",
  "PR",
  "QS",
  "RE",
  "RP",
  "RS",
  "SC",
  "SE",
  "SK",
  "SL",
  "SM",
  "SR",
  "SS",
  "SU",
  "SV",
  "TA",
  "TD",
  "TE",
  "TI",
  "TM",
  "TP",
  "TS",
  "TV",
  "TX",
  "UR",
  "VS",
  "XB",
  "RELREC",
  "RELSUB",
  "SUPPQUAL",
  "DX",
  "OI",
  "OT"
)

.op_operation_domain_is_custom <- function(data, ctx, params) {
  ds <- toupper(ctx$current_dataset %||% "")
  prefix <- substr(ds, 1L, 2L)
  nzchar(prefix) && !prefix %in% .SDTM_STANDARD_DOMAINS
}

.register_operation(
  "domain_is_custom",
  .op_operation_domain_is_custom,
  meta = list(
    kind = "cross",
    summary = "TRUE when current dataset is a custom (non-standard) SDTM domain.",
    returns = "scalar",
    cost_hint = "O(1)"
  )
)
