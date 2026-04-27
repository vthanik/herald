# herald cheatsheet

## herald cheatsheet

Pure-R CDISC conformance validation. Read submission datasets, attach
metadata, run rules, ship reviewer-ready reports – without Java or SAS.

SDTM-IG v2.0 · ADaM-IG v5.0 · Define-XML 2.1  
CDISC Library CORE · NCI EVS CT · MedDRA · WHODrug

L0  
Read  
read_xpt / read_json

L1  
Spec  
as_herald_spec

L2  
Stamp  
apply_spec

L3  
Dict  
ct_provider

L4  
Catalog  
rule_catalog

L5  
Validate  
validate

L6  
Report  
write_report_html

### L0 – Read

Pure-R ingest. No JVM, no SAS.

Transport

#### SAS XPT v5

Round-trip XPT with labels, lengths, types preserved.

``` r
dm <- read_xpt("dm.xpt")
write_xpt(dm, "dm.xpt", label = "Demographics")
```

**Tip:** XPT label = 40 char max, variable label = 200; truncation
throws `herald_error_input`.

Modern

#### Dataset-JSON v1.1

CDISC’s transport replacement – preserves types and ISO 8601 dates.

``` r
ae <- read_json("ae.json")
write_json(ae, "ae.json",
  dataset_label = "Adverse Events",
  iso_dates     = TRUE
)
```

Carries `name`, `label`, `itemOID`, `standard` on every column.

Analytics

#### Parquet

Arrow-backed columnar storage. Best for ADaM at scale.

``` r
adsl <- read_parquet("adsl.parquet")
write_parquet(adsl, "adsl.parquet")

convert_dataset("dm.xpt", "dm.parquet")
```

Requires `arrow`; falls back to a clear `herald_error_runtime` if
absent.

### L1 – Spec

Build the metadata object that drives stamping and validation.

From Define-XML

#### Lift metadata

Round-trip a Define-XML 2.1 document into a herald_spec.

``` r
def  <- read_define_xml("define.xml")
spec <- as_herald_spec(def)

is_herald_spec(spec) # TRUE
```

Carries codelists, methods, comments, value-level metadata, ARM display
sections.

From scratch

#### Hand-build a spec

Programmatic construction for tests, fixtures, sponsor extensions.

``` r
spec <- herald_spec(
  datasets  = list(
    DM = list(label = "Demographics",
              class = "SPECIAL PURPOSE")
  ),
  variables = list(
    DM = list(
      USUBJID = list(label = "Subject ID",
                     length = 30, type = "text"),
      AGE     = list(label = "Age", type = "integer")
    )
  )
)
```

Inspect

#### Walk a spec

Print, summarise, validate against the schema.

``` r
print(spec)
summary(spec)
validate_spec(spec)   # define-xml structure rules

names(spec$datasets)
spec$variables$DM$AGE
```

