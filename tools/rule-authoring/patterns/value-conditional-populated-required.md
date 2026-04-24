# value-conditional-populated-required

## Intent

*"When `<COND_VAR>` is populated, `<TARGET_VAR>` must also be
populated"*. Matches P21's `val:Required` primitive with a `When=`
clause -- the canonical "conditionally required" shape.

Canonical message form:   `<TARGET_VAR> ^= null`  (i.e. must NOT be null)
Canonical condition form: `<COND_VAR> ^= null`

## CDISC source

SDTMIG v3.2+ units-follow-result consistency (e.g. `--STRESU`
populated -> `--STRESC` required); similar patterns for other
required-when-companion-populated pairs.

## P21 conceptual parallel (reference only)

P21 uses `val:Required` (see SD0036 for CG0397 / CG0426):

```
val:Required
  Variable="%Domain%STRESC"
  When="%Domain%STRESU != ''"
```

Semantic: when the When clause is true, the Variable must have a
value (`hasValue() == true` post-rtrim). Fails when Variable is
null on a record where When passes. `ConditionalRequiredValidationRule.java:47-55`
returns `entry.hasValue() ? 1 : 0`.

herald re-expresses as `{all: [non_empty(cond), empty(target)]}` --
fires when cond is populated AND target is empty. No XML/DSL copy.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `hasValue()` post-rtrim null | `DataEntryFactory.java:242-244,313-328` | `op_non_empty` rtrims + `nzchar`. Matches. |
| When=`VAR != ''` -> treats null cell as not-equal-to-null-string -> When passes (record IS checked) | `Comparison.NullComparison` | `op_non_empty(cond) = FALSE` on null cond -> `{all}` = FALSE -> no fire. herald is MORE CONSERVATIVE: where P21 checks on "non-empty-string" cond (including some edge cases around NULL_ENTRY distinguishing null from ''), herald treats them uniformly as empty. Functional equivalent for CDISC data. |
| Missing target column -> `CorruptRuleException` | `AbstractValidationRule.java:148-161` | `op_empty` on missing col returns NA -> advisory. More transparent. |
| Missing cond column -> same | same | Guard leaf returns NA -> `{all}` advisory. |
| `Variable=%Domain%STRESC` expansion | MagicVariable per-dataset | `--VAR` expansion at walker layer. Matches. |

## herald check_tree template

```yaml check_tree
expand: "%expand%"
all:
- operator: non_empty
  name: %cond_var%
- operator: empty
  name: %target_var%
```

## Expected outcome

- Positive: cond populated + target empty -> fires.
- Negative: cond empty (guard blocks) OR target populated -> no fire.

## Batch scope

1 rule: CG0426 (`--STRESC ^= null when --STRESU ^= null`).
