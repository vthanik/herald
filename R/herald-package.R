#' herald: CDISC Conformance Validation for Clinical Trial Submissions
#'
#' Pure-R conformance validation for CDISC clinical data submissions.
#' Reads SDTM and ADaM datasets from XPT, Dataset-JSON, and Parquet files,
#' then checks them against published CDISC Library conformance rules,
#' controlled terminology, and Define-XML 2.1 specifications. Produces
#' findings reports (HTML, XLSX, JSON) with rule-level provenance linked to
#' CDISC source. Includes a Define-XML 2.1 authoring object supporting full
#' read-edit-write roundtrip with semantic preservation. Integrates with
#' reproducible pipeline tooling ('renv', 'targets') and CI workflows.
#' Pure-R and 'CRAN'-installable -- no Java runtime required.
#'
#' @keywords internal
#' @importFrom rlang caller_arg caller_env `%||%`
"_PACKAGE"
