# herald: CDISC Conformance Validation for Clinical Trial Submissions

herald is a pure-R conformance validator for CDISC clinical trial
submissions. It is built for sponsor statistical programmers, data
standards leads, and regulatory submission teams preparing data packages
for the FDA, PMDA, and EMA who want a reproducible, scriptable
alternative to Java-based validators. herald reads SDTM and ADaM
datasets from XPT, Dataset-JSON, and Parquet, applies a Define-XML 2.1
specification, and runs the published CDISC Library rule corpus against
the data – with no JVM, no external service, and full provenance back to
the CDISC source for every finding.

## Workflow

herald is organized as a seven-layer stack. Each layer has a small,
stable surface; downstream layers consume the output of upstream layers
without reaching across.

     6  write_report_html() / xlsx / json     reporting
     5  validate(files = ..., rules = ...)    conformance engine
     4  rule corpus (YAML -> rules.rds)       rule catalog
     3  Dictionary Provider Protocol          CT / SRS / MedDRA / user
     2  apply_spec(datasets, spec)            pre-validation attr stamp
     1  as_herald_spec() / ds_spec + var_spec specification object
     0  read_xpt / read_json / read_define_xml dataset + spec ingest

Key entry points by layer:

- L0 ingest:
  [`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md),
  [`read_json()`](https://vthanik.github.io/herald/reference/read_json.md),
  [`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md),
  [`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md)

- L1 spec:
  [`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md),
  [`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md),
  [`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md)

- L2 stamp:
  [`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)

- L3 dictionaries:
  [`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
  [`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md),
  [`unregister_dictionary()`](https://vthanik.github.io/herald/reference/unregister_dictionary.md)

- L4 catalog:
  [`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md),
  [`supported_standards()`](https://vthanik.github.io/herald/reference/supported_standards.md)

- L5 engine:
  [`validate()`](https://vthanik.github.io/herald/reference/validate.md)

- L6 report:
  [`report()`](https://vthanik.github.io/herald/reference/report.md),
  [`write_report_html()`](https://vthanik.github.io/herald/reference/write_report_html.md),
  [`write_report_xlsx()`](https://vthanik.github.io/herald/reference/write_report_xlsx.md),
  [`write_report_json()`](https://vthanik.github.io/herald/reference/write_report_json.md)

See
[`vignette("architecture", package = "herald")`](https://vthanik.github.io/herald/articles/architecture.md)
for the full design rationale.

## Articles

Documentation is grouped by audience. Start with "Getting started" for a
five-minute tour, then move to the cookbook for task recipes or to the
internals for design background.

**Getting started**

- [`vignette("herald", package = "herald")`](https://vthanik.github.io/herald/articles/herald.md)
  – five-minute tour of the core workflow.

- [`vignette("validation-reporting", package = "herald")`](https://vthanik.github.io/herald/articles/validation-reporting.md)
  – running
  [`validate()`](https://vthanik.github.io/herald/reference/validate.md)
  and rendering reports.

**Cookbook and guides**

- `vignette("cookbook", package = "herald")` – task-oriented recipes
  (rule filtering, severity overrides, domain-scoped runs, batch
  validation).

- `vignette("extending-herald", package = "herald")` – author your own
  ops, rules, and dictionary providers.

- `vignette("migrating-from-p21", package = "herald")` – a side-by-side
  guide for teams switching from Pinnacle 21.

- `vignette("faq", package = "herald")` – common questions and gotchas.

- `vignette("op-catalog", package = "herald")` – searchable index of
  every operator in the rule engine.

- [`vignette("data-io", package = "herald")`](https://vthanik.github.io/herald/articles/data-io.md)
  – reading and writing XPT, Dataset-JSON, and Parquet.

- [`vignette("define-xml", package = "herald")`](https://vthanik.github.io/herald/articles/define-xml.md)
  – Define-XML 2.1 read-edit-write roundtrip.

- [`vignette("dictionaries", package = "herald")`](https://vthanik.github.io/herald/articles/dictionaries.md)
  – controlled terminology, SRS, MedDRA, and custom providers.

- [`vignette("rule-coverage", package = "herald")`](https://vthanik.github.io/herald/articles/rule-coverage.md)
  – which CDISC rules are implemented today.

- [`vignette("best-practices", package = "herald")`](https://vthanik.github.io/herald/articles/best-practices.md)
  – recommended patterns for production submissions.

**Internals**

- [`vignette("architecture", package = "herald")`](https://vthanik.github.io/herald/articles/architecture.md)
  – the layer stack and design decisions.

## Lifecycle

herald is pre-CRAN and currently **\[experimental\]**. The public API
may change without deprecation cycles until the first CRAN release. See
`news(package = "herald")` for the changelog.

## Author

Maintainer and contributor information is auto-generated from
`DESCRIPTION`; see the package citation via `citation("herald")`.

## See also

Useful links:

- <https://github.com/vthanik/herald>

- <https://vthanik.github.io/herald/>

- Report bugs at <https://github.com/vthanik/herald/issues>

## Author

**Maintainer**: Vignesh <about.vignesh@gmail.com>
