# ops-operation-codelist.R -- get_codelist_attributes + extract_metadata
#
# get_codelist_attributes: looks up codelist submission values from the
# session CT provider, keyed by the TSVALCD-context codelist name.
# Unlocks: CG0288 (TSVALCD must be a valid CDISC CT code when TSVCDREF=CDISC).
#
# extract_metadata: returns dataset variable names as a vector (used by CG0334
# RDOMAIN vs SUPP-- name check). Named after the CDISC operation; herald maps
# it to the dataset's column names because the actual metadata comparison is
# done in the Check tree.

.op_operation_get_codelist_attributes <- function(data, ctx, params) {
  cl_name <- as.character(params[["name"]] %||% "")
  if (!nzchar(cl_name)) return(character(0))
  # Try CT provider; fall back gracefully.
  tryCatch({
    provider <- ctx$ct[[cl_name]] %||% NULL
    if (is.null(provider) && !is.null(ctx$dictionaries)) {
      provider <- ctx$dictionaries[["ct"]]
    }
    if (is.null(provider)) return(character(0))
    terms <- ct_info(provider, cl_name)
    if (is.null(terms)) return(character(0))
    as.character(terms)
  }, error = function(e) character(0))
}

.op_operation_extract_metadata <- function(data, ctx, params) {
  names(data)
}

.register_operation(
  "get_codelist_attributes",
  .op_operation_get_codelist_attributes,
  meta = list(
    kind      = "cross",
    summary   = "Codelist submission values from the session CT provider.",
    returns   = "array",
    cost_hint = "O(1)"
  )
)

.register_operation(
  "extract_metadata",
  .op_operation_extract_metadata,
  meta = list(
    kind      = "cross",
    summary   = "Dataset variable names (used for metadata-context checks).",
    returns   = "array",
    cost_hint = "O(1)"
  )
)
