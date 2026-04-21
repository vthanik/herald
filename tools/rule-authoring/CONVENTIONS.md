# CDISC IG Conventions -- Pattern Authoring Reference

This document distills the SDTM-IG v3.4 (chapters 1-4) and ADaM-IG v1.3
conventions most relevant to converting narrative rules into executable
`check_tree` predicates. It is a working reference for
`tools/rule-authoring/`. Source PDFs:

- `SDTMIG v3.4-FINAL_2022-07-21.pdf` -- user's local copy
- `ADaMIG_v1.3.pdf` -- user's local copy

Cross-referenced against Pinnacle 21 Community's 2204.0 XML configs and
Java source (`/Users/vignesh/projects/p21-community/`) for **concept**,
not verbatim expression -- see plan `cached-nibbling-penguin.md`.

---

## 1. SDTM-IG v3.4 key rules

### 1.1 Variable roles (Section 2.1)

Every SDTM variable has exactly one role:

| Role        | Purpose                                       | Examples                                    |
|-------------|-----------------------------------------------|---------------------------------------------|
| Identifier  | Identify study, subject, domain, sequence     | `STUDYID`, `USUBJID`, `DOMAIN`, `--SEQ`     |
| Topic       | Focus of the observation                      | `--TERM`, `--TRT`, `--TESTCD`, `--OBJ`      |
| Timing      | When the observation happened                 | `--STDTC`, `--ENDTC`, `--DTC`, `EPOCH`      |
| Qualifier   | Additional info (see subclasses below)        | `--CAT`, `--ORRES`, `--DOSU`                |
| Rule        | Trial-design flow control                     | TS, TA variables                            |

Qualifier subclasses: **Grouping** (`--CAT`, `--SCAT`), **Result**
(`--ORRES`, `--STRESC`, `--STRESN`), **Synonym** (`--DECOD`,
`--LOINC`), **Record** (`--REASND`, `AGE`, `SEX`, `--BLFL`),
**Variable** (`--ORRESU`, `--DOSU`).

### 1.2 Three general observation classes (Section 2.3)

| Class         | Topic variable | Representative domains                                |
|---------------|----------------|-------------------------------------------------------|
| Interventions | `--TRT`        | CM, EX, SU, EC, PR, DX, AG, ML                        |
| Events        | `--TERM`       | AE, MH, DS, DV, CE, HO, DE, APAE, APMH                |
| Findings      | `--TESTCD`     | LB, VS, EG, QS, PC, PE, SC, ~30 domains               |
| Findings About| `--OBJ`        | FA, SR                                                |

Custom domains built on these three use the same topic variable.

### 1.3 Non-class datasets (Section 2.4)

- **Special Purpose**: DM, CO, SV, SE, DI, DR, APDM (subject-level,
  different structure per domain)
- **Trial Design**: TA, TE, TI, TM, TS, TV, TD (trial metadata, no
  subject records)
- **Relationship**: SUPP-- (prefix for parent domain), RELREC
- **Study Reference**: DI (devices), OI (non-host organisms, SDTM 3.3+)

### 1.4 `--` prefix convention (Section 2.2 & 4.2.2)

- Two-character domain code stored in `DOMAIN` variable.
- Dataset name = domain code lowercased `.xpt` (e.g. `ae.xpt`).
- Most variable names prefix the domain code: AE has `AETERM`, not
  `TERM`. LB has `LBTESTCD`, not `TESTCD`.
- `--` in SDTM/IG means "this 2-char domain prefix goes here" at
  specification time.
- Exceptions that are NOT prefixed:
  - Required identifiers: `STUDYID`, `DOMAIN`, `USUBJID`
  - Grouping/merge keys: `VISIT`, `VISITNUM`, `VISITDY`
  - DM domain variables (except `DMDTC`, `DMDY`)
  - RELREC, SUPPQUAL, some CO and Trial Design variables.

### 1.5 Core designations (Section 4.1.5)

| Core | Meaning                                                          |
|------|------------------------------------------------------------------|
| Req  | **Required** -- column always present, never null                |
| Exp  | **Expected** -- column always present as a column, may be null   |
| Perm | **Permissible** -- include only when the study has the data item |

This is the scope used by P21's `<val:Required>` rules and maps to
herald predicate patterns:
- Req: `{all: [exists(col), non_empty(col)]}`
- Exp: `{all: [exists(col)]}`
- Perm: not enforced by any rule (conditional on data existence)

### 1.6 Dataset splitting (Section 4.1.7)

