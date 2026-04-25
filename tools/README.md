# tools/ — herald rule-harvesting toolchain

Maintainer scripts. **Not shipped** in the installed package (ignored via
`.Rbuildignore`). Users of `herald` never see or run these; they read
`inst/rules/rules.rds` at runtime via `validate()`.

## Pipeline

```
CDISC Library REST API                CDISC-published XLSX downloads
         │                                        │
         ▼                                        ▼
harvest-cdisc-library.R            parse-conformance-xlsx.R
         │                                        │
         ▼                                        ▼
cdisc/sdtm-library-api/*.yaml      cdisc/sdtm-ig-v2.0/*.yaml
cdisc/adam-library-api/*.yaml      cdisc/adam-v5.0/*.yaml
(machine-executable operator      (narrative rule text; predicate
 trees; Check block)               authoring pending)
         │                                        │
         └────────────────┬───────────────────────┘
                          ▼
                  compile-rules.R
                          ▼
              inst/rules/rules.rds          (shipped)
              inst/rules/rules.jsonl        (shipped, diffable)
              inst/rules/MANIFEST.json      (shipped)
```

Every rule in `inst/rules/rules.rds` traces back to one of the two upstream
sources. Nothing is orphan-copied.

## Scripts

### `harvest-cdisc-library.R` — Library API rules (executable)

Fetches machine-executable conformance rules (with operator-tree `Check`
blocks) from the CDISC Library REST API. These are what the runtime engine
actually fires against data.

**Needs** a free CDISC Library API key (request at
<https://api.developer.library.cdisc.org/>).

```bash
export CDISC_LIBRARY_KEY='...'
Rscript tools/harvest-cdisc-library.R              # all catalogs
Rscript tools/harvest-cdisc-library.R --dry-run
Rscript tools/harvest-cdisc-library.R --catalog sdtmig/3-4
Rscript tools/harvest-cdisc-library.R --force      # overwrite
```

Catalogs harvested: SDTMIG 3.2 / 3.3 / 3.4, ADaMIG 1.1 / 1.2 / 1.3.
Output: `tools/handauthored/cdisc/{sdtm,adam}-library-api/<CORE-Id>.yaml`.
Raw API responses cached at `tools/harvest-cache/` (gitignored).

### `parse-conformance-xlsx.R` — XLSX rules (narrative)

Parses CDISC's publicly-downloadable XLSX Conformance Rules documents into
YAML stubs. XLSX has metadata + rule TEXT but NOT machine-executable
predicates — those `check_tree`s get filled in over time by hand-authoring.

**Needs** the XLSX files downloaded (free CDISC account):

- [SDTM and SDTMIG Conformance Rules v2.0](https://www.cdisc.org/standards/foundational/sdtmig/sdtm-and-sdtmig-conformance-rules-v2-0)
- [ADaM Conformance Rules v5.0](https://www.cdisc.org/standards/foundational/adam/adam-conformance-rules-v5-0)

Place both at `tools/handauthored/conformance/` and run:

```bash
Rscript tools/parse-conformance-xlsx.R
```

Output: `tools/handauthored/cdisc/{sdtm-ig-v2.0,adam-v5.0}/<rule-id>.yaml`.

### `compile-rules.R` — the only path into `inst/rules/`

Reads every YAML under `tools/handauthored/**` and produces:

- `inst/rules/rules.rds` — binary (what `validate()` loads)
- `inst/rules/rules.jsonl` — human-readable, diffable
- `inst/rules/MANIFEST.json` — counts + integrity checks

```bash
Rscript tools/compile-rules.R
```

Runs fast (~1-2 s). CI gate: every PR that touches `tools/handauthored/`
must refresh `inst/rules/*` by running this.

Validates on compile:
- every rule has non-empty id + message + valid severity
- no duplicate rule ids
- content-hash dedup across sources

## Provenance + license

Every rule row in `rules.rds` carries:

| column | meaning |
|---|---|
| `authority` | CDISC / FDA / (HERALD removed in conformance-only scope) |
| `standard` | SDTM-IG / ADaM-IG / SEND-IG |
| `source_document` | canonical source (Library API or XLSX v2.0/v5.0) |
| `source_url` | public URL |
| `source_version` | rule version from upstream |
| `license` | CC-BY-4.0 |

Everything is CDISC-published content redistributed under CC-BY-4.0. See
`handauthored/cdisc/NOTICE.md` for attribution.

## Cache + source directories

```
tools/
├── harvest-cdisc-library.R       Library API -> YAML
├── parse-conformance-xlsx.R      XLSX -> YAML
├── compile-rules.R               YAML -> rules.rds
├── seed-fixtures.R               populate tests/testthat/fixtures/
├── fixture-coverage.R            report fixture gap coverage
├── advisory.R                    advisory-finding analysis helpers
├── harvest-cache/                raw Library API JSON (gitignored)
└── handauthored/
    ├── cdisc/
    │   ├── NOTICE.md
    │   ├── sdtm-library-api/     executable SDTM rules (from API)
    │   ├── sdtm-ig-v2.0/         narrative SDTM rules (from XLSX)
    │   ├── adam-library-api/     executable ADaM rules (from API)
    │   ├── adam-v5.0/            narrative ADaM rules (from XLSX)
    │   └── define-xml-v2.1/      CDISC Define-XML 2.1 narratives
    └── herald/
        ├── spec-validation/      herald-spec pre-flight rules
        └── define-xml/           herald define-xml emitted-XML rules
```

## Decommissioned scripts

Moved to `.local/quarantine/tools/` (gitignored). These were one-shot
authoring-time scripts with no live callers:

| Script | When decommissioned | Reason |
|---|---|---|
| `port-core.R` | 2026-04 | One-shot migration of core SDTM rules; work complete |
| `port-define.R` | 2026-04 | One-shot Define-XML rule migration; work complete |
| `rename-hrl-dd.R` | 2026-04 | One-shot HRL-DD prefix rename; work complete |
| `smoke-check.R` | 2026-04 | Smoke-test harness; superseded by testthat fixtures |

Scratch CSV intermediates (`progress.csv`, `core-vs-conformance.csv`,
`smoke-latest.csv`) were also deleted; they are regenerable from the rule
corpus.
