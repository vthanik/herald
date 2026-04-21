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

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Case-sensitive compare default | `String.equals` | row compare uses `!=` on rtrimmed strings. Matches. |
| rtrim trailing spaces both sides | `DataEntryFactory:313-328` | `sub("\\s+$","",...)` both sides. Matches. |
| Missing USUBJID in ADSL -> rule-disable | `Lookup` miss | herald sets that row's comparison to NA; rows with no successful comparison return NA -> advisory. |
| Duplicate ADSL USUBJID -> first-match | `lut[!duplicated(...)]` | herald keeps first row by USUBJID (ADSL is 1-per-subject by contract); the separate dup_subjects pre-scan surfaces duplicates as their own finding. |
| Key columns excluded from compare | n/a (P21 uses ItemRef Role) | herald excludes `key` + `reference_key` automatically; authors may add further columns via the `exclude` slot. |

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
