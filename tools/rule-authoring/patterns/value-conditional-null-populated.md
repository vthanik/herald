# value-conditional-null-populated

## Intent

A record-level rule of the form *"when `<COND_VAR>` is populated,
`<TARGET_VAR>` must be null"*. Common shape for paired variables
where only one may carry a value (e.g. `--DOSE` vs `--DOSTXT`, or
`USUBJID` vs `POOLID` in RELREC). Fires when both columns are
populated on the same record.

Canonical message form: `<TARGET_VAR> = null`
Canonical condition:   `<COND_VAR> ^= null`

## CDISC source

SDTMIG v3.2+: mutually-exclusive dose variables (CG0110/CG0111),
pool/subject mutually-exclusive (CG0361/362), SUPPQUAL mutual-
exclusion (CG0365/366), IE status vs original-result (CG0422),
treatment-timing anti-populated guards (CG0530).

## P21 conceptual parallel (reference only)

P21 uses `val:Condition When="%COND_VAR% != ''" Test="%TARGET_VAR%
== ''"` (ConditionalValidationRule.java:42-48). The When clause is
evaluated record-by-record; when true, the Test assertion decides
pass/fail. herald re-expresses as `{all: [non_empty(cond_var),
non_empty(target_var)]}` -- both populated on the same record = the
violation shape. No XML or DSL copy.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `hasValue()` is `value != null` **after** `DataEntryFactory.create()` rtrims trailing spaces and collapses all-space strings to null | `DataEntryFactory.java:242-244,313-328` | `op_non_empty` rtrims (`sub("\\s+$","",x)`) then tests `nzchar`; `"   "` is null, `"X "` is populated, `"0"` and `"null"` literals are populated. Matches P21. |
| When lhs/rhs of `!=` compare includes rtrim-null semantics (empty == null) | `Comparison.java` + NullDataEntry | herald's `non_empty` returns FALSE on NA / empty / all-spaces, same truth-table. |
| Variable name `.toUpperCase()` at rule init | `ConditionalValidationRule` via `AbstractScriptableValidationRule` | `rules-walk.R:156-163` case-insensitively resolves `name` against `names(data)` before op dispatch. Matches. |
| Missing either column -> `CorruptRuleException` disables rule silently | `AbstractValidationRule.java:148-161` | `op_non_empty` on missing column returns NA mask -> `{all}` NA -> advisory per (rule x dataset). More transparent. |
| Numeric column treatment | `DataEntryImpl.hasValue()` for numeric is always true unless NULL_ENTRY | herald's `op_non_empty` on numeric: `!is.na(values)` -- populated by presence, no coercion. Numeric `0` stays populated. Matches. |

## herald check_tree template

```yaml check_tree
all:
- operator: non_empty
  name: %cond_var%
- operator: non_empty
  name: %target_var%
```

Slots:
- `cond_var`    -- guard column, must be populated to enable the check
- `target_var`  -- column whose populated value (co-populated with
  cond_var) is the violation

## Expected outcome

- Positive: both cond_var and target_var populated on one record ->
  fires 1x.
- Negative: either empty on every record -> fires 0x.

## Batch scope

9 rules converted: CG0110, CG0111, CG0168, CG0216, CG0260, CG0361,
CG0362, CG0422, CG0530.

Deferred: CG0365, CG0366 -- scope class = AP (Associated Persons).
herald's taxonomy doesn't yet carry AP as a first-class scope (the
AP-prefixed SDTM domains inherit parent-class classifications
instead). Same deferral as CG0156/157/158 in the earlier cross-lookup
pattern.
