# Migrating from Pinnacle 21

This article maps Pinnacle 21 (P21) workflows to their `herald`
equivalents. Both tools validate CDISC datasets against the same
published rule sources – SDTM-IG, ADaM-IG, Define-XML 2.1, and the CDISC
Library API. The differences are operational, not substantive: rule
selection, reporting formats, dependency footprint, and how the tool
fits into a reproducible R pipeline.

## Concept map

| Concept                  | Pinnacle 21 (P21)                         | herald                                                                                                                                                                                                                                                                     |
|--------------------------|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Run a validation         | Configure a job in the GUI                | `validate(path = "data/sdtm")`                                                                                                                                                                                                                                             |
| Specify the standard     | Pick an engine version (e.g. SDTM-IG 3.4) | `standards = "SDTM-IG"`                                                                                                                                                                                                                                                    |
| Apply a sponsor profile  | Save / load a profile XML                 | `severity_map = c(Medium = "High")` plus `rules =` filter                                                                                                                                                                                                                  |
| Provide define.xml       | Browse to file in the GUI                 | `read_define_xml("define.xml")` -\> pass to [`validate()`](https://vthanik.github.io/herald/reference/validate.md)                                                                                                                                                         |
| Plug in MedDRA / WHODrug | Configure dictionaries page               | [`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md), [`whodrug_provider()`](https://vthanik.github.io/herald/reference/whodrug_provider.md), [`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md) |
| Get the report           | XLSX / PDF dashboard                      | `report(result, "out.html")` (HTML / XLSX / JSON)                                                                                                                                                                                                                          |
| Run from CI              | Custom shell wrapper around CLI           | Pure-R: any CI that runs `Rscript`                                                                                                                                                                                                                                         |
| Runtime                  | Java + GUI / CLI                          | Pure R, no JVM                                                                                                                                                                                                                                                             |

## Rule ID mapping

`herald` keeps the published CDISC identifier verbatim, with a small
prefix that names the source standard. P21 rule codes correspond
one-to-one with the CDISC publication they were derived from.

| Source (where the rule lives) | herald prefix   | Example         | P21 column        |
|-------------------------------|-----------------|-----------------|-------------------|
| ADaM IG v5.0                  | `ADaM-N`        | `ADaM-1`        | “ADaM IG Rule”    |
| SDTM IG v2.0 conformance      | `SDTMIG-CGNNNN` | `SDTMIG-CG0001` | “SDTM CG Rule”    |
| Define-XML v2.1 conformance   | `DEFINE-NNN`    | `DEFINE-001`    | “Define-XML Rule” |
| CDISC Library API rule        | `CORE-NNNNNN`   | `CORE-000001`   | “CORE Rule”       |

Every rule that P21 emits is therefore findable in the herald catalog:

``` r
catalog <- rule_catalog()

# Rule counts by standard
table(catalog$standard)
#> 
#>     ADaM-IG  Define-XML herald-spec     SDTM-IG     SEND-IG 
#>         790         231         103         740           1

# Find a rule by exact ID
catalog[catalog$rule_id == "ADaM-1", c("rule_id", "standard", "severity")]
#> # A tibble: 0 × 3
#> # ℹ 3 variables: rule_id <chr>, standard <chr>, severity <chr>
```

## Side-by-side: a basic SDTM run

**Pinnacle 21 Community workflow**

1.  Open Pinnacle 21 Community.
2.  Validate Data tab -\> Browse to the SDTM directory.
3.  Pick `SDTM-IG 3.4` as the engine version.
4.  Click *Validate*.
5.  Open the resulting `.xlsx` from the Reports tab.

**herald equivalent**

``` r
out <- file.path(tempdir(), "p21-migration")
dir.create(out, showWarnings = FALSE, recursive = TRUE)

write_xpt(apply_spec(dm, sdtm_spec), file.path(out, "dm.xpt"))

result <- validate(
  path      = out,
  standards = "SDTM-IG",
  quiet     = TRUE
)

report(result, file.path(out, "p21-style-report.xlsx"))
file.exists(file.path(out, "p21-style-report.xlsx"))
#> [1] TRUE
```

## Side-by-side: validating with a Define-XML

**P21**: drag the `define.xml` into the *Define* slot in the GUI.

**herald**: read the Define-XML, hand it to
[`validate()`](https://vthanik.github.io/herald/reference/validate.md).
The same Define-XML is then used to derive the spec for
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md).

``` r
d <- read_define_xml("metadata/define.xml")
spec <- as_herald_spec(d)

result <- validate(
  path   = "data/sdtm",
  spec   = spec,
  define = d,
  quiet  = TRUE
)
```

## Side-by-side: dictionary configuration

**P21**: *Configure -\> Dictionaries* -\> point at MedDRA / WHODrug
folders. P21 stores the choice in its application config.

**herald**: register providers explicitly, in code, with version locked.

``` r
dictionaries <- list(
  "ct-sdtm" = ct_provider("sdtm", version = "2024-09-27"),
  "meddra"  = meddra_provider("dictionaries/meddra", version = "27.0"),
  "whodrug" = whodrug_provider("dictionaries/whodrug", version = "2024-03")
)

result <- validate(
  path         = "data/sdtm",
  dictionaries = dictionaries,
  quiet        = TRUE
)
```

The R approach makes the dictionary version part of the script, so
re-running the script next year with the same dictionary version gives
the same findings.

## Severity differences

P21 publishes severities in its proprietary scheme: **Reject / Error /
Warning / Notice**. CDISC publishes severities as **High / Medium /
Low**. The herald catalog uses CDISC severities verbatim and exposes a
`severity_map=` knob to rewrite labels at run time without touching the
catalog.

| CDISC severity (herald) | Common P21 mapping     |
|-------------------------|------------------------|
| `High`                  | Reject / Error         |
| `Medium`                | Warning                |
| `Low`                   | Notice / informational |

If your sponsor SOP requires a P21-style scheme, apply it inline:

``` r
p21_style <- c("High" = "Error", "Medium" = "Warning", "Low" = "Notice")

result <- validate(
  files        = list(DM = apply_spec(dm, sdtm_spec)),
  standards    = "SDTM-IG",
  severity_map = p21_style,
  quiet        = TRUE
)

table(result$findings$severity)
#> 
#>   Error Warning 
#>       1     241
```

## Output formats

| P21 output                              | herald equivalent                                         |
|-----------------------------------------|-----------------------------------------------------------|
| Validation Report `.xlsx`               | `report(result, "report.xlsx")`                           |
| PDF report                              | `report(result, "report.html")` (HTML, browser-printable) |
| Data Issues Detail tab                  | `result$findings` (tibble)                                |
| Dataset Details / Variable Details tabs | `result$datasets_checked`, `result$rules_total`           |
| JSON export (Enterprise only)           | `report(result, "report.json")` (always)                  |

The HTML report is self-contained and can be archived or attached to
review packets. The JSON output is stable and intended for CI gates,
audit dashboards, and downstream tooling.

## What does *not* carry over

Some P21 features have no direct herald equivalent today; the project
tracks these explicitly.

| P21 feature                      | Status in herald                                                                      |
|----------------------------------|---------------------------------------------------------------------------------------|
| Hosted submission package upload | Out of scope (use git / sponsor archive).                                             |
| GUI rule customisation           | Use rule filters (`rules =`, `standards =`) and `severity_map` in code.               |
| Java-side performance tuning     | N/A – pure R, no JVM.                                                                 |
| P21 Enterprise issue triage UI   | Use the HTML / XLSX report; persist `result` for diff.                                |
| P21 study profiles (XML)         | Replace with a single R settings list (see *Cookbook – Reproducible runs with renv*). |

## Migration checklist

1.  Inventory the P21 rule set you currently run (Reject/Error tier
    first).
2.  Map each rule code to a herald `rule_id`. The prefix tells you the
    standard.
3.  Lock dictionary versions in code, not in a GUI config.
4.  Replace the “validate -\> open xlsx” loop with one R script that
    produces all three report formats from the same `herald_result`.
5.  Add a CI gate using `is_blocking()` (see the *Cookbook* article) so
    high-impact findings stop the build.
6.  Diff the herald findings against the last P21 run during the
    transition; investigate any rule with a different verdict.

## Where to go next

- `cookbook` – ready-to-run recipes against the bundled pilot data.
- `extending-herald` – add a sponsor-private dictionary or operator.
- `faq` – short answers to first-time-user issues.
