# ae-severity-aeser-n

## Intent

*"When every serious-AE sub-flag (AESCAN, AESCONG, AESDISAB,
AESDTH, AESHOSP, AESLIFE, AESOD) is not `'Y'`, AESER must be
`'N'`."*

Canonical message form: `AESER = 'N'`
Canonical condition: `AESCAN ^= 'Y' AND AESCONG ^= 'Y' AND ...`.

Fires (per row) when every sub-flag is not `'Y'` AND AESER is
not `'N'`.

## CDISC source

SDTMIG v3.2+ AE domain guidance (IG v3.2 6.2), contrapositive of
CG0041:

> If categories of serious events are collected secondarily to a
> leading question, ... if Serious is answered "No", the values
> for these variables may be null.

## P21 conceptual parallel (reference only)

P21 `val:Condition` with
`When="AESCAN^='Y' and AESCONG^='Y' and AESDISAB^='Y' and
AESDTH^='Y' and AESHOSP^='Y' and AESLIFE^='Y' and AESOD^='Y'"` and
`Test="AESER=='N'"`. herald re-expresses as
`{all: [is_not_contained_by * 7, not_equal_to(AESER,'N')]}`.

Note: the SDTMIG narrative lists only seven sub-flags (the
AESMIE "other medically important" flag is excluded from the
all-null guard -- AESMIE excluded by design). Matches the
YAML condition verbatim.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `x != 'Y'` with NULL lhs -> true (NullComparison -1 != 0) | `Comparison.java:160-207` | herald uses `not_equal_to(col,'Y')` (not `is_not_contained_by`) because `op_equal_to` has the NullComparison-parity fix (NA vs non-null literal -> FALSE, so `not_equal_to` -> TRUE on NA). `op_is_not_contained_by` wraps `op_is_contained_by` which returns NA for null lhs (container-membership cannot be asserted when the value is missing), so using the set-op in CG0042 would collapse every all-null row to advisory. `not_equal_to` is the correct primitive here. Matches P21. |
| `AESER != 'N'` with NA lhs -> rule fires | `Comparison.java:160-207` | `not_equal_to(AESER,'N')` returns TRUE on NA. Matches. |
| Missing sub-flag column -> `Optional` attribute skip | `RuleDefinition.Optional` | op returns NA mask; under `{all}` a single NA collapses to NA -> one advisory per (rule x dataset). Functional equivalent. |
| Case-sensitive literal comparison default | `Comparison.java:194-205` | R's `==` is case-sensitive. Matches. |

## herald check_tree template

```yaml check_tree
all:
- operator: not_equal_to
  name: AESCAN
  value: 'Y'
- operator: not_equal_to
  name: AESCONG
  value: 'Y'
- operator: not_equal_to
  name: AESDISAB
  value: 'Y'
- operator: not_equal_to
  name: AESDTH
  value: 'Y'
- operator: not_equal_to
  name: AESHOSP
  value: 'Y'
- operator: not_equal_to
  name: AESLIFE
  value: 'Y'
- operator: not_equal_to
  name: AESOD
  value: 'Y'
- operator: not_equal_to
  name: AESER
  value: 'N'
```

## Expected outcome

- Positive: all seven sub-flags null AND AESER='Y' -> fires.
- Negative: AESCAN='Y' AND AESER='Y' -> no fire (guard FALSE on
  first leaf).
- Negative #2: all seven sub-flags null AND AESER='N' -> no fire
  (assertion FALSE).

## Batch scope

1 rule: CG0042 (AESER='N' when all secondary severity flags
^= 'Y').
