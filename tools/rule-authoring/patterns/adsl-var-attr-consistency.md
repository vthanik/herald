# adsl-var-attr-consistency

## Intent

*"A variable is present with the same name as a variable present in
ADSL but the variables do not have identical `<ATTRIBUTE>`"*. Fires
once per (rule x dataset) when at least one column shared with ADSL
carries a different `<ATTRIBUTE>` (label / format / type / length).

Scope: every ADaM analysis dataset that shares columns with ADSL.
Comparing ADSL against itself is a no-op (identity compare), so
running with `classes: ALL` is safe.

Canonical message form:
`A variable is present with the same name as a variable present in
ADSL but the variables do not have identical <ATTRIBUTE>`

## CDISC source

ADaMIG v1.0 Section 3.2 + 3.1. ADSL-origin variables copied into BDS
/ OCCDS datasets to support traceability must preserve their ADSL
definitions. Covers:

- ADaM-85  (labels mismatch)
- ADaM-86  (formats mismatch)
- ADaM-590 (data types mismatch)

Covering ADaM-591 (value mismatch per USUBJID) uses a separate op
(`shared_values_mismatch_by_key`) authored in a sibling pattern.

## P21 conceptual parallel (reference only)

P21 expresses each attribute via `val:Match` against the
`%Variable.Define.Label%` / `%Variable.Define.DataType%` /
`%Variable.Define.DisplayFormat%` magic-variable families, one rule
per attribute (MagicVariableParser.java). herald collapses the
iteration into a single op that walks `intersect(names(data),
names(ADSL))` and fires on the first mismatch.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Attribute absent in Define-XML -> rule-disable | `MagicVariable.isMissing` | herald's op returns NA when `attr(col, key)` is NULL on either side. NA -> advisory. More transparent. |
| Case-sensitive attribute compare | `MatchValidationRule.equals` | `identical()` is case-sensitive. Matches. |
| Reference dataset absent -> rule-disable | `DataEntryFactory.lookupDataset` | herald returns NA mask for the rule -> advisory. Matches. |
| Column missing on one side only -> no fire | n/a (Define-XML guarantees alignment) | herald's `intersect()` only compares shared columns. Consistent. |

## herald check_tree template

```yaml check_tree
operator: shared_attr_mismatch
attribute: %attribute%
reference_dataset: ADSL
```

Slots:
- `attribute` -- one of `label`, `format`, `type`, `length`

## Expected outcome

- Positive: at least one shared column has a different `<attribute>`
  on current vs ADSL -> fires once.
- Negative: every shared column matches -> no fire.
- No shared columns OR ADSL absent OR missing attr on either side
  for every shared column -> advisory.

## Batch scope

3 rules: ADaM-85 (label), ADaM-86 (format), ADaM-590 (type).
