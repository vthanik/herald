# value-conditional-not-matches-regex

## Intent

Fires when `%cond_var%` is in `%cond_values%` AND `%target_var%` does
NOT match `%pattern%`. Used for TS-domain parametric rules where a
specific TSPARMCD value requires TSVAL to follow a numeric format.

Canonical message form:
`When <COND_VAR> is in (<cond_values>), <TARGET_VAR> must match <pattern>`

## CDISC source

SDTMIG Trial Summary (TS) domain parametric validation:
- CG0284: TSPARMCD='NARMS' -> TSVAL must be a positive integer.
- CG0440: TSPARMCD='PLANSUB' -> TSVAL must be a positive integer.
- CG0457: TSPARMCD='ACTSUB' -> TSVAL must be a positive integer.

## P21 conceptual parallel (reference only)

P21 uses `val:Regex` with a `When=` clause filtering by TSPARMCD.
herald uses `{all: [is_contained_by(cond_var), not_matches_regex(target_var)]}`.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| When clause filters before regex test | `is_contained_by` in `all` short-circuits; no regex test when cond not met. Matches. |
| Null TSVAL -> passes (no regex match required) | `op_not_matches_regex` returns NA on null -> `all` advisory -> no fire. Matches. |
| Missing column -> advisory | Both ops return NA on absent column. Matches. |

## herald check_tree template

```yaml check_tree
all:
- operator: is_contained_by
  name: %cond_var%
  value: [%cond_values%]
- operator: not_matches_regex
  name: %target_var%
  value: '%pattern%'
```

## Expected outcome

- Positive: TSPARMCD='NARMS' and TSVAL='abc' (not numeric) -> fires.
- Negative: TSPARMCD='NARMS' and TSVAL='5' (positive integer) -> no fire.
- TSPARMCD != 'NARMS' -> no fire (condition not met).

## Batch scope

3 rules: CG0284, CG0440, CG0457.
