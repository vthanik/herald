# value-var-name-in-ref-dataset

## Intent

*"The value in `<NAME>` must be a variable that exists in
`<REFERENCE_DATASET>`"*, optionally restricted to variables whose
name matches a suffix pattern (e.g. `(DT|DTC|DTM)` for date
variables). Fires per record when the cell's value isn't a column
in the reference dataset, or is a column but doesn't fit the
required suffix.

Canonical message form:
`<NAME> = date variable name in <REF_DS>` /
`<NAME> references a variable not found in <REF_DS>`

## CDISC source

SDTMIG v3.2+ Section 7.3 + SDTM Model Section 3.5.1. CG0375 is the
canonical case: `TDANCVAR` must be the name of a date variable in
ADSL that serves as the anchor date for disease assessment
scheduling.

## P21 conceptual parallel (reference only)

P21's SDTM-IG 3.3 config does NOT encode CG0375 explicitly -- only
the `<ItemDef OID="IT.TD.TDANCVAR">` metadata definition exists
(line 43299). herald authors this pattern from the CDISC narrative
directly, using a new op that mirrors the P21 pattern for
cross-dataset variable existence:

```
val:Lookup Variable="USUBJID == USUBJID, %VALUE% == <target_col>"
  From="<ref>"
```

but projected against the ref dataset's **column list** rather than
a specific column. The op iterates `names(ref_dataset)` and checks
for membership, optionally filtering by a suffix regex.

## P21 edge-case audit (general Lookup conventions)

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Variable name lookup UPPERCASED | `Metadata.java:138,163,185` | herald uppercases both `values` and `names(ref_ds)` before comparison. Matches. |
| rtrim trailing spaces on ref-column values | `DataEntryFactory.java:313-328` | `sub("\\s+$","",values)` before membership test. Matches. |
| Null reference dataset -> Lookup skipped | `LookupValidationRule` | `.ref_ds` returns NULL on missing dataset -> op returns NA mask -> advisory. Matches. |
| Null cell on current dataset -> P21 skips | `hasValue() == false` | herald returns NA on empty cells -> advisory, not fire. Matches. |
| Case-sensitive default on the suffix match | `Pattern.compile` default | `grepl(perl = TRUE)` default is case-sensitive; pattern compares against UPPER-case values so `(DT|DTC|DTM)` matches case-exactly. |

## herald check_tree template

```yaml check_tree
operator: value_not_var_in_ref_dataset
name: %var%
reference_dataset: %ref_ds%
name_suffix: %suffix%
```

Slots:
- `var`        -- column holding the variable-name value to check
- `ref_ds`     -- reference dataset (e.g. `ADSL`)
- `suffix`     -- optional regex suffix (e.g. `(DT|DTC|DTM)`)

## Expected outcome

- Positive: record where `<var>` holds a value that isn't in
  `<ref_ds>`'s column list, OR is in the list but doesn't match
  the suffix -> fires.
- Negative: `<var>` value is a valid column name in `<ref_ds>` AND
  matches the suffix -> no fire.
- Null `<var>` -> NA -> advisory (no false fire).

## Batch scope

1 rule: CG0375 (TDANCVAR must be a date variable in ADSL).
