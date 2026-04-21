# value-not-equal-column

## Intent

Unconditional row-level assertion that two columns must NOT hold
equal values on any record. Mirror of `value-equal-column`: that one
fires when the pair differs; this one fires when the pair matches.

Canonical message form:
`<VAR_A> ^= <VAR_B>`

(CDISC user DSL: `^=` means "not equal" -- SAS convention. Not to be
confused with P21's XML DSL where `^=` means case-insensitive equal.)

## CDISC source

SDTMIG v3.2+ consistency rules on Category / Subcategory /
Dictionary-Derived pairs: subcategory (`--SCAT`) must be a finer
grouping than category (`--CAT`), and neither should equal the
dictionary-derived term (`--DECOD`) or body-system (`--BODSYS`).
Redundant pair-equality means the author has copied a value rather
than providing the intended categorization.

## P21 conceptual parallel (reference only)

P21 uses `val:Condition` without a `When=` clause:
`Test="%A% != %B%"` (Comparison.java:160-207 default path, no null
short-circuit). herald re-expresses as a single-leaf
`{operator: equal_to, value_is_literal: false}` -- the op returns
TRUE when the pair is equal, which is the violation condition under
our TRUE=fire convention. No XML/DSL copy.

## P21 edge-case audit (Comparison.java + DataEntryFactory.java)

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `Comparison.evaluate` uses `lhs.compareToAny(rhs, true)` for `==`/`!=`; type-aware compare (numeric-aware where possible) | `Comparison.java:194-205` | `op_equal_to` with `value_is_literal: false` uses R's `col == other` -- promotes numeric/character on mixed types. Matches P21's type-aware equality. |
| `NullDataEntry.compareTo(NullDataEntry)` returns 0 (null == null is TRUE in P21) | `DataEntryFactory.java:349` inferred via `rhs.hasValue() ? -1 : 0` for NullDataEntry | **Deviation**: R's `NA == NA` returns NA (3-valued logic). Under `op_equal_to` on col-to-col, NA entries propagate NA to the mask -> advisory, not fire. P21 would fire a "both-null" row as a violation here ('SCAT and CAT are both null' = redundant). herald is more conservative; the reviewer gets an advisory rather than a potential false fire on empty rows. |
| `NullDataEntry.compareTo(<non-null>)` returns -1 (null != X is TRUE in P21) | same | R's `NA == 'X'` returns NA -> advisory. P21 would NOT fire (null != X is the non-violation side). herald's advisory is acceptable (no false fire). |
| `compareTo` for string values uses rtrim-null applied at ingest | `DataEntryFactory.java:69-79,313-328` | XPT reader already rtrims at load; herald's `==` runs over rtrimmed strings. Matches. |
| **Fuzzy date prefix equality** -- when both sides look like dates (DateTime or 4-char Integer), P21 treats `'2024-01-15'` and `'2024'` as equal via `startsWith` | `DataEntryFactory.java:172-180` | herald does strict string compare. **Not applicable to this pattern** -- none of the 4 in-scope column pairs (--CAT/--DECOD, --SCAT/--DECOD, --CAT/--BODSYS, --SCAT/--BODSYS) are date-typed. Documented for completeness. |
| Case-sensitive default on `compareToAny(rhs, true)` for `==`/`!=` | `Comparison.java:195` + `DataEntryFactory.java:182-185` (only lowercases when `caseSensitive=false`) | R's `==` is case-sensitive on character vectors. Matches. |
| Numeric-numeric compare via BigDecimal.compareTo | `DataEntryFactory.java:160` | R's `==` on mixed numeric coerces via standard promotion; BigDecimal-precision nuances don't apply to these identifier/category columns. Not relevant here. |
| Variable name `.toUpperCase()` at rule init | `ConditionalValidationRule.java` via `AbstractScriptableValidationRule` | walker's case-insensitive `name` resolution (rules-walk.R:156-163). Matches. |
| Missing either column -> `CorruptRuleException` (rule disabled) | `AbstractValidationRule.java:148-161` | `op_equal_to` on missing col returns NA mask -> advisory. More transparent. |

## herald check_tree template

```yaml check_tree
operator: equal_to
name: %var_a%
value: %var_b%
value_is_literal: false
```

Slots:
- `var_a` / `var_b` -- the two columns. TRUE (violation) on a record
  where both columns hold equal non-NA values.

## Expected outcome

- Positive: 2-row fixture with `<VAR_A>` == `<VAR_B>` on at least one
  row -> fires 1x or more.
- Negative: all rows have `<VAR_A>` != `<VAR_B>` -> fires 0x.

## Batch scope

4 rules: CG0337 (--CAT ^= --DECOD), CG0338 (--SCAT ^= --DECOD),
CG0339 (--CAT ^= --BODSYS), CG0340 (--SCAT ^= --BODSYS). All
SDTMIG v3.2+, scope `ALL / ALL`, severity Medium.
