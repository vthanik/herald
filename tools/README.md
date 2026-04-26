# tools/ — herald maintainer toolchain

Not shipped in the installed package (`^tools$` in `.Rbuildignore`).
Users of `herald` never run these; they interact with `inst/rules/rules.rds`
at runtime via `validate()`.

## Full pipeline

```
CDISC Library REST API          CDISC-published XLSX           CDISC Define-XML XLSX
         │                              │                               │
         ▼                              ▼                               ▼
harvest-cdisc-library.R     parse-conformance-xlsx.R     rule-authoring/ingest-define-xlsx.R
         │                              │                               │
         ▼                              ▼                               ▼
handauthored/cdisc/          handauthored/cdisc/           handauthored/cdisc/
sdtm-library-api/*.yaml      sdtm-ig-v2.0/*.yaml           define-xml-v2.1/*.yaml
adam-library-api/*.yaml      adam-v5.0/*.yaml
         │                              │                               │
         └──────────────────┬───────────┘───────────────────────────────┘
                            │  (hand-authoring via rule-authoring/ tools)
                            ▼
                    compile-rules.R
                            ▼
                inst/rules/rules.rds        (shipped)
                inst/rules/MANIFEST.json    (shipped)
                            │
                    seed-fixtures.R
                            ▼
          rule-authoring/fixtures/<authority>/<rule_id>/
              positive.json + negative.json
                            │
                    fixture-coverage.R
                            ▼
          rule-authoring/fixtures/COVERAGE.md
```

---

## Top-level scripts

### `harvest-cdisc-library.R`
Fetches machine-executable rules (with `check_tree` operator blocks) from
the CDISC Library REST API.

```bash
export CDISC_LIBRARY_KEY='...'
Rscript tools/harvest-cdisc-library.R              # all catalogs
Rscript tools/harvest-cdisc-library.R --dry-run
Rscript tools/harvest-cdisc-library.R --catalog sdtmig/3-4
Rscript tools/harvest-cdisc-library.R --force
```

Output: `handauthored/cdisc/{sdtm,adam}-library-api/<CORE-id>.yaml`.
Cache: `harvest-cache/` (gitignored).

### `parse-conformance-xlsx.R`
Parses CDISC XLSX Conformance Rules into narrative YAML stubs. The
`check_tree` blocks are filled in later via the `rule-authoring/` workflow.

```bash
Rscript tools/parse-conformance-xlsx.R
```

Needs XLSX files in `handauthored/conformance/` (free CDISC account download).
Output: `handauthored/cdisc/{sdtm-ig-v2.0,adam-v5.0}/<rule-id>.yaml`.

### `compile-rules.R`
**The only path into `inst/rules/`.** Reads every YAML under
`handauthored/**` and writes:

- `inst/rules/rules.rds` — runtime binary loaded by `validate()`
- `inst/rules/MANIFEST.json` — counts + content-hash integrity

```bash
Rscript tools/compile-rules.R
```

Run this after any change to `handauthored/**`. CI gate enforces it on PRs
that touch those files.

### `seed-fixtures.R`
Auto-generates golden test fixtures for executable rules. For each rule
with a supported `check_tree`, builds a `positive.json` (rule fires) and
`negative.json` (rule passes) under `rule-authoring/fixtures/`.

```bash
Rscript tools/seed-fixtures.R           # skip existing
Rscript tools/seed-fixtures.R --force   # overwrite auto-seeded
```

Fixtures marked `authored: "manual"` are never overwritten.
Validates every fixture via `validate()` during seeding — a fixture that
doesn't fire correctly is rejected, not written.

### `fixture-coverage.R`
Reports how many executable rules have both golden fixtures. Writes
`rule-authoring/fixtures/COVERAGE.md` and prints a terminal summary.

```bash
Rscript tools/fixture-coverage.R
```

Run from CI or after `seed-fixtures.R` to check coverage progress.

### `advisory.R`
Interactive helpers for reviewing advisory findings during rule development.
Not run from CI — sourced interactively by maintainers.

```r
source("tools/advisory.R")
advisory_report(res)
```

---

## `rule-authoring/` — predicate conversion workflow

Converts narrative rule YAMLs (text only) into executable `check_tree`
predicates. Use this when onboarding a new cluster of rules.

### Authoring flow

```
1. discover-patterns.R   → find unclaimed rule clusters
2. Author patterns/<pattern>.md + patterns/<pattern>.ids
3. apply-pattern.R       → stamp check_tree into YAMLs
4. compile-rules.R       → rebuild inst/rules/rules.rds
5. seed-fixtures.R       → generate + validate golden fixtures
6. Commit per pattern
```

### Scripts

| Script | Purpose |
|---|---|
| `discover-patterns.R` | Scan YAMLs, cluster by message skeleton, update `coverage.md` |
| `apply-pattern.R` | Apply a pattern template to a list of rule IDs (writes `check_tree`) |
| `build-catalog.R` | Regenerate `catalog.csv` from the live YAML corpus |
| `ingest-define-xlsx.R` | Parse CDISC Define-XML XLSX into `handauthored/cdisc/define-xml-v2.1/` |

```bash
Rscript tools/rule-authoring/discover-patterns.R [--top N]
Rscript tools/rule-authoring/apply-pattern.R --pattern <name> --ids patterns/<name>.ids [--dry-run]
Rscript tools/rule-authoring/build-catalog.R
Rscript tools/rule-authoring/ingest-define-xlsx.R /path/to/define.xlsx
```

### Files

| File | Purpose |
|---|---|
| `catalog.csv` | Single source of truth: all rule IDs, executability, pattern, blockers |
| `CONVENTIONS.md` | Pattern authoring conventions and design decisions |
| `coverage.md` | Pattern-level progress snapshot (written by `discover-patterns.R`) |
| `patterns/` | One `.md` + `.ids` file per pattern; pattern-level README inside |
| `fixtures/` | Golden fixtures (`<authority>/<rule_id>/positive.json` + `negative.json`) and `COVERAGE.md` |

---

## `handauthored/` — rule source corpus

```
handauthored/
├── cdisc/
│   ├── NOTICE.md               CC-BY-4.0 attribution
│   ├── sdtm-library-api/       executable SDTM rules (from CDISC Library API)
│   ├── sdtm-ig-v2.0/           narrative SDTM rules (from XLSX)
│   ├── adam-library-api/       executable ADaM rules (from CDISC Library API)
│   ├── adam-v5.0/              narrative ADaM rules (from XLSX)
│   └── define-xml-v2.1/        CDISC Define-XML 2.1 rules (DEFINE-NNN)
└── herald/
    ├── spec-validation/        herald-spec pre-flight checks
    └── define-xml/             herald define-xml emitted-XML checks
```

Every rule traces to one upstream source. Rule IDs:

| Prefix | Standard |
|---|---|
| `ADaM-N` | ADaM-IG v5.0 |
| `SDTMIG-CGNNNN` | SDTM-IG v2.0 |
| `DEFINE-NNN` | Define-XML v2.1 |
| `CORE-NNNNNN` | CDISC Library API |

---

## Decommissioned scripts

Moved to `.local/quarantine/tools/` (gitignored):

| Script | When | Reason |
|---|---|---|
| `port-core.R` | 2026-04 | One-shot CORE rule migration; complete |
| `port-define.R` | 2026-04 | One-shot Define-XML migration; complete |
| `rename-hrl-dd.R` | 2026-04 | One-shot HRL-DD → DEFINE prefix rename; complete |
| `smoke-check.R` | 2026-04 | Superseded by `seed-fixtures.R` + testthat golden fixtures |