- Split on `--CAT` (or `--OBJ` for FA).
- Split dataset names up to 4 chars (QS -> QSCG, QSPI, QSSW; FA ->
  FACM, FAAE, FAEX).
- `DOMAIN` value stays the 2-char parent (split dataset names differ
  but `DOMAIN = "QS"` across all).
- `--SEQ` must be unique per `USUBJID` across all splits.
- Supplemental Qualifier follows parent: `SUPPQSCG`, `SUPPFACM`.

### 1.7 Naming constraints (Section 4.2.1)

- Variable names: A-Z first char, then A-Z / 0-9 / `_`, max 8 chars
  (SAS v5 xpt limit).
- `--TESTCD` values: max 8 chars, no leading digit, no non-alnum
  except `_`.
- `ARMCD` / `ACTARMCD`: max 20 chars (for crossover trial codes).
- Variable labels: max 40 chars, title case.

### 1.8 Missing values (Section 4.2.5)

Missing values represented by nulls (empty string for character,
`NA` for numeric). `--STAT` = "NOT DONE" plus `--REASND` explains
why a record exists without a value.

### 1.9 Text case (Section 4.2.4)

Text data in UPPERCASE by convention (`NEGATIVE`, `NOT DONE`).
Exceptions: `--TEST` values (may be title case as display labels),
long free-text, controlled-terminology values (per codelist case).

### 1.10 ISO 8601 dates (Section 4.4)

- `--DTC`, `--STDTC`, `--ENDTC`: ISO 8601 date/time or interval
  (`YYYY-MM-DD` / `YYYY-MM-DDThh:mm:ss`).
- Partial dates use hyphens: `2003---15` = 15th of some month 2003.
- `--DUR`: ISO 8601 duration (`P5D`, `PT24H`, `P2Y3M`).

### 1.11 Restricted variables (Section 2.7)

Not allowed in human-clinical SDTM (SEND-only or undefined):
`FETUSID`, `RPHASE`, `RPPLDY`, `RPPLSTDY`, `RPPLENDY`, `--NOMDY`,
`--NOMLBL`, `--RPDY`, `--RPSTDY`, `--RPENDY`, `--DETECT`,
`--USCHFL`, `--METHOD` (Interventions context), `--RSTIND`,
`--RSTMOD`, `--IMPLBL`, `--RESLOC`, `--DTHREL`, `--EXCLFL`,
`--REASEX`.

DM variables not for human use: `SPECIES`, `STRAIN`, `SBSTRAIN`,
`RPATHCD`.

---

## 2. ADaM-IG v1.3 key rules

### 2.1 ADaM data structures (Section 2.3)

| Class of Dataset                 | SubClass (optional) | Canonical Name |
|----------------------------------|---------------------|-----------------|
| SUBJECT LEVEL ANALYSIS DATASET   | --                  | ADSL            |
| BASIC DATA STRUCTURE             | --                  | (ADVS, ADLB, ADQS, ADxx ...) |
| BASIC DATA STRUCTURE             | TIME-TO-EVENT       | ADTTE           |
| OCCURRENCE DATA STRUCTURE        | --                  | ADAE, OCCDS     |
| ADAM OTHER                       | --                  | ADXX (custom)   |

**Important**: ADaM DOES use `SubClass` -- the TTE (time-to-event)
datasets declare `SubClass = TIME-TO-EVENT` while staying in the BDS
class. My earlier scan of P21's XML missed this because it only
surfaced the Class attribute; the SubClass is in CDISC's ADaMIG
section 2.3.2.

### 2.2 BDS topic variables

A Basic Data Structure dataset has these signature columns:
- `PARAMCD`, `PARAM` -- parameter code + label (the "what")
- `AVAL` (numeric) and/or `AVALC` (character) -- the analysis value
- `ABLFL` -- baseline flag (Y/null)
- Timing via `AVISIT` / `AVISITN` / `ATPT` / `ATPTN` / `ADT`, etc.

P21's ADaM prototype (ADaM-IG 1.1 FDA XML line 7758):
- BDS: requires any of `PARAMCD, PARAM, AVAL, AVALC`
- OCCDS: `AD*` name AND `--TRT` or `--TERM` AND no `PARAMCD`
- ADaM Other: `AD*` catch-all

