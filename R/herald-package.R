#' herald: CDISC Conformance Validation for Clinical Trial Submissions
#'
#' @description
#' herald is a pure-R conformance validator for CDISC clinical trial
#' submissions. It is built for sponsor statistical programmers, data
#' standards leads, and regulatory submission teams preparing data
#' packages for the FDA, PMDA, and EMA who want a reproducible,
#' scriptable alternative to Java-based validators. herald reads SDTM
#' and ADaM datasets from XPT, Dataset-JSON, and Parquet, applies a
#' Define-XML 2.1 specification, and runs the published CDISC Library
#' rule corpus against the data -- with no JVM, no external service,
#' and full provenance back to the CDISC source for every finding.
#'
#' @section Workflow:
#' herald is organized as a seven-layer stack. Each layer has a small,
#' stable surface; downstream layers consume the output of upstream
#' layers without reaching across.
#'
#' \preformatted{
#'  6  write_report_html() / xlsx / json     reporting
#'  5  validate(files = ..., rules = ...)    conformance engine
#'  4  rule corpus (YAML -> rules.rds)       rule catalog
#'  3  Dictionary Provider Protocol          CT / SRS / MedDRA / user
#'  2  apply_spec(datasets, spec)            pre-validation attr stamp
#'  1  as_herald_spec() / ds_spec + var_spec specification object
#'  0  read_xpt / read_json / read_define_xml dataset + spec ingest
#' }
#'
#' Key entry points by layer:
#'
#' - L0 ingest: [read_xpt()], [read_json()], [read_parquet()],
#'   [read_define_xml()]
#' - L1 spec: [as_herald_spec()], [herald_spec()], [validate_spec()]
#' - L2 stamp: [apply_spec()]
#' - L3 dictionaries: [ct_provider()], [register_dictionary()],
#'   [unregister_dictionary()]
#' - L4 catalog: [rule_catalog()], [supported_standards()]
#' - L5 engine: [validate()]
#' - L6 report: [report()], [write_report_html()],
#'   [write_report_xlsx()], [write_report_json()]
#'
#' See `vignette("architecture", package = "herald")` for the full
#' design rationale.
#'
#' @section Articles:
#' Documentation is grouped by audience. Start with "Getting started"
#' for a five-minute tour, then move to the cookbook for task recipes
#' or to the internals for design background.
#'
#' **Getting started**
#'
#' - `vignette("herald", package = "herald")` -- five-minute tour of
#'   the core workflow.
#' - `vignette("validation-reporting", package = "herald")` -- running
#'   [validate()] and rendering reports.
#'
#' **Cookbook and guides**
#'
#' - `vignette("cookbook", package = "herald")` -- task-oriented
#'   recipes (rule filtering, severity overrides, domain-scoped runs,
#'   batch validation).
#' - `vignette("extending-herald", package = "herald")` -- author your
#'   own ops, rules, and dictionary providers.
#' - `vignette("migrating-from-p21", package = "herald")` -- a
#'   side-by-side guide for teams switching from Pinnacle 21.
#' - `vignette("faq", package = "herald")` -- common questions and
#'   gotchas.
#' - `vignette("op-catalog", package = "herald")` -- searchable index
#'   of every operator in the rule engine.
#' - `vignette("data-io", package = "herald")` -- reading and writing
#'   XPT, Dataset-JSON, and Parquet.
#' - `vignette("define-xml", package = "herald")` -- Define-XML 2.1
#'   read-edit-write roundtrip.
#' - `vignette("dictionaries", package = "herald")` -- controlled
#'   terminology, SRS, MedDRA, and custom providers.
#' - `vignette("rule-coverage", package = "herald")` -- which CDISC
#'   rules are implemented today.
#' - `vignette("best-practices", package = "herald")` -- recommended
#'   patterns for production submissions.
#'
#' **Internals**
#'
#' - `vignette("architecture", package = "herald")` -- the layer stack
#'   and design decisions.
#'
#' @section Lifecycle:
#' herald is pre-CRAN and currently
#' `r lifecycle::badge("experimental")`. The public API may change
#' without deprecation cycles until the first CRAN release. See
#' `news(package = "herald")` for the changelog.
#'
#' @section Author:
#' Maintainer and contributor information is auto-generated from
#' `DESCRIPTION`; see the package citation via
#' `citation("herald")`.
#'
#' @keywords internal
#' @importFrom rlang caller_arg caller_env `%||%`
#' @importFrom lifecycle deprecated
"_PACKAGE"
