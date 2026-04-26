# tools/ -- herald maintainer toolchain

Not shipped in the installed package (`^tools$` in `.Rbuildignore`).
Users of `herald` never run these. They interact with `inst/rules/rules.rds`
via `validate()` at runtime.

## Pipeline

```
CDISC Library API          CDISC XLSX files           Define-XML XLSX
        |                        |                           |
        v                        v                           v
harvest-cdisc-library.R   parse-conformance-xlsx.R   rule-authoring/
        |                        |                   ingest-define-xlsx.R
        v                        v                           |
handauthored/cdisc/        handauthored/cdisc/               |
  sdtm-library-api/          sdtm-ig-v2.0/         ----------+
  adam-library-api/          adam-v5.0/
                           handauthored/cdisc/
                             define-xml-v2.1/
        |                        |
        +--------+---------------+
                 |
     (rule-authoring/ workflow: discover -> apply-pattern -> compile)
                 |
                 v
         compile-rules.R
                 |
         +-------+--------+
         |                |
  inst/rules/          inst/rules/
  rules.rds            MANIFEST.json
  (shipped)            (shipped)
                 |
         seed-fixtures.R
                 |
  rule-authoring/fixtures/<authority>/<rule_id>/
    positive.json + negative.json
                 |
         fixture-coverage.R
                 |
  rule-authoring/fixtures/COVERAGE.md
```

---

## Top-level scripts

### `compile-rules.R`
**The only path into `inst/rules/`.** Reads every YAML under `handauthored/`
and writes `inst/rules/rules.rds` and `inst/rules/MANIFEST.json`.

```bash
Rscript tools/compile-rules.R
```

Run after any change to `handauthored/`. CI enforces this on PRs that
touch those files.

### `seed-fixtures.R`
Auto-generates golden test fixtures for executable rules. For each rule
with a supported `check_tree`, writes `positive.json` (fires) and
`negative.json` (passes) under `rule-authoring/fixtures/`. Every fixture
is validated via `validate()` before writing -- a fixture that does not
behave correctly is rejected.

```bash
Rscript tools/seed-fixtures.R           # skip existing
Rscript tools/seed-fixtures.R --force   # overwrite auto-seeded only
```

Fixtures marked `authored: "manual"` are never overwritten.

### `fixture-coverage.R`
Reports how many executable rules have both golden fixtures. Writes
`rule-authoring/fixtures/COVERAGE.md` and prints a terminal summary.

```bash
Rscript tools/fixture-coverage.R
```

### `harvest-cdisc-library.R`
Fetches machine-executable rules from the CDISC Library REST API.

```bash
export CDISC_LIBRARY_KEY='...'
Rscript tools/harvest-cdisc-library.R
Rscript tools/harvest-cdisc-library.R --dry-run
Rscript tools/harvest-cdisc-library.R --catalog sdtmig/3-4
Rscript tools/harvest-cdisc-library.R --force
```

Output: `handauthored/cdisc/{sdtm,adam}-library-api/<CORE-id>.yaml`.
Cache: `harvest-cache/` (gitignored). Auth: `CDISC_LIBRARY_KEY` env var.

### `parse-conformance-xlsx.R`
Parses CDISC XLSX Conformance Rules into narrative YAML stubs. The
`check_tree` blocks are narrative placeholders, filled in later via the
`rule-authoring/` workflow.

```bash
Rscript tools/parse-conformance-xlsx.R
```

Needs XLSX files in `handauthored/conformance/` (free CDISC account download).

---

## `rule-authoring/` -- predicate conversion workflow

Converts narrative rule YAMLs (text only) into executable `check_tree`
predicates. Use this when onboarding a new cluster of rules.

### Authoring flow

```
1. discover-patterns.R   -- find unclaimed rule clusters
2. write patterns/<name>.md + patterns/<name>.ids
3. apply-pattern.R       -- stamp check_tree into YAMLs
4. compile-rules.R       -- rebuild inst/rules/rules.rds
5. seed-fixtures.R       -- generate and validate golden fixtures
6. commit per pattern
```

### Scripts

| Script | Purpose |
|---|---|
| `discover-patterns.R` | Scan YAMLs, cluster by message, print top unclaimed patterns |
| `apply-pattern.R` | Apply a pattern template to a list of rule IDs (writes `check_tree`) |
| `build-catalog.R` | Regenerate `catalog.csv` from the live YAML corpus |
| `ingest-define-xlsx.R` | Parse CDISC Define-XML XLSX into `handauthored/cdisc/define-xml-v2.1/` |
| `advisory.R` | Interactive helpers for reviewing advisory findings; source interactively |
| `debug-seed.R` | Diagnostic: records why each rule is skipped by `seed-fixtures.R` |

```bash
Rscript tools/rule-authoring/discover-patterns.R [--top N]
Rscript tools/rule-authoring/apply-pattern.R --pattern <name> --ids patterns/<name>.ids [--dry-run]
Rscript tools/rule-authoring/build-catalog.R
Rscript tools/rule-authoring/ingest-define-xlsx.R /path/to/define.xlsx
```

### Files

| File | Purpose |
|---|---|
| `catalog.csv` | All rule IDs, executability, pattern assignment, blockers |
| `CONVENTIONS.md` | Pattern authoring conventions and design decisions |
| `coverage.md` | Pattern-level progress (written by `discover-patterns.R`) |
| `patterns/` | One `.md` + `.ids` per pattern; `README.md` inside |
| `fixtures/` | Golden fixtures per rule + `COVERAGE.md` |

---

## `handauthored/` -- rule source corpus

```
handauthored/
+-- cdisc/
|   +-- NOTICE.md               CC-BY-4.0 attribution
|   +-- sdtm-library-api/       SDTM rules from CDISC Library API (executable)
|   +-- adam-library-api/       ADaM rules from CDISC Library API (executable)
|   +-- sdtm-ig-v2.0/           SDTM-IG v2.0 rules from XLSX (narrative)
|   +-- adam-v5.0/              ADaM v5.0 rules from XLSX (narrative)
|   +-- define-xml-v2.1/        Define-XML v2.1 rules (DEFINE-NNN)
+-- herald/
|   +-- spec-validation/        herald-spec pre-flight checks
|   +-- define-xml/             herald define-xml emitted-XML checks
+-- conformance/                source XLSX files (CDISC download)
```

Rule ID prefixes:

| Prefix | Standard |
|---|---|
| `CORE-NNNNNN` | CDISC Library API (SDTM + ADaM) |
| `ADaM-N` | ADaM-IG v5.0 |
| `SDTMIG-CGNNNN` | SDTM-IG v2.0 |
| `DEFINE-NNN` | Define-XML v2.1 |
