# suffix-var-value-in-codelist

## Intent

*"Every column whose name ends with `<SUFFIX>` must have a value
in a named CDISC CT codelist (or be null)"*. Uses the `stem`
index-expansion placeholder; per-row `value_in_codelist` fires
when a populated value is not found in the ADaM CT codelist.

Canonical message form:
`A variable with a suffix of <SUFFIX> has a value that is not within
Controlled Terminology for <CODELIST>`

## CDISC source

ADaMIG v1.1 date/time imputation flag variables:

- ADaM-39 (`*DTF`)  -- Date Imputation Flag; must be in DATEFL codelist.
- ADaM-40 (`*TMF`)  -- Time Imputation Flag; must be in TIMEFL codelist.

Both DATEFL and TIMEFL ship in the bundled ADaM CT (adam-ct.rds).

## herald check_tree template

```yaml check_tree
all:
- operator: value_in_codelist
  name: stem%suffix%
  codelist: "%codelist%"
  package: "adam"
```

Slots:
- `suffix`   -- column name suffix (e.g. `DTF`, `TMF`).
- `codelist` -- CT codelist code (e.g. `DATEFL`, `TIMEFL`).

## Expected outcome

- Positive: column value not in the named ADaM CT codelist -> fires.
- Negative: value found in codelist -> no fire.
- Null / NA -> `value_in_codelist` returns NA -> advisory, no fire.

## Batch scope

2 rules: ADaM-39 (DTF / DATEFL), ADaM-40 (TMF / TIMEFL).
