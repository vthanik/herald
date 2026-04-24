# value-in-literal-set

## Intent

Fires when `%var%` IS in the disallowed set. Inverse of `value-in-set`
(which fires when a value is NOT in an allowed set). Used when specific
values are prohibited -- for example, flag variables must not be 'N',
or ARM must not be certain screening/unplanned treatment labels.

Canonical message form:
`<VAR> must not be in (<disallowed>)`

## CDISC source

ADaMIG / SDTMIG rules where specific values are explicitly prohibited:
- ADaM-493/494: ANLzzFL/ABLFL must not be 'N' (only 'Y' or null allowed
  for these flag variables).
- CG0244: ARM must not be a screen-failure or administrative treatment
  arm label.

## P21 conceptual parallel (reference only)

P21 uses `val:Match` with a negative sense or a separate exclusion check.
herald uses `is_contained_by` which fires TRUE when the value IS in the
listed set -- the violation condition.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| Null cell -> passes (no violation) | `op_is_contained_by` returns NA on null -> advisory (no fire). Matches. |
| Case-sensitive match | `op_is_contained_by` uses `%in%`. Matches. |
| Missing column -> advisory | `op_is_contained_by` returns NA on absent column. Matches. |

## herald check_tree template

```yaml check_tree
expand: "%expand%"
operator: is_contained_by
name: %var%
value: [%disallowed%]
```

## Expected outcome

- Positive: row has `<var>` set to a disallowed value -> fires.
- Negative: row has `<var>` set to an allowed value or null -> no fire.

## Batch scope

3 rules: ADaM-493, ADaM-494, CG0244.
