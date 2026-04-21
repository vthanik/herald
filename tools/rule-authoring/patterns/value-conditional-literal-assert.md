# value-conditional-literal-assert

## Intent

A record-level rule of the form *"when `<COND_VAR>` is in a set of
literal values, `<TARGET_VAR>` must equal `<TARGET_LIT>`"*. Both the
guard and the assertion compare against string literals. The
assertion covers exactly one allowed value; any other non-null value
on the target is a violation.

Canonical message form:   `<TARGET_VAR> = '<TARGET_LIT>'`
Canonical condition forms:
 - `<COND_VAR> = '<LIT>'`
 - `<COND_VAR> in ('<LIT_1>', '<LIT_2>', ...)`

Both guard shapes collapse to a single-leaf `is_contained_by` check
(the eq form is `is_contained_by` with a one-element set).

## CDISC source

SDTMIG v3.2+ DS completion / IE inclusion-exclusion / TS controlled-
code-reference rules. Each YAML's `provenance.cited_guidance` anchors
the assertion to an IG section (e.g., *"DSDECOD value for completion
disposition must be 'COMPLETED'"*).

## P21 conceptual parallel (reference only)

P21 uses `val:Condition When="%COND_VAR% == '<LIT>'" Test="%TARGET_VAR%
== '<TARGET_LIT>'"` for the eq-guard form, and switches `When` to
`%COND_VAR% in_list ('<LIT_1>', '<LIT_2>')` for the set-guard form
(ConditionalValidationRule.java:42-48 + Expression.java handling of
the `in` operator). herald re-expresses via
`{all: [is_contained_by(cond_var, [<set>]), not_equal_to(target, '<lit>')]}`:
the `{all}` evaluates TRUE (violation) when guard is satisfied AND
target differs from the required literal. No XML/DSL copy.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `in` / `not_in` DSL operator iterates list members with `equalsIgnoreCase` where appropriate | `Expression.java` + `Comparison.java:177-205` | `op_is_contained_by` does case-sensitive `%in%` on rtrimmed values. Matches CDISC text conventions (literals are stored verbatim). |
| `NULL_ENTRY` vs populated on the guard variable | `DataEntry.java:25` + `NullDataEntry` | `op_is_contained_by` returns NA on NA / empty / all-spaces rows; under `{all}`, NA -> advisory per-row (does not fire). P21's When-false skip has the same no-fire effect. |
| `== '<LIT>'` dispatch with rtrim of both sides | `DataEntryFactory.java:69-79,313-328` | `op_not_equal_to` -> `op_equal_to` -> `.coerce_compare` (character path for strings); rtrim applied at XPT ingest, so `'LIT '` and `'LIT'` compare equal. |
| Target null -> Test `==` returns false -> fires (rule violated because target has no value) | `Comparison.java:194-205` + `DataEntryFactory.java:349` (NullDataEntry.compareTo returns -1 vs non-null rhs) | `op_equal_to` now treats NA cells as FALSE when compared to a non-null literal (ops-compare.R `result[is.na(col)] <- FALSE`). Under `{all}` with `not_equal_to`, NA target evaluates to TRUE -> fires. **Matches P21.** (Column-to-column compare path still propagates NA.) |
| Target on a missing column -> P21 throws `CorruptRuleException` (rule disabled) | `AbstractValidationRule.java:148-161` | `op_not_equal_to` on missing column returns NA -> advisory. |
| Case sensitivity on literal match | no `(?i)` flag on default Comparison path | R's `==` is case-sensitive. Matches. |

### Additional P21 findings (XML + Expression.java)

| P21 behaviour | Source | herald decision |
|---|---|---|
| `@eqic` synonym -> `^=` (case-insensitive equal); `@and` -> `&&`, `@or` -> `\|\|`, `@re` -> regex, `@feq` -> fuzzy-eq | `Expression.java:45-62` | herald uses case-sensitive `is_contained_by` / `not_equal_to` everywhere. CG0175's P21 rule SD1045 uses `@eqic` on `IECAT`; herald is strict. A single-rule case-insensitive deviation -- acceptable since CDISC terminology is uppercase-standard. |
| P21 splits one CDISC rule across multiple XML rules when the `in (...)` can't be expressed compactly | CG0444 -> SD2241, SD2242, SD2256 (one per TSPARMCD value) | herald keeps the single `in`-set form via `is_contained_by`. One check_tree, one rule, reviewer gets one finding -- simpler. |
| P21 adds implicit `@and TSVALNF == ''` guard to TS-rules (only validate when null-flavor isn't explaining the missing TSVAL) | SD2241/2242/2243/2256 `When="... @and TSVALNF == ''"` | CDISC narrative doesn't mention TSVALNF; herald follows CDISC text literally. Consequence: herald may fire a false positive when TSVALNF is populated to explain absence. Downstream reviewers can filter these findings. **Known deviation.** |
| P21 may permit additional values not in CDISC narrative (e.g. `'MED-RT' @or 'NDF-RT'` for PCLAS, where CDISC says only `'NDF-RT'`) | SD2243 | herald follows CDISC narrative (only `'NDF-RT'` for CG0455). P21 has loosened its rule in config updates; CDISC conformance-rules doc has not caught up. **Known deviation.** |
| P21 checks standardized forms where CDISC narrative says original (e.g. CG0175 `Test="IESTRESC == 'Y'"` vs CDISC `IEORRES = 'Y'`) | SD1045/1046 | herald checks the CDISC-named column (IEORRES). Follows authoritative CDISC text, not P21's interpretation. **Known deviation** -- both behaviours are defensible; CDISC narrative wins per herald's authoring rule. |

### Null-target semantics (resolved)

Earlier drafts of this pattern documented a deviation where herald's
`not_equal_to` returned NA on a null target (P21 would fire). This
was fixed in `op_equal_to` / `op_equal_to_ci`: when the rhs is a
non-null literal, NA cells in the lhs column are now treated as
FALSE for the equality check. `not_equal_to` consequently returns
TRUE on null targets, matching P21's NullComparison path
(`DataEntryFactory.java:349` -- NullDataEntry.compareTo returns -1
vs non-null rhs -> `!=` evaluates true).

The fix applies only to the literal-compare branch
(`value_is_literal = TRUE`). Column-to-column compares still
propagate NA so paired-variable rules continue to emit advisories
when either side is missing (safer default for that shape).

## herald check_tree template

```yaml check_tree
all:
- operator: is_contained_by
  name: %cond_var%
  value: [%cond_values%]
- operator: not_equal_to
  name: %target_var%
  value: '%target_lit%'
```

Slots:
- `cond_var`     -- guard column
- `cond_values`  -- comma-separated YAML list content (quoted
  literals). For an eq-guard, a single quoted literal.
- `target_var`   -- the asserted column
- `target_lit`   -- the single required literal

## Expected outcome

- Positive: cond_var in set AND target_var != target_lit -> fires.
- Negative: cond_var in set AND target_var == target_lit -> compliant,
  no fire.
- Negative #2: cond_var not in set (guard blocks) -> no fire
  regardless of target value.

## Batch scope

7 rules:
- eq-guard (5): CG0065, CG0175, CG0176, CG0455, CG0456.
- in-set-guard (2): CG0444, CG0458.

All SDTMIG v3.2+, severity Medium, per-record row-level, no wildcard
or indexed expansion.

Deferred (26 rules in the `VAR = LIT` cluster): compound OR guards
(`AESCAN = 'Y' or AESCONG = 'Y' or ...`), compound AND guards
(`--PRESP = 'Y' and --OCCUR = null`), cross-dataset guards
(`SS.SSSTRESC = 'DEAD'`), natural-language guards (`Multiple records
in SUPPDM where RACE captured`). These need additional condition-
parsing support or dedicated cross-reference resolution.
