# adsl-dm-consistency

## Intent

For each ADSL subject, the value of a key demographic variable
must equal the corresponding variable in DM for the same USUBJID.
Fires when ADSL.VAR != DM.VAR for the same USUBJID.

Canonical message form (from YAML outcome.message):
`ADSL.USUBJID = DM.USUBJID and ADSL.VAR != DM.VAR`

The check joins ADSL to DM on USUBJID and fires per subject row
where the variable values disagree. Rules: ADaM-204 (AGE),
ADaM-205 (AGEU), ADaM-206 (SEX), ADaM-207 (RACE), ADaM-208
(SUBJID), ADaM-209 (SITEID), ADaM-210 (ARM), ADaM-367 (ACTARM).

## CDISC source

CDISC ADaM Conformance Rules v5.0, ADaMIG v1.0 Section 3.1
Table 3.1.1 and ADaMIG v1.1 Section 3.2 Table 3.2.4. These rules
assert that specific ADSL variables must be identical copies of
their DM counterparts when the variable is a direct copy (as
opposed to a renamed or derived version).

## P21 conceptual parallel (reference only)

P21's `CrossDatasetValidationRule` iterates subjects in ADSL and
performs a DM lookup by USUBJID, comparing the designated field.
herald uses `op_differs_by_key` which performs the same equi-join
via a lookup table (LUT) built from DM.USUBJID -> DM.VAR, then
compares against the ADSL row value. Both emit one finding per
mismatching subject row.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| Subject in ADSL but not in DM -> finding | `op_differs_by_key` returns NA (advisory) when key is absent from LUT; matches P21 advisory. |
| Both values are NA -> pass (not a mismatch) | `op_differs_by_key` returns NA when either side is NA; consistent with P21. |
| Numeric normalization (e.g. 65.0 vs 65) | `.cdisc_value_equal` canonicalisation inside `op_differs_by_key` handles numeric + date + POSIXct. |
| DM missing from submission -> skip rule | `.ref_ds()` returns NULL; op returns NA mask; surfaces as advisory in `result$skipped_refs`. |

## herald check_tree template

```yaml check_tree
all:
- operator: differs_by_key
  name: %var%
  reference_dataset: %ref_dataset%
  reference_column: %ref_column%
  key: %key%
```

Slots:
- `var`          -- the ADSL variable to check (e.g. `AGE`)
- `ref_dataset`  -- reference dataset; always `DM` for this pattern
- `ref_column`   -- the DM column; always the same name as `var`
- `key`          -- join key; always `USUBJID` for this pattern

TRUE (differs_by_key fires) = ADSL.var != DM.var for that subject
= violation.

## Expected outcome

- Positive fixture: one ADSL subject row whose AGE differs from
  DM.AGE for the same USUBJID -> fires on that row.
- Negative fixture: all ADSL subject rows have AGE matching
  DM.AGE for each USUBJID -> no fires.
- DM absent from submission: NA advisory.
- ADSL subject missing from DM: NA advisory per row.
- `provenance.executability` -> `predicate`.

## Batch scope

8 rules in the ADSL scope class (SUBJECT LEVEL ANALYSIS DATASET):
ADaM-204 (AGE), ADaM-205 (AGEU), ADaM-206 (SEX), ADaM-207
(RACE), ADaM-208 (SUBJID), ADaM-209 (SITEID), ADaM-210 (ARM),
ADaM-367 (ACTARM).
