# suffix-pair-value-in-set

## Intent

*"When a column ending in `<SUFFIX1>` is populated, the column
with the same stem ending in `<SUFFIX2>` must be in a controlled
set (or null)"*. Uses `stem` expansion twice in the same tree so
both leaf names resolve to the same concrete stem; a `non_empty`
gate on the first suffix conditions the check on the second.

Canonical message form:
`A variable with a suffix of <SUFFIX1> is present and a variable
with the same root and a suffix of <SUFFIX2> has a value that is
not <allowed>`

## CDISC source

ADaMIG v1.1 flag pairing rule:

- ADaM-6 (`*FL` present -> `*FN` in {0, 1, null}): when the
  corresponding binary flag (FL) is populated the numeric
  indicator (FN) must be 0, 1, or absent.

## herald check_tree template

```yaml check_tree
all:
- operator: non_empty
  name: stem%suffix1%
- operator: is_not_contained_by
  name: stem%suffix2%
  value: [%allowed%]
```

Slots:
- `suffix1` -- conditioning suffix (e.g. `FL`).
- `suffix2` -- target suffix (e.g. `FN`).
- `allowed` -- comma-separated quoted literals (e.g. `'0', '1'`).

## Expected outcome

- Positive: stem+suffix1 populated AND stem+suffix2 value not in
  allowed set -> fires.
- Negative: stem+suffix1 empty (gate blocks) OR stem+suffix2 in
  allowed set OR stem+suffix2 null -> no fire.

## Batch scope

1 rule: ADaM-6 (FL present -> FN in 0,1 or null).
