# Validate CDISC clinical data against the conformance rule catalog

**\[stable\]**

The primary entry point for CDISC conformance checking. Runs SDTM-IG,
ADaM-IG, and SEND-IG rules from the compiled catalog against a set of
clinical datasets and returns a `herald_result` carrying every finding,
the full rule catalog snapshot, and dataset metadata.

Supply datasets as a directory path (XPT or Dataset-JSON files on disk)
or directly as a named list of data frames. `validate()` is the only
function you need for a round-trip submission check:

- Loads the compiled rule catalog (`inst/rules/rules.rds` and
  `inst/rules/spec_rules.rds`) on first call and caches it.

- Resolves rule scope per dataset using the autodetected profile
  (`"sdtm"`, `"adam"`, `"send"`) and any class hints from `spec`.

- Walks each rule's compiled `check_tree` against the relevant datasets,
  recording fired and advisory findings.

- Returns a `herald_result` ready for
  [`report()`](https://vthanik.github.io/herald/reference/report.md) and
  friends.

For best results, stamp CDISC attributes first with
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md).

## Usage

``` r
validate(
  path = NULL,
  files = NULL,
  spec = NULL,
  rules = NULL,
  authorities = NULL,
  standards = NULL,
  dictionaries = NULL,
  study_metadata = NULL,
  define = NULL,
  severity_map = NULL,
  quiet = FALSE
)
```

## Arguments

- path:

  Directory path containing `.xpt` or `.json` datasets. Mutually
  exclusive with `files`.

- files:

  A single data frame or a list of data frames. When passed directly
  (e.g. `files = dm`), the dataset name is inferred from the variable
  name and uppercased (`dm` -\> `"DM"`). Explicit names are required
  when the variable name does not match the domain (e.g.
  `list(DM = dm_loaded)`). Mutually exclusive with `path`.

- spec:

  Optional `herald_spec` from
  [`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md)
  or
  [`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md).
  Used for class resolution and anchor variables.

- rules:

  Character vector of rule IDs to run (e.g. `c("CG0001", "ADaM-005")`).
  `NULL` (default) runs the full catalog.

- authorities:

  Character vector of authorities to include (e.g. `c("CDISC", "FDA")`).
  `NULL` (default) includes all.

- standards:

  Character vector of standards to include (e.g.
  `c("SDTM-IG", "ADaM-IG")`). `NULL` (default) includes all.

- dictionaries:

  Named list of `herald_dict_provider` objects from
  [`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md),
  [`srs_provider()`](https://vthanik.github.io/herald/reference/srs_provider.md),
  [`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md),
  etc. Per-run overrides to the session registry set by
  [`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md).

- study_metadata:

  Named list of sponsor-supplied study characteristics. Recognised key:
  `collected_domains` – character vector of CDISC domain codes collected
  in this study (e.g. `c("MB", "PC")`). Rules that require this key
  return `NA` advisory when it is absent.

- define:

  A `herald_define` object from
  [`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md).
  Activates Define-XML dependent rules (e.g. CG0019, CG0400) that
  otherwise return `NA` advisory.

- severity_map:

  Named character vector (or named list for domain-scoped overrides)
  remapping rule severities at run time. Match priority (first wins):

  1.  Exact rule ID: `c("CG0085" = "Reject")`.

  2.  Regex on rule ID: `c("^ADaM-7[0-9]{2}$" = "High")`.

  3.  Severity category: `c("Medium" = "High")`.

  For domain-scoped overrides use a named list as the value:
  `list("CG0085" = list(ADSL = "Reject", BDS = "High", default = "Medium"))`.
  Findings include a `severity_override` column when an override is
  applied.

- quiet:

  Logical. Suppress progress output. Default `FALSE`.

## Value

A `herald_result` S3 object with fields:

- `findings`:

  Data frame – one row per (rule, dataset, record) finding. Columns:
  `rule_id`, `dataset`, `row`, `variable`, `value`, `status` (`"fired"`
  or `"advisory"`), `severity`, `message`, `severity_override`.

- `rule_catalog`:

  Data frame snapshot of every rule applied, with `id`, `title`,
  `authority`, `standard`, `severity`, `source_url`, and per-rule
  `fired_n` / `advisory_n` counts.