[`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md)
runs only the `DEFINE-NNN` rule subset – no datasets needed.

### L2 – Stamp

Project spec attributes onto data frames before validation.

Apply

#### Stamp a single dataset

``` r
dm <- apply_spec(dm, spec)

attr(dm, "label")             # "Demographics"
attr(dm$AGE, "label")         # "Age"
attr(dm$AGE, "herald_length") # 8
class(dm)                     # data.frame + sdtm class
```

Idempotent. Re-stamping replaces – never appends.

Bulk

#### Stamp a whole study

``` r
files <- list(DM = dm, AE = ae, EX = ex, VS = vs)
files <- Map(apply_spec, files, list(spec))

# or pass to validate() and let it stamp
validate(files = files, spec = spec)
```

Rules expecting `herald_length`, `herald_type`, dataset class will
fail-fast without stamping.

### L3 – Dictionaries

Controlled terminology + external dictionary providers.

CDISC CT

#### Bundled SDTM / ADaM CT

``` r
ct <- load_ct("sdtm", release = "2024-09-27")
ct_info(ct)
available_ct_releases("sdtm")

# refresh local NCI EVS cache
download_ct("sdtm")
```

External

#### MedDRA / WHODrug / SRS

``` r
mh   <- meddra_provider(path = "meddra/")
who  <- whodrug_provider(path = "whodrug/")
srs  <- srs_provider(release = "latest")

mh$contains("LLT", "Headache")
who$lookup("ATC", "N02BE01")
```

Custom

#### Sponsor / ad-hoc

``` r
my_codelist <- custom_provider(
  values = c("AE001", "AE002"),
  name   = "SPONSOR_AE_REASON"
)

register_dictionary("SPONSOR", my_codelist)
list_dictionaries()
unregister_dictionary("SPONSOR")
```

All providers share `contains()` + optional `lookup()` – rules don’t
care about source.

### L4 – Catalog

Inspect and filter the compiled rule corpus.

Browse

#### The rule catalog

``` r
cat <- rule_catalog()

# slice by standard
sdtm  <- cat[cat$standard == "SDTM-IG", ]
adam  <- cat[cat$standard == "ADaM-IG", ]
core  <- cat[cat$standard == "CORE",    ]

supported_standards()
```

Filter

#### Pick targeted rule sets

``` r
demog_rules <- cat[
  cat$dataset == "DM" &
    cat$severity == "error",
  "rule_id"
]

validate(files = files, spec = spec,
         rules = demog_rules)
```

Rule IDs are stable – safe to pin in study-level QC scripts.

##### Rule ID prefixes

| prefix          | source                             |
|-----------------|------------------------------------|
| `SDTMIG-CGNNNN` | SDTM-IG v2.0 (CG0001 – CG0666)     |
| `ADaM-N`        | ADaM-IG v5.0 (1 – ~790)            |
| `DEFINE-NNN`    | Define-XML 2.1 (001 – 225)         |
| `CORE-NNNNNN`   | SDTM Library API (000001 – 001082) |

##### Severity levels

| level     | meaning                     |
|-----------|-----------------------------|
| `error`   | Submission-blocking         |
| `warning` | Reviewer follow-up expected |
| `note`    | Informational, advisory     |

### L5 – Validate

Run the catalog. Returns a herald_result.

Run

#### End-to-end validate()

``` r
res <- validate(
  files = list(DM = dm, AE = ae),
  spec  = spec,
  rules = c("SDTMIG-CG0001",
            "CORE-000123")
)

summary(res)
```

Pass a directory path or a named list of data frames. Spec is optional
but unlocks metadata-aware rules.

Tune

#### Severity + scope filters

``` r
res <- validate(
  files        = "data/",
  spec         = spec,
  standards    = c("SDTM-IG", "Define-XML"),
  severity_map = c("SDTMIG-CG0042" = "warning"),
  dictionaries = list(MEDDRA = mh)
)
```

Skipped cross-dataset refs surface in `res$skipped_refs` – not as silent
passes.

##### Operator kinds (R/ops-\*.R) {.unnumbered}

| kind        | example use                   |
|-------------|-------------------------------|
| `set`       | Codelist membership           |
| `compare`   | Cross-variable comparisons    |
| `existence` | Variable presence / NA checks |
| `temporal`  | Date order, ISO 8601 parsing  |
| `cross`     | Cross-dataset joins           |
| `string`    | Pattern, regex, length        |

##### Error classes (always via herald_error())

| class                     | when                          |
|---------------------------|-------------------------------|
| `herald_error_input`      | User argument problem         |
| `herald_error_runtime`    | Internal / dependency failure |
| `herald_error_file`       | I/O, missing or unreadable    |
| `herald_error_spec`       | Spec construction or shape    |
| `herald_error_rule`       | Rule definition problem       |
| `herald_error_validation` | Engine run failure            |

### L6 – Report

Reviewer-ready artifacts. Self-contained, audit-friendly.

HTML

#### Self-contained QC report

``` r
write_report_html(res, "qc.html")
```

Findings, rule counts, dataset metadata, skipped refs, run metadata –
one file, no assets.

XLSX

#### Workbook for reviewers

``` r
write_report_xlsx(res, "qc.xlsx")
```

One sheet per section; severity-coloured rows.

JSON

#### Machine-readable artifact

``` r
write_report_json(res, "qc.json")

# or dispatch from extension
report(res, "out/qc.html")
report(res, "out/qc.xlsx")
```

Stable schema – safe for downstream dashboards, CI, ticket creation.

### End-to-end recipe

A full submission QC pass in one block.

``` r
library(herald)

# L0 + L1 -- read datasets and lift Define-XML metadata
def   <- read_define_xml("submission/define.xml")
spec  <- as_herald_spec(def)

files <- list(
  DM = read_xpt("submission/dm.xpt"),
  AE = read_json("submission/ae.json"),
  EX = read_xpt("submission/ex.xpt")
)

# L3 -- attach external dictionaries
mh  <- meddra_provider(path = "dict/meddra/")

# L5 -- run targeted validation
res <- validate(
  files        = files,
  spec         = spec,
  standards    = c("SDTM-IG", "Define-XML"),
  dictionaries = list(MEDDRA = mh),
  severity_map = c("SDTMIG-CG0042" = "warning")
)

# L6 -- ship reviewer artifacts
write_report_html(res, "out/qc.html")
write_report_xlsx(res, "out/qc.xlsx")
write_report_json(res, "out/qc.json")
```

### Tips & pitfalls

Things experienced users wish they knew on day one.

- **Stamp before validate.** Metadata-aware rules silently skip on
  un-stamped data.
  [`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md)
  first.
- **Pin rule IDs in CI.** Catalog grows – `rules = c(...)` keeps reviews
  reproducible across releases.
- **Use `severity_map`, not forks.** Demote sponsor-irrelevant rules
  without editing YAML.
- **Inspect `res$skipped_refs`.** Cross-dataset rules skip when refs
  missing – not a pass.
- **Errors are typed.** `tryCatch(..., herald_error_input = ...)` beats
  string matching.
- **Define-XML alone is valid input.** Run
  [`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md)
  against `define.xml` with no datasets.
- **Parquet for big ADaM.** XPT \> 2 GB is risky;
  [`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md)
  moves formats while preserving labels.
- **Custom providers cost nothing.** Wrap any vector with
  [`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md)
  and register it.
