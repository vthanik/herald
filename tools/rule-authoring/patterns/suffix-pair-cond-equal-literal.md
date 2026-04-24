# suffix-pair-cond-equal-literal

## Intent

*"When a column ending in `<SUFFIX1>` equals a specific literal value,
the column with the same stem ending in `<SUFFIX2>` must equal a
different specific literal value."*  Uses `stem` expansion to bind both
leaf names to the same concrete stem at evaluation time.

Canonical message form:
`A variable with a suffix of <SUFFIX1> is equal to <COND_VALUE> and a
variable with the same root and a suffix of <SUFFIX2> is not equal to
<REQUIRED_VALUE>`

## CDISC source

ADaMIG v1.1, Section 3, Item 9 (General Flag Variable Conventions):
flag pairing consistency rules:

- ADaM-10: when `*FL = 'Y'`, the paired numeric `*FN` must equal `1`.
- ADaM-11: when `*FL = 'N'`, the paired numeric `*FN` must equal `0`.

## P21 conceptual parallel (reference only)

P21 encodes these as `val:Match` rules with a `When=` guard asserting
`VARIABLE == '<VALUE>'` on the character flag column, then a `Terms=`
check on the numeric column. We re-express this independently using
herald's `equal_to` / `not_equal_to` operators.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| Guard value comparison is case-sensitive | `equal_to` with `value_is_literal: true` uses R `==` (case-sensitive). ADaM flag values are UPPERCASE, so this is correct. |
| Assertion comparison is numeric-normalised | `not_equal_to` with `value_is_literal: true` compares string representation. `*FN` values `0`/`1` are numeric SAS vars; herald's value compare normalises numeric to character before comparison (`.parse_sdtm_dt` path not triggered; direct `==` on trimmed string). Correct. |
| `stem` wildcard matches any prefix | herald's `expand: [suffix1, suffix2]` with `stem` placeholder drives `.expand_indexed()` to discover all `*FL` columns and bind each with its `*FN` sibling. |

## herald check_tree template

```yaml check_tree
expand:
- %suffix1%
- %suffix2%
all:
- operator: equal_to
  name: stem%suffix1%
  value: '%cond_value%'
  value_is_literal: true
- operator: not_equal_to
  name: stem%suffix2%
  value: '%required_value%'
  value_is_literal: true
```

Slots:
- `suffix1` -- conditioning suffix (e.g. `FL`).
- `cond_value` -- literal value that triggers the check (e.g. `Y`).
- `suffix2` -- target suffix (e.g. `FN`).
- `required_value` -- literal value the target must equal (e.g. `1`).

## Expected outcome

- Positive: stem+suffix1 equals cond_value AND stem+suffix2 does not
  equal required_value -- fires.
- Negative: stem+suffix1 does not equal cond_value (guard skips), OR
  stem+suffix2 equals required_value -- no fire.
- `provenance.executability` -> `predicate`.

## Batch scope

2 rules: ADaM-10 (FL=Y -> FN=1), ADaM-11 (FL=N -> FN=0).
