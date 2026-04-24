# suffix-var-is-numeric

## Intent

*"Every column whose name ends with `<SUFFIX>` must be stored as
a numeric variable"*. Uses the `stem` index-expansion placeholder;
the new `var_by_suffix_not_numeric` op checks `!is.numeric(col)`
and fires on all rows when the column type is wrong.
`exclude_prefix` allows a specific stem to be exempted
(ADaM-716: ELTM excluded because it originates from SDTM).

Canonical message form:
`A variable with a suffix of <SUFFIX> is not a numeric variable`

## CDISC source

ADaMIG v1.1 timing variable conventions: displacement date/time
variables derived from reference dates must be stored as numeric
(days or fractions thereof) so arithmetic comparisons are valid.

- ADaM-58  (`*DT`)  -- Analysis Date; numeric.
- ADaM-59  (`*TM`)  -- Analysis Time; numeric.
- ADaM-60  (`*DTM`) -- Analysis Datetime; numeric.
- ADaM-716 (`*TM` excluding ELTM) -- same as 59 but ELTM is
  excluded because it is a direct SDTM carry-over.

## herald check_tree template

```yaml check_tree
all:
- operator: var_by_suffix_not_numeric
  name: stem%suffix%
  exclude_prefix: "%exclude_prefix%"
```

Slots:
- `suffix`         -- column name suffix (e.g. `DT`, `TM`, `DTM`).
- `exclude_prefix` -- stem prefix to skip (e.g. `EL`); empty string
                      means no exclusion.

## Expected outcome

- Positive: matching column is not numeric -> fires on all rows.
- Negative: column is numeric -> no fire.
- Column absent -> NA (advisory).
- Column matches exclude_prefix -> FALSE (pass).

## Batch scope

4 rules: ADaM-58 (DT), ADaM-59 (TM), ADaM-60 (DTM), ADaM-716 (TM/excl ELTM).
