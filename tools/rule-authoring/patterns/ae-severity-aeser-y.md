# ae-severity-aeser-y

## Intent

*"When any serious-AE sub-flag (AESCAN, AESCONG, AESDISAB, AESDTH,
AESHOSP, AESLIFE, AESOD, AESMIE) is `'Y'`, AESER must be `'Y'`."*

Canonical message form: `AESER = 'Y'`
Canonical condition: any of the eight sub-flags equals `'Y'`.

Fires (per row) when at least one sub-flag is `'Y'` AND AESER is
not `'Y'`.

## CDISC source

SDTMIG v3.2+ AE domain guidance (IG v3.2 6.2):

> If categories of serious events are collected secondarily to a
> leading question, ... if Serious is answered "Yes", at least
> one of them will have a "Y" response.

## P21 conceptual parallel (reference only)

P21 `val:Condition` with
`When="AESCAN=='Y' or AESCONG=='Y' or AESDISAB=='Y' or AESDTH=='Y'
or AESHOSP=='Y' or AESLIFE=='Y' or AESOD=='Y' or AESMIE=='Y'"` and
`Test="AESER=='Y'"` (ConditionalValidationRule.java:42-48).
herald re-expresses as
`{all: [{any: [equal_to(col,'Y') * 8]}, not_equal_to(AESER,'Y')]}`.
`equal_to` (not `is_contained_by`) is the correct primitive here:
`op_equal_to` has the NullComparison-parity fix so a null lhs
against a non-null literal returns FALSE (matching P21's
`null == 'Y'` -> false). `op_is_contained_by` returns NA on a
null lhs (set-membership of an unknown value is undecidable),
which would collapse every all-null row to advisory under `{any}`.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `x == 'Y'` with NULL lhs -> NullComparison returns -1 -> false | `Comparison.java:160-207` | `equal_to(col,'Y')` on NA returns FALSE (via NullComparison-parity fix in op_equal_to). Under `{any}` all-false rows skip. Matches. |
| `AESER != 'Y'` with NA lhs -> rule fires (NullComparison -1 != 0 -> true) | `Comparison.java:160-207` | `not_equal_to(AESER,'Y')` returns TRUE on NA. Matches. |
| Missing sub-flag column -> `Optional` attribute skip | `RuleDefinition.Optional` | op returns NA mask; under `{any}` NAs propagate only when no `equal_to` leaf returns TRUE. If a sibling flag fires, the rule still fires. Functional equivalent. |
| Case-sensitive literal comparison default | `Comparison.java:194-205` | R's `==` is case-sensitive. Matches. |

## herald check_tree template

```yaml check_tree
all:
- any:
  - operator: equal_to
    name: AESCAN
    value: 'Y'
  - operator: equal_to
    name: AESCONG
    value: 'Y'
  - operator: equal_to
    name: AESDISAB
    value: 'Y'
  - operator: equal_to
    name: AESDTH
    value: 'Y'
  - operator: equal_to
    name: AESHOSP
    value: 'Y'
  - operator: equal_to
    name: AESLIFE
    value: 'Y'
  - operator: equal_to
    name: AESOD
    value: 'Y'
  - operator: equal_to
    name: AESMIE
    value: 'Y'
- operator: not_equal_to
  name: AESER
  value: 'Y'
```

## Expected outcome

- Positive: AESCAN='Y' AND AESER='N' -> fires.
- Negative: all eight sub-flags null AND AESER='N' -> no fire
  (guard-`{any}` FALSE).
- Negative #2: any sub-flag 'Y' AND AESER='Y' -> no fire
  (assertion FALSE).

## Batch scope

1 rule: CG0041 (AESER='Y' when any secondary severity flag='Y').
