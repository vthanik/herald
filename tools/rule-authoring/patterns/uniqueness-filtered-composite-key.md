# uniqueness-filtered-composite-key

## Intent

Within rows where `%filter_var%` is in `%filter_values%`, the composite
key formed by `%keys%` must be unique. Fires on all rows in a violating
group that also pass the filter condition.

Canonical message form:
`When <FILTER_VAR> is '<filter_values>', the combination of (<keys>) must be unique`

## CDISC source

SDTMIG DS domain uniqueness rules for disposition events:
- CG0398: When DSCAT='DISPOSITION EVENT', (USUBJID, EPOCH) must be unique.
- CG0536: When DSCAT='DISPOSITION EVENT', (USUBJID, DSSCAT, EPOCH) must be unique.
- CG0537: When DSCAT='DISPOSITION EVENT', (USUBJID, EPOCH) must be unique.

## P21 conceptual parallel (reference only)

P21 uses `val:Unique` with a `When=` clause and composite `GroupBy`. herald
expresses this as `{all: [is_contained_by(filter), is_not_unique_set([keys])]}`.
Note: `is_not_unique_set` only fires on rows within violating groups that also
pass the outer filter condition.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| Filter applied before uniqueness check | `is_contained_by` in `all` short-circuits -> non-filter rows pass. Matches. |
| Null in composite key -> treated as its own group | `is_not_unique_set` joins on the actual values including NA. Matches. |
| Missing column -> advisory | Both ops return NA on absent column. Matches. |

## herald check_tree template

```yaml check_tree
all:
- operator: is_contained_by
  name: %filter_var%
  value: [%filter_values%]
- operator: is_not_unique_set
  name:
%keys%
```

The `%keys%` slot must be a YAML block with lines like:
```
  - USUBJID
  - EPOCH
```
(two-space indent, one variable per line).

## Expected outcome

- Positive: two rows with DSCAT='DISPOSITION EVENT' sharing the same
  (USUBJID, EPOCH) -> both fire.
- Negative: all (USUBJID, EPOCH) combinations under DISPOSITION EVENT
  are unique -> no fire.
- Rows with DSCAT != 'DISPOSITION EVENT' -> no fire.

## Batch scope

3 rules: CG0398, CG0536, CG0537.
