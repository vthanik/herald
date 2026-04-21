# value-cross-dataset-eq-lit

## Intent

*"When the reference dataset has a row for this subject where
`<REF_COL>` equals `<REF_VALUE>`, the current dataset's
`<TARGET_VAR>` must equal `<TARGET_LIT>`"*. Cross-dataset existence
guard with a literal-equality assertion on the current row. Fires
when the guard-row exists but the current-row assertion fails.

Canonical message form: `<TARGET_VAR> = '<TARGET_LIT>'`
Canonical condition:    `<REF_DS>.<REF_COL> = '<REF_VALUE>'`

## CDISC source

SDTMIG v3.2+ death-indicator consistency: when one domain records
a subject's death (SS.SSSTRESC='DEAD', AE.AEOUT='FATAL',
DS.DSDECOD='DEATH', DD record present), DM.DTHFL must equal 'Y'
for the same subject. CG0132-0136 cover the same DM.DTHFL
assertion from different guard-domain directions.

## P21 conceptual parallel (reference only)

P21 uses `val:Lookup` with `Variable="USUBJID == USUBJID"` and a
`Where="<col> == 'VAL'"` clause on the reference dataset:

```
val:Lookup ID="SD..." PublisherID="CG0134"
  Variable="USUBJID == USUBJID"
  When="AEOUT == 'FATAL'"
  Where="DTHFL == 'Y'"
  From="DM"
```

Actually this P21 form uses the REVERSE direction: scope AE, guard
on AE.AEOUT, look up DM for DTHFL='Y'. herald's CDISC authoring has
scope=DM with guard-lookup in the direction the CDISC rule-id
declares: scope=DM, for each DM row, check if AE has a matching
FATAL row for this subject; if yes, DM.DTHFL must be 'Y' on this
row.

The new op `subject_has_matching_row(key, ref_ds, ref_col,
expected_value)` encodes the reverse-direction existence check used
in the guard. Paired with `not_equal_to(target, 'lit')` on the
current row, the `{all}` fires when the cross-dataset condition is
present AND the current row's target differs from the required
literal.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `val:Lookup` scopes to the "From" dataset conceptually; herald inverts by scoping the authored rule's current-dataset | `LookupValidationRule` | Direction matches the CDISC rule_id's scope declaration; no semantic difference in fire coverage. |
| `Where="<col> @eqic '<VAL>'"` case-insensitive on some (SD1347) | Comparison DSL `@eqic` | herald uses case-sensitive `==` (matches `op_subject_has_matching_row` default). CDISC CT values are uppercase-standard so case deviation is rare; document if seen. |
| Multi-row ref (e.g. subject has both ALIVE and DEAD rows in SS) | Lookup returns any matching row | `op_subject_has_matching_row` tests "any row matches" -- guard fires if at least one row satisfies. Matches. |
| Ref column null after rtrim -> does NOT match literal | `DataEntryFactory.java:313-328` | rtrim-null applied before `ref_vals == target` compare. Matches. |
| Subject without ref dataset entry -> Lookup fails / returns no match | Lookup semantic | `op_subject_has_matching_row` returns FALSE for keys not in ref -> guard blocks, no fire. Matches. |
| Missing ref dataset or columns -> `CorruptRuleException` | `AbstractValidationRule.java:148-161` | Op returns NA mask -> advisory. More transparent. |
| Null target cell compared to 'Y' | Our recent NullComparison-parity fix to `op_equal_to` | `not_equal_to(null, 'Y')` returns TRUE -> fires, matching P21's NullDataEntry.compareTo behaviour. |

## herald check_tree template

```yaml check_tree
all:
- operator: subject_has_matching_row
  name: USUBJID
  reference_dataset: %ref_ds%
  reference_column: %ref_col%
  expected_value: '%ref_value%'
- operator: not_equal_to
  name: %target_var%
  value: '%target_lit%'
```

## Expected outcome

- Positive: DM row has DTHFL != 'Y' AND SS has a DEAD record for
  same subject -> fires.
- Negative: DM row has DTHFL == 'Y' (compliant) OR SS has no DEAD
  record for subject (guard blocks) -> no fire.

## Batch scope

2 rules (initial): CG0132 (DTHFL=Y when SS.SSSTRESC=DEAD),
CG0134 (DTHFL=Y when AE.AEOUT=FATAL).

Deferred: CG0133 (DD record present -- "record present" is existence
only, no column-value filter), CG0135 (AE.AESDTH = 'Y'), CG0136
(DS.DSDECOD = 'DEATH'). Same shape; can extend .ids as the engine
supports each.
