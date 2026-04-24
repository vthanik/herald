# suffix-var-value-in-set

## Intent

*"Every column whose name ends with `<SUFFIX>` must have a value
in a controlled literal set (or be null)"*. Uses the `stem`
index-expansion placeholder to iterate all matching columns;
per-row `is_not_contained_by` fires when a populated value falls
outside the allowed set.

Canonical message form:
`A variable with a suffix of <SUFFIX> has a value that is not <allowed>`

## CDISC source

ADaMIG v1.1 suffix-based flag/indicator conventions:

- ADaM-5  (`*FL`)  -- values must be Y, N, or null.
- ADaM-33 (`*RFL`) -- Reference Range Indicator; Y or null.
- ADaM-34 (`*PFL`) -- Period Flag; Y or null.
- ADaM-35 (`*RFN`) -- Reference Range numeric; 1 or null.
- ADaM-36 (`*PFN`) -- Period Flag numeric; 1 or null.

## herald check_tree template

```yaml check_tree
all:
- operator: is_not_contained_by
  name: stem%suffix%
  value: [%allowed%]
```

Slots:
- `suffix`  -- the column name suffix (e.g. `FL`, `RFL`).
- `allowed` -- comma-separated quoted literals for inline YAML list
               (e.g. `'Y', 'N'`).

## Expected outcome

- Positive: column matching `stem<SUFFIX>` is populated with a
  value outside the allowed set -> fires.
- Negative: value is in the allowed set -> no fire.
- Null / NA value -> `is_not_contained_by` returns NA -> advisory,
  no fire (null allowed by CDISC convention).

## Batch scope

5 rules: ADaM-5 (FL in Y,N), ADaM-33 (RFL in Y), ADaM-34 (PFL in Y),
ADaM-35 (RFN in 1), ADaM-36 (PFN in 1).