- `dataset_meta`:

  Named list – one entry per dataset with row/column counts, detected
  class, and per-dataset finding tallies.

- `datasets_checked`:

  Character vector of dataset names that were evaluated.

- `skipped_refs`:

  List of cross-dataset references that could not be resolved (missing
  datasets).

- `timestamp`:

  `POSIXct` of when `validate()` was called.

- `duration`:

  `difftime` of total elapsed time.

- `profile`:

  Character – `"sdtm"`, `"adam"`, `"send"`, or `"unknown"` –
  autodetected from dataset names.

## Catalog loading and scope

On entry `validate()` reads the compiled catalog (rules + spec
pre-flight rules), then narrows it by `rules`, `authorities`, and
`standards`. Scope is resolved per (rule, dataset): a rule scoped to
SDTM `EX` only runs against datasets detected as `EX`, and a rule scoped
to an ADaM class (`"BDS"`, `"OCCDS"`) consults the dataset's detected
class (or `spec$ds_spec$class` when `spec` is supplied).

## Severity-map precedence

`severity_map` overrides match in this order (first wins): exact
rule-id, regex on rule-id, severity category. A domain-scoped value (a
named list under a rule-id key) is consulted last using the dataset's
class. Findings carry a `severity_override` column when an override
applied.

## Virtual datasets from Define-XML

When `define = read_define_xml(...)` is supplied, herald materialises a
small set of "virtual" datasets such as `Define_Dataset_Metadata`,
`Define_Variable_Metadata`, and `Define_Codelist_Metadata` from the
parsed XML and injects them into `datasets`. Define-XML dependent rules
(e.g. CG0019, CG0400) become evaluable; without `define` they return
advisory `NA`.

## Advisory collapse

Operators may legitimately return `NA` to mean "I cannot answer".
`validate()` collapses repeated advisory rows into a single advisory
finding per (rule, dataset) so the report is not flooded by missing
references. The unresolved references surface in `result$skipped_refs`.

## See also

[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
to stamp CDISC attributes before validation,
[`write_report_html()`](https://vthanik.github.io/herald/reference/write_report_html.md)
/
[`write_report_xlsx()`](https://vthanik.github.io/herald/reference/write_report_xlsx.md)
to render results,
[`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md)
to browse the available rules.

Other validate:
[`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md),
[`supported_standards()`](https://vthanik.github.io/herald/reference/supported_standards.md)

## Examples

``` r
# \donttest{
dm   <- readRDS(system.file("extdata", "dm.rds",        package = "herald"))
spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
dm   <- apply_spec(dm, spec)
ae   <- data.frame(STUDYID = "PILOT01", DOMAIN = "AE", USUBJID = "PILOT01-001-001",
                   AETERM = "HEADACHE", AEDECOD = "Headache",
                   stringsAsFactors = FALSE)

# single dataset -- name inferred from variable (dm -> "DM")
r <- validate(files = dm, quiet = TRUE)
r$datasets_checked
#> [1] "DM"
r$findings[r$findings$status == "fired", c("rule_id", "message")]
#> # A tibble: 105 × 2
#>    rule_id     message                                            
#>    <chr>       <chr>                                              
#>  1 1           ADSL dataset does not exist                        
#>  2 CG0313      STUDYID, USUBJID or POOLID, DOMAIN, and DMSEQ exist
#>  3 CG0501      TM dataset present in study                        
#>  4 CG0502      TM dataset present in study                        
#>  5 CORE-000655 Values between ARMCD and ACTARMCD are not matching 
#>  6 CORE-000655 Values between ARMCD and ACTARMCD are not matching 
#>  7 CORE-000655 Values between ARMCD and ACTARMCD are not matching 
#>  8 CORE-000655 Values between ARMCD and ACTARMCD are not matching 
#>  9 CORE-000655 Values between ARMCD and ACTARMCD are not matching 
#> 10 CORE-000655 Values between ARMCD and ACTARMCD are not matching 
#> # ℹ 95 more rows

# multiple datasets
r2 <- validate(files = list(DM = dm, AE = ae), quiet = TRUE)
r2$datasets_checked
#> [1] "DM" "AE"
r2$profile   # "sdtm", "adam", or "send"
#> [1] NA
# }
```
