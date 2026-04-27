# Package index

## Dataset I/O

Read and write clinical datasets without a Java or SAS dependency.
[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md)
and
[`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md)
handle SAS transport files in pure R.
[`read_json()`](https://vthanik.github.io/herald/reference/read_json.md)
and
[`write_json()`](https://vthanik.github.io/herald/reference/write_json.md)
support CDISC Dataset-JSON v1.1.
[`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md)
and
[`write_parquet()`](https://vthanik.github.io/herald/reference/write_parquet.md)
use Arrow when available.
[`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md)
moves between formats while preserving labels, lengths, types, and
dataset-level metadata.

- [`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md)
  **\[stable\]** : Read a SAS Transport (XPT) file into a data frame
- [`write_xpt()`](https://vthanik.github.io/herald/reference/write_xpt.md)
  **\[stable\]** : Write a data frame to a SAS Transport (XPT) file
- [`read_json()`](https://vthanik.github.io/herald/reference/read_json.md)
  : Read a CDISC Dataset-JSON file
- [`write_json()`](https://vthanik.github.io/herald/reference/write_json.md)
  : Write a data frame as CDISC Dataset-JSON v1.1
- [`read_parquet()`](https://vthanik.github.io/herald/reference/read_parquet.md)
  : Read an Apache Parquet dataset with CDISC column attributes
- [`write_parquet()`](https://vthanik.github.io/herald/reference/write_parquet.md)
  : Write a data frame to Apache Parquet with CDISC column attributes
- [`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md)
  : Convert a dataset between XPT, Dataset-JSON, and Parquet

## Specification Metadata

Build and inspect `herald_spec` objects: the metadata source for dataset
labels, variable labels, storage lengths, expected types, standards, and
dataset classes.
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
stamps those attributes onto data frames before validation and transport
writing.

- [`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md)
  **\[experimental\]** :

  Construct a `herald_spec` object

- [`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md)
  **\[experimental\]** : Construct a rich herald_spec with all
  submission slots

- [`is_herald_spec()`](https://vthanik.github.io/herald/reference/is_herald_spec.md)
  :

  Is `x` a `herald_spec`?

- [`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
  **\[stable\]** :

  Stamp column and dataset attributes from a `herald_spec`

## Define-XML 2.1

Read, write, and render Define-XML 2.1. The rich
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md)
constructor carries study metadata, datasets, variables, codelists,
methods, comments, document leaves, value-level metadata, and ADaM ARM.
Parsed Define-XML can be passed to
[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
so metadata-dependent rules run with the same context as reviewers.

- [`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md)
  **\[stable\]** : Read a Define-XML 2.1 file
- [`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md)
  : Write a Define-XML 2.1 file from a herald specification
- [`write_define_html()`](https://vthanik.github.io/herald/reference/write_define_html.md)
  : Write a Define-XML 2.1 HTML rendering
- [`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md)
  : Validate a herald_spec for Define-XML completeness

## Validation Engine

[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
runs the compiled rule catalog against directories or named lists of
data frames and returns a `herald_result`. Rule filters can target exact
IDs, authorities, standards, and study-specific severity policies.
[`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md)
and
[`supported_standards()`](https://vthanik.github.io/herald/reference/supported_standards.md)
expose the compiled corpus for planning, QC, and coverage review.

- [`validate()`](https://vthanik.github.io/herald/reference/validate.md)
  **\[stable\]** : Validate CDISC clinical data against the conformance
  rule catalog
- [`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md)
  **\[experimental\]** : Compiled rule catalog
- [`supported_standards()`](https://vthanik.github.io/herald/reference/supported_standards.md)
  : Summarise herald's standards coverage

## Reports

Convert `herald_result` objects into submission-review artifacts.
[`report()`](https://vthanik.github.io/herald/reference/report.md)
dispatches from file extension; explicit writers produce self-contained
HTML, workbook-style XLSX, and machine-readable JSON. Reports include
findings, rule counts, dataset metadata, skipped references, and run
metadata.

- [`report()`](https://vthanik.github.io/herald/reference/report.md)
  **\[stable\]** : Write a herald_result to disk in any supported format
- [`write_report_html()`](https://vthanik.github.io/herald/reference/write_report_html.md)
  **\[experimental\]** : Write a herald_result as a self-contained HTML
  report
- [`write_report_xlsx()`](https://vthanik.github.io/herald/reference/write_report_xlsx.md)
  **\[experimental\]** : Write a herald_result as a five-sheet XLSX
  workbook
- [`write_report_json()`](https://vthanik.github.io/herald/reference/write_report_json.md)
  **\[experimental\]** : Write a herald_result as canonical JSON

## Controlled Terminology

Load bundled SDTM and ADaM controlled terminology, inspect release
metadata, list available NCI EVS releases, and refresh local caches.
[`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md)
exposes CDISC CT through the same dictionary-provider protocol used by
SRS, MedDRA, WHODrug, LOINC, SNOMED, and sponsor dictionaries.

- [`load_ct()`](https://vthanik.github.io/herald/reference/load_ct.md) :
  Load bundled or cached CDISC Controlled Terminology
- [`ct_info()`](https://vthanik.github.io/herald/reference/ct_info.md) :
  Summarise the currently resolvable CT.
- [`available_ct_releases()`](https://vthanik.github.io/herald/reference/available_ct_releases.md)
  : List available CDISC CT releases
- [`download_ct()`](https://vthanik.github.io/herald/reference/download_ct.md)
  : Download + cache a CDISC CT release from NCI EVS
- [`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md)
  **\[experimental\]** : CDISC Controlled Terminology as a Dictionary
  Provider

## External Dictionary Providers

Register external or sponsor-owned terminology sources for validation
runs. Providers expose `contains()` and optional `lookup()` methods so
rules can check dictionary membership without knowing the file format.
Use session-wide registration for interactive work or pass providers
directly to `validate(dictionaries = ...)` for reproducible pipelines.

- [`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md)
  **\[experimental\]** : Construct a dictionary-provider object
- [`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md)
  **\[experimental\]** : Generic in-memory Dictionary Provider
- [`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md)
  **\[experimental\]** : Install a dictionary provider in the session
  registry
- [`unregister_dictionary()`](https://vthanik.github.io/herald/reference/unregister_dictionary.md)
  **\[experimental\]** : Remove a dictionary from the session registry
- [`list_dictionaries()`](https://vthanik.github.io/herald/reference/list_dictionaries.md)
  : List known dictionaries
- [`download_srs()`](https://vthanik.github.io/herald/reference/download_srs.md)
  : Download + cache the FDA SRS / UNII table
- [`srs_provider()`](https://vthanik.github.io/herald/reference/srs_provider.md)
  **\[experimental\]** : FDA SRS / UNII as a Dictionary Provider
- [`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md)
  **\[experimental\]** : MedDRA as a Dictionary Provider
- [`whodrug_provider()`](https://vthanik.github.io/herald/reference/whodrug_provider.md)
  **\[experimental\]** : WHO-Drug as a Dictionary Provider
- [`loinc_provider()`](https://vthanik.github.io/herald/reference/loinc_provider.md)
  **\[experimental\]** : LOINC as a Dictionary Provider
- [`snomed_provider()`](https://vthanik.github.io/herald/reference/snomed_provider.md)
  **\[experimental\]** : SNOMED CT as a Dictionary Provider

## Submission Discovery and ADaM Helpers

Helpers for classifying ADaM datasets and detecting analysis dataset
shapes from variable names. These functions are useful for routing
class-scoped ADaM rules and for checking whether a sponsor dataset looks
like ADSL, BDS, OCCDS, or ADTTE.

- [`detect_adam_class()`](https://vthanik.github.io/herald/reference/detect_adam_class.md)
  : Detect the ADaM dataset class from column names
- [`detect_adam_classes()`](https://vthanik.github.io/herald/reference/detect_adam_classes.md)
  : Detect ADaM class for each dataset

## Object Methods

Print and summary methods for the main herald objects. These keep
console output compact while preserving the full object for programmatic
access in pipelines and reports.

- [`print(`*`<herald_define>`*`)`](https://vthanik.github.io/herald/reference/print.herald_define.md)
  : Print a herald_define
- [`print(`*`<herald_dict_provider>`*`)`](https://vthanik.github.io/herald/reference/print.herald_dict_provider.md)
  : Print a herald_dict_provider
- [`print(`*`<herald_result>`*`)`](https://vthanik.github.io/herald/reference/print.herald_result.md)
  : Print a herald_result
- [`print(`*`<herald_spec>`*`)`](https://vthanik.github.io/herald/reference/print.herald_spec.md)
  : Print a herald_spec
- [`summary(`*`<herald_result>`*`)`](https://vthanik.github.io/herald/reference/summary.herald_result.md)
  : Summarise a herald_result

## Operators

The validation engine dispatches each rule to a registered operator – a
vectorised predicate with signature `op(data, ctx, ...)`. Operators are
referenced by name from rule YAML and resolved at run time. The full
sortable catalog of built-in operators, their kinds, arg schemas, and
cost hints lives in the operator catalog vignette.

- [`herald-ops-catalog`](https://vthanik.github.io/herald/reference/herald-ops-catalog.md)
  : Operator catalog

## Built-in Datasets

Lazy-loaded SDTM and ADaM datasets and specs shipped with the package.
Use directly in examples and vignettes without
[`readRDS()`](https://rdrr.io/r/base/readRDS.html) or
[`system.file()`](https://rdrr.io/r/base/system.file.html). The
`pilot-data` page documents the legacy `.rds` fixtures retained under
`inst/extdata` for backwards compatibility.

- [`dm`](https://vthanik.github.io/herald/reference/dm.md) : Pilot DM
  (Demographics) domain
- [`adsl`](https://vthanik.github.io/herald/reference/adsl.md) : Pilot
  ADSL (Subject-Level Analysis Dataset)
- [`adae`](https://vthanik.github.io/herald/reference/adae.md) : Pilot
  ADAE (Adverse Events Analysis Dataset, OCCDS)
- [`advs`](https://vthanik.github.io/herald/reference/advs.md) : Pilot
  ADVS (Vital Signs Analysis Dataset, BDS)
- [`sdtm_spec`](https://vthanik.github.io/herald/reference/sdtm_spec.md)
  : Pilot SDTM specification (herald_spec)
- [`adam_spec`](https://vthanik.github.io/herald/reference/adam_spec.md)
  : Pilot ADaM specification (herald_spec)
- [`pilot-data`](https://vthanik.github.io/herald/reference/pilot-data.md)
  : CDISC Pilot 03 example data and specs (bundled)