(Ported to herald's `R/class-detect.R::.PROTOTYPES`.)

### 2.3 Indexed variable naming

ADaM variables use integer placeholders for multi-instance slots:

| Placeholder | Range               | Example uses                          |
|-------------|---------------------|---------------------------------------|
| `xx`        | 01..99 zero-padded  | `TRTxxPN`, `APERIODxx`, `R2AxxN`      |
| `y`         | 1..9 single digit   | `TRTPGy`, `RANDy`, `TRCMPGy`          |
| `zz`        | 01..99 zero-padded  | Secondary slot (e.g. `TR01PGzz`)      |

In a rule, every occurrence of the placeholder within a single check
refers to the SAME concrete value at evaluation time. See
`R/index-expand.R` for herald's expansion support and the
`expand: xx|y|zz` YAML key.

**Resolved messages on fire.** When an indexed rule fires on a
concrete instance, herald renders the rule's `outcome.message`
with the placeholder substituted by the instance's value. A rule
whose message template is

    TRTxxAN is present and TRTxxA is not present

emits findings like

    TRT01AN is present and TRT01A is not present

so reviewers see the exact variable names that tripped the rule.
One finding is emitted per violating instance (TRT01 and TRT04
violating independently produce two findings). Advisories from
an indexed rule with no matching columns in the dataset retain the
template, because there's no concrete value to substitute.

### 2.4 `*FL` / `*FN` variable families (Section 3.2 + rules AD0005+)

- `*FL` (flag): values **Y / N / null**
- `*FN` (flag numeric): values **1 / 0 / null**
- Population flags MUST NOT be null: `COMPLFL`/FN, `FASFL`/FN,
  `ITTFL`/FN, `PPROTFL`/FN, `SAFFL`/FN, `RANDFL`/FN, `ENRLFL`/FN.
- `*RFL` / `*RFN` (record-level flag): values **Y / null** and
  **1 / null** respectively.
- `*PFL` / `*PFN` (parameter-level): same Y/null, 1/null constraint.
- Pairs must be consistent: when `XFL = 'Y'`, `XFN = 1`;
  when `XFL = 'N'`, `XFN = 0`.

### 2.5 Date/time format families (Section 3.3)

- `*DT` (date): numeric SAS date, valid formats include `B8601DA`,
  `DATE9`, `DDMMYY`, `YYMMDD`, ...
- `*TM` (time): numeric SAS time, formats `B8601TM`, `HHMM`, `TIME`, ...
- `*DTM` (datetime): numeric SAS datetime, formats `B8601DT`,
  `DATETIME`, ...
- `*DY` (study day): integer, **never zero** (CDISC has no study
  day 0).

These appear directly in ADaM-IG rules as "*DT has wrong format",
"*DY = 0" etc.

---

## 3. Mapping conventions to herald patterns

This table guides which herald operators to reach for when you see a
given CDISC phrase. Not exhaustive -- extend as new patterns emerge.

| CDISC phrase / rule shape                                  | herald pattern              | key ops                      |
|------------------------------------------------------------|-----------------------------|------------------------------|
| "X is present and Y is not present" (metadata)             | `presence-pair`             | `exists`, `not_exists`       |
| "X not present in dataset" (metadata)                      | `presence-required`         | `not_exists`                 |
| "X is populated" / "X is not null"                         | `value-not-null`            | `empty` (inverted semantic)  |
| "X = null"                                                 | `value-is-null`             | `non_empty` (inverted)       |
| "on a given record X is populated and Y is not populated"  | `value-conditional-populated`| `{all: [non_empty, empty]}`  |
| "X in (A, B, C)"                                           | `value-in-set`              | `is_not_contained_by`        |
| "X not in (...)"                                           | `value-not-in-set`          | `is_contained_by`            |
| "X = Y" (both are variables)                               | `value-cross-var-equal`     | `not_equal_to` (value_is_literal=FALSE) |
| "X = DS.COL" (dotted cross-dataset ref)                    | `cross-join-by-key`         | `differs_by_key`             |
| "label length > 40 / variable name > 8"                    | `metadata-length-le`        | `length_le` on LABEL/VARIABLE |
| "variable name does not match regex"                       | `regex-varname`             | `matches_regex`              |
| "*DT variable does not have SAS Date format"               | `metadata-format-is`        | `is_contained_by` on FORMAT  |
| "(STUDYID, USUBJID, --TESTCD) duplicate"                   | `uniqueness-grouped`        | `is_not_unique_set` + GroupBy|
| "ADSL dataset does not exist"                              | `dataset-ref-required`      | `not_exists` on dataset name |
| "XxxN present, Xxx not present" (indexed)                  | `presence-pair` + `expand`  | `exists`+`not_exists` + `expand: xx|y` |

When you encounter a rule whose shape doesn't map to one of these,
pick a new pattern name using the kebab-case vocabulary in the plan
file and document it under `patterns/<new-pattern>.md`.

---

## 4. P21 edge cases we mirror (source-code audit)

Structural quirks in Pinnacle 21's rule execution that a naive R
implementation would silently get wrong. herald mirrors the CDISC
intent (not P21's expression) but respects the same semantics:

| P21 behaviour | File:line | herald decision |
|---|---|---|
| **Right-trim null** -- "   " treated as null; leading whitespace preserved | `DataEntryFactory.java:313-328` | `op_empty`/`op_non_empty` use `sub("\\s+$","",x)` before `nzchar`. Numeric zero + "NA" / "null" literals are populated. |
| **Regex full-match** -- `matcher.matches()` (anchored), case-sensitive by default | `RegularExpressionValidationRule.java:71` | `.anchor_regex()` wraps unanchored patterns in `^(?:...)$`. Explicit `^...$` from rule authors passes through. |
| **Case-insensitive compare uses JVM locale** | `Comparison.java:178-181` | herald's `tolower()` uses R's default locale. CDISC data is generally ASCII English; revisit if non-English strings surface. |
| **Fuzzy date prefix match** -- "2024" equals "2024-01-15" by prefix | `DataEntryFactory.compareToAny:172-180` | herald parses dates before comparison (`.parse_sdtm_dt()`); no fuzzy prefix match. herald is STRICTER than P21 here; preferred. |
| **`val:Required` column-absent -> disable rule** (no findings) | `AbstractValidationRule.java:148-161` | herald's `op_empty`/`op_non_empty` return NA on missing column -> one advisory per (rule x dataset) rather than silent skip. herald is MORE TRANSPARENT. |
| **`SUPP--` wildcard domain** | `ConfigurationManager.prepare` | `.rule_scope_matches_ctx` accepts SUPP-- against any `SUPP`-prefixed dataset; class filter skipped in that branch to avoid SPC-vs-RELATIONSHIP false reject. |
| **Metadata virtual dataset -- LABEL rtrim + null skip** -- `Target="Metadata"` rules project variables as rows with a LABEL column; the factory rtrims trailing spaces and all-spaces labels become null. Regex Metadata rules skip records where the label has no value (`entry.hasValue() == false`). | `Metadata.java:30-39,178` + `DataEntryFactory.java:313-328` + `RegularExpressionValidationRule.java:62` | `op_label_by_suffix_missing` rtrims the label via `sub(" +$","",lbl)`, then `next`s when the trimmed label is empty -- never fires on a missing label. Missing-label quality is a separate concern (e.g. AD0016-style length rule). Variable-name suffix match is UPPERCASE on both sides, mirroring `Metadata.add` uppercasing of every variable name (line 138, 163, 185). |
| **Multi-placeholder variable templates** -- each `#`/`@`/`_`/`*` wildcard in a variable name pattern compiles to a separate regex capture group; `matcher.matches()` iterates the variable list and records the tuple of captured values per variable. | `MagicVariable.java:198-223` + `MagicVariable.java:104-147` | `.expand_indexed()` accepts a comma-separated `expand:` slot (`xx,y` or `stem,y`). One regex per template with each placeholder as an ordered capture group (`^TR([0-9]{2})PG([1-9])N$`), `regexec()` over `names(data)`, each matching column contributes a (ph1=v1, ph2=v2) tuple. Cartesian product across templates; one instance per tuple wrapped under `{any}`. `stem` placeholder (`[A-Z][A-Z0-9]+`) is herald's analogue of P21's `@*` / `_*` variable-name prefix wildcard. |

P21 implementation details we do **not** mirror:

- `FindValidationRule` counter-inversion for Terms lists
  (`FindValidationRule.java:234-243`): herald's `is_contained_by`
  evaluates directly; no dual counter.
- `MatchValidationRule` paired-variable silent-pass when the first
  var isn't in `Terms` (`MatchValidationRule.java:131`): P21 bug; we
  treat the leaf as NA -> advisory, not silent pass.
- `Expression.evaluate` non-standard OR/AND precedence fallback
  (`Expression.java:259-283`): herald uses explicit `{all}/{any}`
  combinators; no ambiguity.
- `val:Unique` single-row + no-`GroupBy` creates per-value groupings
  that never trip: herald's `op_is_unique_set` uses `duplicated()`
  directly; no hidden grouping.

## 5. Clean-room notice

The conventions above are extracted from the CDISC IG PDFs (CC-BY
license) and from structural observation of P21's XML/Java source.
Rule **expressions** and implementation details from P21 must not be
copied into herald (per P21's source-available license). herald's
operator set and check_tree authoring are independent implementations
of the CDISC-defined semantics.
