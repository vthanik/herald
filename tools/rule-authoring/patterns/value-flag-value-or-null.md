# value-flag-value-or-null

## Intent

Fires when `%var%` is populated with a value NOT in `%allowed%`.
Null/empty rows pass (the non_empty gate filters them). Same structure
as `value-flag-yn` but with a parameterized allowed set. Used for flag
variables that permit a specific non-Y/N value set (e.g. only 'Y', or
only '1', '2', '3').

Canonical message form:
`<VAR> is present and has a value that is not in (<allowed>)`

## CDISC source

ADaMIG flag variables with restricted value sets:
- Numeric flag variables (ABLFN, ANLzzFN) that must be 1 when populated.
- Severity numeric variables (AESEVN, ASEVN) that must be 1, 2, or 3.
- Treatment flag variables (TRTEMFL, PREFL, FUPFL, ONTRTFL, LVOTFL)
  that must be Y when populated.
- Indexable flags (ANLzzFL, SMQzzSC, SMQzzSCN) with restricted value
  sets.

## P21 conceptual parallel (reference only)

P21 uses `val:Compliance` with either a codelist reference or inline
`Terms`. herald expresses this as `non_empty + is_not_contained_by`
with the literal set authored per-rule.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| Null cell -> `hasValue() == false` -> rule passes | `op_non_empty` returns FALSE on null -> `all` short-circuits -> no fire. Matches. |
| Set membership is case-sensitive | `op_is_not_contained_by` uses `%in%`. CDISC values are uppercase. Matches. |

## herald check_tree template

```yaml check_tree
expand: "%expand%"
all:
  - operator: non_empty
    name: %var%
  - operator: is_not_contained_by
    name: %var%
    value: [%allowed%]
```

## Expected outcome

- Positive: row has `<var>` populated with a value not in allowed set -> fires.
- Negative: row has `<var>` in the allowed set -> no fire.
- Null / empty rows -> no fire (non_empty gate).

## Batch scope

13 rules: ADaM-176, 178, 211, 212, 269, 270, 271, 279, 282, 312, 313,
363, 619.
