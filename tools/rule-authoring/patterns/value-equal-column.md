# value-equal-column

## Intent

Row-level assertion that two columns hold equal values on every
record. Unconditional sibling of `value-conditional-equal-column`:
where that pattern adds an `is_contained_by` guard, this one just
checks the pair.

Canonical message form:
`<VAR_A> = <VAR_B>`

## CDISC source

Scoped to specific SDTM domains where two variables capture the same
concept in different forms (e.g. `IESTRESC` is the standardized form
of `IEORRES` -- they must match on every record unless the
standardization step is broken). Each rule's `provenance.cited_guidance`
quotes the section requiring parity.

## P21 conceptual parallel (reference only)

P21 uses `val:Condition Test="%VAR_A% == %VAR_B%"` with no `When`
clause -- the per-record Test alone decides pass/fail
(ConditionalValidationRule.java:42-48). When LHS/RHS are variable
names, `Comparison` resolves both via `record.getValue(...)` and
`compareToAny(rhs, true)` does numeric-aware equality
(Comparison.java:160-207). herald re-expresses this as a single-leaf
tree with `op_not_equal_to` and `value_is_literal: false` -- fires
row-wise when the two columns differ.

## herald check_tree template

```yaml check_tree
operator: not_equal_to
name: %var_a%
value: %var_b%
value_is_literal: false
```

Just one leaf. The walker evaluates row-by-row; each violating row
emits an individual finding.

## Expected outcome

- Positive: 2-row fixture with `<VAR_A>` != `<VAR_B>` on at least
  one row -> fires 1x or more.
- Negative: all rows have `<VAR_A>` == `<VAR_B>` -> fires 0x.

## Batch scope

3 rules:
- CG0177 (`IESTRESC = IEORRES`, SDTMIG v3.2+ IE domain). Companion
  to the 5 conditional rules in `value-conditional-equal-column`.
- CG0037 (`--SOCCD = --BDSYCD`, SDTMIG v3.2+ EVT classes, MedDRA
  SOC code must equal body-system code used for analysis).
- CG0039 (`--BODSYS = --SOC`, SDTMIG v3.2+ EVT classes, body system
  must equal primary system organ class).
