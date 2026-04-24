# value-flag-fn

## Intent

*"`<VAR>` is present and has a value that is not 1 or 0"*. Per-row:
fires on populated rows whose value is anything other than `1` or
`0`. Null / empty rows pass (consistent with the narrative
"is present and..." gate).

Canonical message form:
`<VAR> is present and has a value that is not 1 or 0`

## CDISC source

ADaMIG v1.1 Section 3.1 numeric indicator variables (FN suffix).
COMPLFN, FASFN, ITTFN, PPROTFN, SAFFN, RANDFN, ENRLFN must carry
`1` or `0` when populated; null is allowed.

Sister pattern to `value-flag-yn` (Y/N flags) for the numeric
indicator (FN) variable family.

## herald check_tree template

```yaml check_tree
all:
  - operator: non_empty
    name: %var%
  - operator: is_not_contained_by
    name: %var%
    value: ["1", "0"]
```

Slots:
- `var` -- the indicator variable name (e.g. `COMPLFN`).

## Expected outcome

- Positive: row has `<var>` populated with a value other than `1`
  or `0` -> fires.
- Negative: row has `<var>` = `1` or `0` -> no fire.
- `<var>` empty / NA -> no fire (the `non_empty` gate filters).

## Batch scope

7 rules: ADaM-26 (COMPLFN), ADaM-27 (FASFN), ADaM-28 (ITTFN),
ADaM-29 (PPROTFN), ADaM-30 (SAFFN), ADaM-31 (RANDFN),
ADaM-32 (ENRLFN).
