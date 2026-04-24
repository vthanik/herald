# value-conditional-value-in-set

## Intent

*"When `<COND_VAR>` is in `<COND_VALS>`, `<TARGET_VAR>` must also be in
`<TARGET_VALS>`"*. Fires when the condition is met but the target is not
in the required set.

Canonical message form:
`<COND_VAR> is <COND_VAL> but <TARGET_VAR> is not <TARGET_VAL>`

Examples:
- `ONTRxxFL is Y but ONTRTFL is not Y`
- `TREMxxFL is Y but TRTEMFL is not Y`

## CDISC source

ADaMIG "indexed flag implies parent flag" family:
- ADaM-647: TREMxxFL=Y implies TRTEMFL=Y (xx expand).
- ADaM-648: TRTEMwFL=Y implies TRTEMFL=Y (w expand).
- ADaM-649: ONTRxxFL=Y implies ONTRTFL=Y (xx expand).
- ADaM-650: ONTRTwFL=Y implies ONTRTFL=Y (w expand).

## herald check_tree template

```yaml check_tree
expand: "%expand%"
all:
- operator: is_contained_by
  name: %cond_var%
  value:
  - "%cond_vals%"
- operator: is_not_contained_by
  name: %target_var%
  value:
  - "%target_vals%"
```

Fires when `cond_var` is in `cond_vals` (condition) AND `target_var` is
not in `target_vals` (assertion). `is_not_contained_by` returns NA when
the target row value is empty/null -- in that case the `all:` propagates
NA (advisory), which is correct: a null parent flag when the child flag
is Y is an advisory finding.

## Expected outcome

- Positive: cond_var='Y', target_var='N' -> fires.
- Negative: cond_var='Y', target_var='Y' -> no fire.
- Guard: cond_var='N' -> is_contained_by=FALSE -> all:=FALSE -> no fire.
- Advisory: cond_var='Y', target_var=null -> is_not_contained_by=NA -> all:=NA.

## Batch scope

4 rules: ADaM-647, 648, 649, 650.
