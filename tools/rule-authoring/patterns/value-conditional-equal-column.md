# value-conditional-equal-column

## Intent

A small family of SDTM-IG cross-variable consistency rules: when a
condition on one variable holds (e.g. ACTARM is a special code like
"Screen Failure"), a second variable must match (be equal to) a third
variable on the same record. The CDISC rule carries the assertion in
`check.narrative` (form `VAR_A = VAR_B`) and the precondition in
`check.condition` (form `<cond_var> in (<list>)` or
`<cond_var> = '<literal>'`).

Canonical message form:
`<VAR_A> = <VAR_B>`
(i.e. the compliant state; rule fires when, under the condition,
VAR_A does NOT equal VAR_B on a given record.)

## CDISC source

SDTMIG v3.2+ Trial Arms / Trial Elements / Inclusion-Exclusion
sections. The rules handle the special ACTARM / ARM reconciliation
(`Screen Failure`, `Not Assigned` subjects), DS protocol-milestone
wording (`DSTERM = DSDECOD` when `DSCAT = 'PROTOCOL MILESTONE'`),
and IE result parity (`IESTRESC = IEORRES`). Each YAML's
`provenance.cited_guidance` quotes the relevant IG clause.

## P21 conceptual parallel (reference only)

P21 implements this via `val:Condition` with a compound DSL
expression: `Test="%VAR_A% = %VAR_B%" When="%COND_VAR% in
(<list>)"` (ConditionalValidationRule.java:42-48 prepares both
expressions; `performValidation` short-circuits to -1/skip when
`When` evaluates false, otherwise returns pass/fail based on `Test`).

herald re-expresses the same concept with a compound check_tree:

```
all:
  - operator: is_contained_by    <- the "When" guard
    name: <cond_var>
    value: [<cond_values>]
  - operator: not_equal_to       <- the negated "Test" assertion
    name: <var_a>
    value: <var_b>
    value_is_literal: false
```

Under `{all}`, the rule fires when BOTH the guard is true AND the
assertion is violated -- exactly P21's ConditionalValidation
semantics. No XML or DSL copy.

## P21 parity points (audit)

- **`When=` short-circuit -> skip** -- P21 returns -1 when the When
  clause is false; herald's `is_contained_by` returns FALSE on
  rows where cond_var is not in the set, collapsing `{all}` to FALSE
  on those rows -> no fire. Same per-record semantics, different
  mechanism (explicit skip vs mask arithmetic).
- **NA on cond_var** -- P21 treats a null cond_var as When-fails
  (hasValue() == false -> expression evaluates false). herald's
  `is_contained_by` returns NA when the cell is null/empty (rtrim
  null). Under `{all}`, NA collapses the whole-row to NA -> advisory
  (not fire). More transparent than P21's silent skip.
- **Column-to-column equality in the assertion** -- herald's
  `op_not_equal_to` accepts `value_is_literal: false` to interpret
  `value` as a column name; the op compares the two R vectors
  element-wise. Missing either column -> NA mask -> advisory. P21
  would throw CorruptRuleException (rule-level disable).
- **Case-insensitive compare** -- not applied by default. CDISC
  rule text is case-sensitive (`'Screen Failure'`, `'SCRNFAIL'`
  etc.). If a rule needs CI, switch to `is_contained_by_case_insensitive`.
- **Character vs numeric coercion** -- `op_equal_to` aligns types
  via `.coerce_compare` before comparison; numeric columns that
  contain `"01"` vs character `"1"` will coerce to numeric 1 and
  compare equal. Matches P21's DataEntryFactory type-inference.

## herald check_tree template

```yaml check_tree
all:
- operator: is_contained_by
  name: %cond_var%
  value: [%cond_values%]
- operator: not_equal_to
  name: %var_a%
  value: %var_b%
  value_is_literal: false
```

Slots:
- `cond_var` -- the variable the guard inspects
- `cond_values` -- comma-separated quoted literals already YAML-formatted
  (e.g. `'Screen Failure', 'Not Assigned'`). Rendered inside `[...]`.
- `var_a` / `var_b` -- the two columns that must be equal under the
  guard. Not equal on a given record = violation.

## Batch scope

5 rules: CG0066, CG0119, CG0122, CG0127, CG0129. All SDTMIG v3.2+,
severity Medium, per-record row-level. The unconditional sibling
CG0177 (`IESTRESC = IEORRES`, no guard) is handled separately in
the same commit as a one-off bare `not_equal_to` assertion.

## Fixture strategy

Per-rule synth: smoke-check builds a 2-row fixture with `cond_var`
set to the first listed condition value on both rows. Row 1 has
`var_a` == `var_b` (compliant), row 2 has them different (violation).
Positive fires 1x (row 2), negative (where both rows comply) fires 0x.
