# value-conditional-not-equal-column

## Intent

Record-level assertion *"when `<COND_VAR>` is populated, `<VAR_A>`
must NOT equal `<VAR_B>`"*. Combines a populated-guard with the
column-pair-inequality check from `value-not-equal-column`. Fires when
the guard holds AND the pair is equal on the same record.

Canonical message form:
`<VAR_A> ^= <VAR_B>` (assertion in CDISC user DSL)
Canonical condition:
`<COND_VAR> ^= null` (guard -- cond_var is populated)

## CDISC source

SDTMIG v3.2+: sub-category (`--SCAT`) cannot equal category
(`--CAT`) when SCAT is populated (CG0027); RELREC pool/subject
identifiers must not alias parent-domain keys (CG0363/364).

## P21 conceptual parallel (reference only)

P21 uses `val:Condition When="%COND_VAR% != ''" Test="%A% != %B%"`
(ConditionalValidationRule.java:42-48). The When-clause activates
on a populated guard; the Test fails when the two columns are equal.
herald re-expresses as
`{all: [non_empty(cond_var), equal_to(var_a, var_b, cols)]}`:
`{all}` TRUE (violation) when guard is satisfied AND the columns
match. No XML/DSL copy.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `When=` -> skip record when guard is false | `ConditionalValidationRule.java:47` | `non_empty(cond_var) = FALSE` collapses `{all}` to FALSE -> no fire. Matches. |
| `hasValue()` post-rtrim | `DataEntryFactory.java:242-244,313-328` | `op_non_empty` rtrims trailing spaces + `nzchar` test. `"   "` is null, `"X "` is populated. Matches. |
| `!=` evaluation with two null cells -> TRUE (null == null is FALSE per `compareToAny`) -- actually: `NullDataEntry.compareTo(NullDataEntry)` returns 0 (equal), so `!=` is FALSE on both-null -> Test fails -> fires | `Comparison.java:194-205` + `DataEntryFactory.java:349` | herald's `op_equal_to` col-to-col returns NA on NA cells; under `{all}`, NA -> advisory. **Deviation**: P21 fires on both-null rows (treats `null == null` = equal = violation); herald emits advisory. Safer default; reviewer can verify intentional nulls. |
| `!=` with one null, one populated -> TRUE (null differs from X) | same | herald returns NA -> advisory. P21 does NOT fire (non-violation path); herald is more conservative. |
| Missing column -> `CorruptRuleException` | `AbstractValidationRule.java:148-161` | NA mask -> advisory. More transparent. |
| Case-sensitive comparison | `Comparison.java:194-205` default | R's `==` is case-sensitive. Matches. |
| **Fuzzy date prefix equality** when both sides are DateTime or 4-char Integer-like (year) | `DataEntryFactory.java:172-180` | herald does strict string compare. **Not applicable** -- this pattern's columns (--SCAT/--CAT categorical, RSUBJID/USUBJID/POOLID identifiers) aren't date-typed. |
| NullDataEntry.compareToAny returns 0 (equal) when BOTH sides null, -1 when lhs null + rhs populated | `DataEntryFactory.java:349-357` | Explains why P21 fires on both-null (treats null==null as equal violation); herald's NA propagation emits advisory instead. Documented deviation preserves conservative default. |

## herald check_tree template

```yaml check_tree
all:
- operator: non_empty
  name: %cond_var%
- operator: equal_to
  name: %var_a%
  value: %var_b%
  value_is_literal: false
```

Slots:
- `cond_var`   -- guard column, must be populated to enable the check
- `var_a` / `var_b` -- the two columns asserted to differ

## Expected outcome

- Positive: cond_var populated AND var_a == var_b on one row -> fires.
- Negative: cond_var populated AND var_a != var_b -> no fire.
- Negative #2: cond_var empty (guard blocks) -> no fire regardless.

## Batch scope

3 rules: CG0027 (--SCAT ^= --CAT), CG0363 (RSUBJID ^= USUBJID),
CG0364 (RSUBJID ^= POOLID). All SDTMIG v3.2+, per-record row-level.

Deferred (1 rule): CG0201 (`IDVAR ^= --SEQ` under compound null-
guard `IDVARVAL = null AND USUBJID = null`). Needs additional leaf
composition; lands in a future batch.
