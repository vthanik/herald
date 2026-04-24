# suffix-pair-cond-null

## Intent

*"When a column ending in `<SUFFIX1>` is null (empty), the column with
the same stem ending in `<SUFFIX2>` must also be null."*  Uses `stem`
expansion so both leaf names resolve to the same concrete stem at
evaluation time.

Canonical message form:
`A variable with a suffix of <SUFFIX1> is equal to null and a variable
with the same root and a suffix of <SUFFIX2> is not equal to null`

## CDISC source

ADaMIG v1.1, Section 3, Item 9 (General Flag Variable Conventions):
flag pairing consistency rules:

- ADaM-12: when `*FL` is null, the paired numeric `*FN` must also be
  null (not populated).

## P21 conceptual parallel (reference only)

P21 encodes this as a `val:Match` rule where the `When=` guard checks
that the character flag column has no value (`entry.hasValue() == false`),
then a `Terms=` assertion requires the numeric column to also have no
value. We re-express this independently using herald's `empty` /
`non_empty` operators.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| `entry.hasValue()` treats right-trimmed empty string as null | `op_empty` applies `sub("\\s+$","",x)` before `nzchar` -- equivalent. |
| Guard and assertion are both value-level (row-by-row) | `empty` and `non_empty` operate row-by-row. Correct. |
| `stem` wildcard matches any prefix | herald's `expand: [suffix1, suffix2]` drives `.expand_indexed()` to discover all `*FL` columns and bind each with its `*FN` sibling. |

## herald check_tree template

```yaml check_tree
expand:
- %suffix1%
- %suffix2%
all:
- operator: empty
  name: stem%suffix1%
- operator: non_empty
  name: stem%suffix2%
```

Slots:
- `suffix1` -- null-guarded suffix (e.g. `FL`).
- `suffix2` -- populated-assertion suffix (e.g. `FN`).

## Expected outcome

- Positive: stem+suffix1 is null AND stem+suffix2 is populated -- fires.
- Negative: stem+suffix1 is populated (guard skips), OR stem+suffix2 is
  also null -- no fire.
- `provenance.executability` -> `predicate`.

## Batch scope

1 rule: ADaM-12 (FL=null -> FN must be null too).
