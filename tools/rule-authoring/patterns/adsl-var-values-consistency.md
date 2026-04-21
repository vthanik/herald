# adsl-var-values-consistency

## Intent

*"A variable is present with the same name as a variable present in
ADSL but the variables do not have identical values for a given
value of USUBJID"*. Per-row: fires on every row whose value in a
shared column differs from the matching ADSL row's value joined by
USUBJID. Auto-walks every shared column; a row fires if ANY shared
column mismatches.

Sibling of `adsl-var-attr-consistency` (labels / formats / types)
but row-level instead of metadata-level.

Canonical message form:
`A variable is present with the same name as a variable present in
ADSL but the variables do not have identical values for a given
value of USUBJID`

## CDISC source

ADaMIG v1.2 Section 2.3.1: a variable that is present in both ADSL
and any other ADaM dataset must have the same values (and type and
label; the attr checks live in the sibling pattern).

- ADaM-591 (values per USUBJID mismatch)

## P21 conceptual parallel (reference only)

P21 uses `val:Match Variable=%Variable% Target=Data Role="Subject
Key"` which joins on USUBJID at the record level. herald's op
iterates `intersect(names(data), names(ADSL))` server-side and
compares.

## P21 edge-case audit

Value-equality semantics track P21's `DataEntryFactory.compareToAny()`
via the shared `.cdisc_value_equal()` helper in `ops-cross.R`.

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Case-sensitive `==` default | `Comparison.java:195` | string compare is case-sensitive. Matches. |
| rtrim trailing SPACE on key | `DataEntryFactory.java:313-328` | key rtrim via `sub(" +$","",...)`. Matches. |
| Both sides NULL -> equal (no fire) | `NullDataEntry.compareToAny:355-356` | `.cdisc_value_equal` returns TRUE for (NA, NA). Matches. |
| One side NULL -> not equal (fire) | same | returns FALSE when one NA. Matches. |
| Both sides numeric -> BigDecimal equality | `DataEntryFactory.java:159-160` | numeric fallback compares with `==`. Matches. |
| Both sides datetime -> prefix equality | `DataEntryFactory.java:172-180` | regex match on CDISC ISO partial-date pattern + `startsWith` both ways. Matches. |
| 4-digit integer treated as year | `DataEntryFactory.java:173,175` | 4-digit no-decimal numeric is flagged as date. Matches. |
| Subject not in ADSL -> Lookup no-match -> rule-disable | `LookupValidationRule` | row NA from `subj_in_ref`; row contributes no comparison, returns NA -> advisory. Matches. |
| Duplicate ADSL USUBJID -> first-match | `lut[!duplicated(...)]` | herald keeps first row by USUBJID (ADSL is 1-per-subject by contract); `ctx$dup_subjects` pre-scan surfaces duplicates as a separate finding. Matches. |
| Key columns excluded from compare | n/a (P21 uses ItemRef Role) | herald excludes `key` + `reference_key` automatically; authors may add more via the `exclude` slot. More explicit. |

## herald check_tree template

```yaml check_tree
operator: shared_values_mismatch_by_key
reference_dataset: %ref_ds%
key: %key%
```

Slots:
- `ref_ds` -- reference dataset (typically `ADSL`).
- `key`    -- subject key column (typically `USUBJID`).

Optional slots:
- `reference_key` -- override when the key has a different name in
  the reference dataset.
- `exclude`       -- list of columns to skip in the compare.

## Expected outcome

- Positive: at least one shared column has a different value for a
  given subject -> row fires.
- Negative: every shared column matches for that subject -> no fire.
- No successful comparison for a row (subject not in reference, or
  both sides NA for every shared column) -> NA -> advisory per
  (rule x dataset).

## Batch scope

1 rule: ADaM-591 (values per USUBJID mismatch).
