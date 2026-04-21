# value-compare-subject-ordinal

## Intent

*"The record's date (or value) must be `<`/`<=`/`>`/`>=` the subject's
reference value from DM"*. Mirrors P21's `SUB:` subject-level
comparison (`SUB:RFICDTC @lteq %Domain%STDTC`). Violation = the
ordinal relation does NOT hold on that record.

Canonical message forms:
 - `<ROW_VAR> >= DM.<REF_COL>`   -> violation: row < ref
 - `<ROW_VAR> < DM.<REF_COL>`    -> violation: row >= ref
 - etc.

## CDISC source

SDTMIG v3.2+ subject-level consistency: record dates must fall
within the study period anchored by `DM.RFICDTC`, `DM.RFSTDTC`,
`DM.RFENDTC`, or `DM.DTHDTC` (CG0068, 0069, 0075, 0079, 0147, 0148,
0171). Each rule pairs a record date (e.g. `--STDTC`, `SSDTC`,
`EXENDTC`) with a subject-level anchor and asserts an ordinal
relation.

## P21 conceptual parallel (reference only)

P21's DSL uses `SUB:VAR` for subject-level DM variables:

```
val:Condition ID=SD... PublisherID="CG0068"
  Test="SUB:RFICDTC @lteq %Domain%STDTC"
  When="SUB:RFICDTC !='' @and %Domain%STDTC !=''"
```

`SUB:` is P21 shorthand: the validator looks up the current record's
USUBJID in DM and returns that subject's single RFICDTC value.
Herald expresses the same concept explicitly via
`reference_dataset=DM` + `reference_column=RFICDTC` + `key=USUBJID`
on the new `*_by_key` ordinal ops.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `@lteq` / `@gteq` / `@lt` / `@gt` evaluate via `compareToAny(rhs, true)` -- type-aware | `Comparison.java:160-207` | `.cmp_by_key` attempts numeric coerce if both sides parse clean; else lexicographic string compare. ISO 8601 dates sort correctly as strings. Matches. |
| rtrim-null on both sides before compare | `DataEntryFactory.java:313-328` | `.cmp_by_key` rtrims via `sub("\\s+$","",v)` on both row and ref values before comparison. Matches. |
| Null lhs or rhs -> `NullComparison` -> compare returns -1 -> ordinal evaluates | `DataEntryFactory.java:349-357` | NA on either side -> mask NA -> advisory (not fire). **Deviation:** P21 might fire on null-vs-populated for `@gt` style; herald advisory is safer for date comparisons. |
| Fuzzy date prefix match when both sides look date-like (`'2024-01' startsWith '2024'` = equal) | `DataEntryFactory.java:172-180` | Not applied in `.cmp_by_key`. **Documented deviation** -- strict lexicographic compare is more predictable. |
| Subject without a DM row -> lookup fails | `LookupValidationRule` -> CorruptRuleException or skip | `.cmp_by_key` returns NA for rows whose key isn't in the LUT -> advisory. More transparent than P21's skip. |
| Multi-row DM for same USUBJID (shouldn't happen per CDISC) | P21's Lookup picks first | `.cmp_by_key` also picks first (`lut[!duplicated(names(lut))]`). Same. |

## herald check_tree template

```yaml check_tree
all:
- operator: non_empty
  name: %row_var%
- operator: %cmp_op%
  name: %row_var%
  reference_dataset: %ref_ds%
  reference_column: %ref_col%
  key: USUBJID
```

Slots:
- `row_var`  -- the row-level date/value column
- `cmp_op`   -- one of `less_than_by_key`, `less_than_or_equal_by_key`,
  `greater_than_by_key`, `greater_than_or_equal_by_key`. The op NAME
  describes the violation condition (fires when row `<op>` ref).
- `ref_ds`   -- reference dataset (usually `DM`)
- `ref_col`  -- reference column in that dataset

The first `non_empty(row_var)` leaf is a guard so we skip rows where
the row-date is missing entirely; otherwise the ordinal op would
advisory on every null row and inflate findings.

## Expected outcome

- Positive: row has date populated AND the ordinal relation describes
  a violation (e.g. row is before the subject's enrolment anchor) ->
  fires on that row.
- Negative: row date populated, relation holds OR row date missing
  (guard blocks) -> no fire.

## Batch scope

Initial batch (11 rules): CG0068 (DSSTDTC < RFICDTC),
CG0069 (DSSTDTC != DTHDTC for DEATH records -- extended form),
CG0075 (DVSTDTC < RFICDTC), CG0079 (MHSTDTC > RFSTDTC -- past
medical history should precede study start), CG0147 (EXENDTC
later than RFXENDTC), CG0148 (EXSTDTC before RFXSTDTC),
CG0171 (SSDTC before DTHDTC), and ADaM-IG equivalents.

**This pattern as shipped** covers the SIMPLE 2-leaf ordinal
comparisons. Rules with additional filters (e.g. CG0069's
`DSDECOD @eqic 'DEATH'` condition) need a 3-leaf template with
an is_contained_by guard; authored as separate .ids entries or
future sibling patterns.
