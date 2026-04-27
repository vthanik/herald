# What CDISC rules does herald check?

## Why this vignette exists

herald is an open-source CDISC conformance validator built as a
transparent alternative to commercial tools. Before running a single
check, a programmer should be able to inspect the full rule corpus and
understand:

- which CDISC standards are covered today
- which specific rules have machine-executable predicates vs. which are
  still being ported
- what gaps exist and when they are likely to close

This vignette answers those questions with live data from the installed
package. Every table below is generated at render time from
[`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md)
and
[`supported_standards()`](https://vthanik.github.io/herald/reference/supported_standards.md)
– the numbers are never hard-coded.

------------------------------------------------------------------------

## Coverage by standard and authority

``` r
ss <- supported_standards()
knitr::kable(ss[, c("standard", "authority", "n_rules",
                    "n_predicate", "n_narrative", "pct_predicate")],
  digits = 3,
  col.names = c("Standard", "Authority", "Rules", "Executable",
                "Narrative", "% Executable")
)
```

| Standard    | Authority | Rules | Executable | Narrative | % Executable |
|:------------|:----------|------:|-----------:|----------:|-------------:|
| ADaM-IG     | CDISC     |   790 |        790 |         0 |        1.000 |
| Define-XML  | CDISC     |   225 |        225 |         0 |        1.000 |
| Define-XML  | HERALD    |     6 |          5 |         1 |        0.833 |
| herald-spec | HERALD    |   103 |        100 |         3 |        0.971 |
| SDTM-IG     | CDISC     |   659 |        659 |         0 |        1.000 |
| SDTM-IG     | FDA       |    81 |         81 |         0 |        1.000 |
| SEND-IG     | CDISC     |     1 |          1 |         0 |        1.000 |

Corpus compiled at: **2026-04-25T01:08:45Z**, herald version **0.1.0**.

------------------------------------------------------------------------

## Standards covered

- **SDTM-IG** (740 rules): Structural and content checks across all SDTM
  observation classes – domain existence, variable naming,
  controlled-terminology values, timing variables, relationships, and
  supplemental qualifiers. Rules sourced from CDISC SDTM and SDTMIG
  Conformance Rules v2.0 (CDISC authority) and FDA Technical Conformance
  Guide submissions guidance (FDA authority).

- **ADaM-IG** (790 rules): Dataset-level checks for ADSL, BDS, OCCDS,
  and ADTTE subject-level analysis datasets. Variable suffixes,
  baseline/change traceability, analysis flags, and treatment period
  variables. Rules sourced from CDISC ADaM Conformance Rules v5.0.

- **Define-XML** (231 rules):

  Structural conformance for `define.xml` v2.1 files – OID uniqueness,
  codelist references, value-level metadata, origin types, and ARM
  display metadata. CDISC-published rules plus herald gap-fill rules
  (`HERALD` authority) for checks the specification mandates but neither
  CDISC Library nor FDA publishes as machine-executable predicates.

- **SEND-IG** (1 rules): Initial SEND support; expanded coverage planned
  for a future release.

------------------------------------------------------------------------

## Authorities

| Authority  | What it covers                                                                                                                                           |
|------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| **CDISC**  | Machine-executable rules from the CDISC Library API and CDISC-published conformance XLSX documents. These are the same checks P21/OpenCDISC derive from. |
| **FDA**    | Rules derived from the FDA Technical Conformance Guide and eCTD-related FDA guidance documents (FDAB-series).                                            |
| **HERALD** | Gap-fill rules authored by the herald team where neither CDISC nor FDA publishes a machine check, but the underlying specification is unambiguous.       |

------------------------------------------------------------------------

## Executable predicates vs. narrative rules

Most rules in herald have an **executable predicate** – an operator tree
that fires against dataset rows and emits a finding when the condition
is violated. A small number are **narrative rules** that describe a
conformance requirement in text but whose predicate has not yet been
ported to a herald operator. Narrative rules never emit false findings;
they are simply skipped.

``` r
cat <- rule_catalog()
narrative <- cat[!cat$has_predicate, ]
if (nrow(narrative) == 0L) {
  message("All ", nrow(cat), " rules have executable predicates.")
} else {
  knitr::kable(
    aggregate(rule_id ~ standard, data = narrative, FUN = length),
    col.names = c("Standard", "Narrative rules (no predicate)")
  )
}
```

| Standard    | Narrative rules (no predicate) |
|:------------|-------------------------------:|
| Define-XML  |                              1 |
| herald-spec |                              3 |

------------------------------------------------------------------------

## Known gaps and roadmap

The areas below represent categories where coverage is thinner or where
rule authoring is actively in progress:

- **SEND-IG** – only 1 rule compiled today; SEND datasets pass
  structural xpt checks but full conformance coverage is not yet
  available.

- **SDTM-IG narrative rules** – the CDISC conformance XLSX contains
  rules whose predicates require complex multi-dataset joins (e.g.,
  sponsor-defined key relationships, sequence variable cross-domain
  checks). These are being ported incrementally.

- **ADaM-IG narrative rules** – similar to SDTM, rules involving
  join-time derivation logic (baseline window checks, treatment-period
  variable matching) are under active predicate authoring.

Progress is tracked internally. The 2026-04 corpus reflects 99.8%
executable coverage across all 1865 conformance rules.

------------------------------------------------------------------------

## Inspecting the catalog locally

``` r
library(herald)

# Full rule list -- filter and inspect as needed
cat <- rule_catalog()
cat[cat$standard == "ADaM-IG" & !cat$has_predicate, ]

# Coverage summary with corpus metadata
supported_standards()
```

------------------------------------------------------------------------

## Trust and transparency statement

herald ships its entire rule corpus inside the package at `inst/rules/`.
No rules are loaded from the network at runtime, no checks are silently
skipped, and no test fixtures are mocked. The compiled corpus is
reproducible: `tools/compile-rules.R` reads every YAML in
`tools/handauthored/` and writes `inst/rules/rules.rds` from scratch.

If you find a rule that fires incorrectly, does not fire when it should,
or is missing from this list, please open an issue. Corpus accuracy is a
first-class quality goal.
