# value-cross-dataset-not-in-cond-in-set

## Intent

*"When `<VAR>` is not found in `<REF_DS>.<REF_COL>`, `<VAR>` must be in a
controlled sentinel set of literals"*. Cross-dataset negative-membership guard:
the value in the current row's `<VAR>` is looked up against the full column of
`<REF_COL>` values in `<REF_DS>`. When the value is absent from that reference
column, the rule asserts it must instead be one of the explicitly-listed
sentinel strings. Fires when the guard is satisfied (not in ref) AND the value
is also not in the sentinel set.

Canonical condition: `<VAR> not in <REF_DS>.<REF_COL>`
Canonical assertion: `<VAR> in (<SENTINELS>)`

## CDISC source

SDTMIG v3.2 Demographics domain treatment-arm sentinel rules. Subjects not
assigned to a planned trial arm (not in TA.ARM / TA.ARMCD) must record one of
the defined sentinel values (e.g., 'Screen Failure', 'Not Assigned', 'Not
Treated', 'Unplanned Treatment') to distinguish their off-schedule status from
a data error.

- CG0117: ACTARM not in TA.ARM -> ACTARM in sentinel set (4 values)
- CG0120: ARM not in TA.ARM -> ARM in sentinel set (2 values)
- CG0124: ACTARMCD not in TA.ARMCD -> ACTARMCD in sentinel set (4 values)
- CG0128: ARMCD not in TA.ARMCD -> ARMCD in sentinel set (2 values)

## P21 conceptual parallel (reference only)

P21 expresses this as a `val:Condition When="%VAR% not_in_list TA.%REF_COL%"
Test="%VAR% in_list '<sentinels>'"` (ConditionalValidationRule.java). The
`not_in_list` operator iterates all values in the TA reference column and
returns true when no value matches. herald composes the same logic using
`missing_in_ref` (guard) + `is_not_contained_by` (assertion) under an `{all}`
combinator.

## P21 edge-case audit

| P21 behaviour | Source | herald decision |
|---|---|---|
| `not_in_list` compares current row value against all rows of ref column; fires guard when none match | ConditionalValidationRule.java | `op_missing_in_ref` with `name=<VAR>`, `reference_dataset=<REF_DS>`, `reference_key=<REF_COL>` does the same: returns TRUE when VAR value is not in any TA.<REF_COL> row. Matches. |
| TA dataset absent -> guard cannot be evaluated -> rule skipped | AbstractValidationRule.java:148-161 | `op_missing_in_ref` calls `.ref_ds(ctx, "TA")` which records the missing ref in `ctx$missing_refs$datasets` and returns NA -> advisory. Matches. |
| Guard NULL / empty cell -> `hasValue() == false` -> guard short-circuits (no fire) | DataEntry.java:25 | `op_missing_in_ref` returns `!(value %in% ref_keys)`. NA/empty VAR -> value is NA, not in ref_keys -> TRUE, then guard fires. But the second leaf `is_not_contained_by` on an NA value returns NA -> advisory. Net: no definitive fire. Acceptable. |
| Case-sensitive comparison on ARM values (mixed-case sentinel strings) | FindValidationRule.java:91-96 | `%in%` in `op_missing_in_ref` is case-sensitive. TA.ARM values are stored as authored. Sentinel strings match CDISC verbatim. Matches. |
| Sentinel values contain spaces ('Screen Failure', 'Not Assigned') | P21 parses quoted tokens | herald value list accepts multi-word strings verbatim in YAML sequences. Matches. |

## herald check_tree template

```yaml check_tree
all:
- operator: missing_in_ref
  name: %var%
  reference_dataset: %ref_ds%
  reference_key: %ref_col%
- operator: is_not_contained_by
  name: %var%
  value: [%sentinels%]
```

Slots:
- `var`       -- the column in the current dataset (e.g. ACTARM)
- `ref_ds`    -- the reference dataset name (e.g. TA)
- `ref_col`   -- the column in the reference dataset to match against (e.g. ARM)
- `sentinels` -- comma-separated YAML sequence content (quoted literals);
  e.g. `'Screen Failure', 'Not Assigned', 'Not Treated', 'Unplanned Treatment'`

## Expected outcome

- Positive: VAR not in REF_DS.REF_COL AND VAR not in sentinel set -> fires.
- Negative: VAR IS in REF_DS.REF_COL (guard blocks) -> no fire.
- Negative #2: VAR not in REF_DS.REF_COL AND VAR IS in sentinel set -> no fire.
- Advisory: TA dataset missing -> both leaves return NA -> advisory.

## Batch scope

4 rules (SDTMIG v3.2, scope DM, severity Medium):
- CG0117 (ACTARM, TA.ARM, 4 sentinels)
- CG0120 (ARM, TA.ARM, 2 sentinels)
- CG0124 (ACTARMCD, TA.ARMCD, 4 sentinels)
- CG0128 (ARMCD, TA.ARMCD, 2 sentinels)
