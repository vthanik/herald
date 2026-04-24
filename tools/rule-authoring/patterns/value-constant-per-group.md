# value-constant-per-group

## Intent

*"Within a given value of `<OUTER_KEY>`, there is more than one value of
`<VAR>`"* with no secondary grouping variable. The column must be constant
(single distinct non-NA value) across all rows that share the same outer key.
Fires every row in a violating group.

Canonical message form:
`Within a given value of <OUTER>, there is more than one value of <VAR>`
`Within a given value of <OUTER>, <VAR> is populated for at least one record
and is not populated for at least one record`

## CDISC source

ADaMIG Q10 single-variable cardinality rules:
- ADaM-151: CRITy must have the same definition (value) across all rows for a
  given PARAMCD. ADaMIG v1.0 Section 4.7.1.
- ADaM-131: BASETYPE must be consistently populated or absent within each
  PARAMCD. ADaMIG v1.0 Section 3.2.4.
- ADaM-735: Same as ADaM-131 but applies only to rows where BASE or BASEC is
  populated; covers both BDS and MDBDS classes. ADaMIG v1.3.

## P21 conceptual parallel (reference only)

P21 expresses these with `val:Unique` and a single-column `GroupBy`. herald
uses the new `op_is_not_constant_per_group` op which fires all rows in any
group with >1 distinct non-NA value of the target column.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| Fires only 2nd+ duplicate (Matching=Yes) | herald fires ALL rows in violating group. Documented deviation. |
| All-NA group is not flagged | op excludes NA from distinct-value count; group with only NAs -> FALSE. |

## herald check_tree template

```yaml check_tree
operator: is_not_constant_per_group
name: %var%
group_by:
- %group_by%
```

## Expected outcome

- Positive fixture: PARAMCD='HR' with two rows having different CRITy values ->
  both rows fire.
- Negative fixture: all rows with PARAMCD='HR' have the same CRITy value -> no
  fires.
- Rows with NA in `name` are excluded from the count (all-NA group: no fire).

## Batch scope

3 rules: ADaM-131, ADaM-151, ADaM-735.
