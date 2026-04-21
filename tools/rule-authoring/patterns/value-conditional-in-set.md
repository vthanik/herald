# value-conditional-in-set

## Intent

*"When `<COND_VAR>` equals `<COND_LIT>`, `<TARGET_VAR>` must be in
a controlled set of literals"*. Fires when the condition holds AND
the target is populated with a value OUTSIDE the allowed set.

Canonical message form: `<TARGET_VAR> in ('<LIT_1>', '<LIT_2>', ...)`
Canonical condition:    `<COND_VAR> = '<COND_LIT>'` or `VAR in (...)`

## CDISC source

SDTMIG v3.2+ Trial Summary records: specific TSPARMCD values
require TSVAL to be drawn from a constrained codelist
(`Y`/`N` for boolean parameters like ADDON, RANDOM, ADAPT).
Covered rules: CG0269 (ADDON), CG0271 (RANDOM), CG0282 (ADAPT).

## P21 conceptual parallel (reference only)

P21 uses `val:Match Variable=<TARGET> Terms=<allowed> When=<cond>`:

```
val:Match PublisherID="CG0269"
  Variable = TSVAL
  Terms    = Y,N
  Delimiter= ,
  When     = TSPARMCD == 'ADDON'
```

herald expresses this as a 2-leaf `{all}` tree: first leaf is the
guard (`is_contained_by(COND_VAR, [COND_LIT])`), second leaf is the
assertion (`is_not_contained_by(TARGET_VAR, [allowed])`). Both use
the existing set-membership ops; null target remains allowed (NA
under `is_not_contained_by` propagates to advisory).

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `val:Match` skips records where the variable is null | `FindValidationRule.java:208` | `op_is_not_contained_by` returns NA on null -> `{all}` NA -> advisory, not fire. Matches CDISC "null allowed" semantic. |
| `When=` short-circuits on false | `AbstractScriptableValidationRule.checkExpression` | `op_is_contained_by` returns FALSE when cond_var isn't in the guard set -> `{all}` FALSE -> no fire. Matches. |
| `Terms="Y,N"` split by `Delimiter` | `FindValidationRule.java` | herald uses YAML list `[Y, N]`; same resolved set. |
| CaseSensitive=Yes default | default | Herald's `%in%` is case-sensitive. Matches. |
| Null cond_var | `NullComparison` on `==` | `is_contained_by` returns NA on null -> guard NA -> advisory. More conservative than P21 (which treats null == '' as true for `@eqic`). Documented. |

## herald check_tree template

```yaml check_tree
all:
- operator: is_contained_by
  name: %cond_var%
  value: [%cond_values%]
- operator: is_not_contained_by
  name: %target_var%
  value: [%target_allowed%]
```

## Expected outcome

- Positive: cond holds AND target populated with value NOT in the
  allowed set -> fires.
- Negative: cond false (guard blocks) OR target in allowed set OR
  target null -> no fire.

## Batch scope

3 rules: CG0269 (TSVAL in Y,N when TSPARMCD='ADDON'),
CG0271 (TSVAL in Y,N when TSPARMCD='RANDOM'),
CG0282 (TSVAL in Y,N when TSPARMCD='ADAPT').
