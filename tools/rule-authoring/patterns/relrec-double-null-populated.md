# relrec-double-null-populated

## Intent

A record-level rule of the form *"when `<GUARD_A>` is null AND `<GUARD_B>` is
null, `<TARGET>` must be populated"*. The rule fires when both guard variables
are empty on the same row and the target variable is also empty -- i.e., the
two null guards are both satisfied but the required field is missing.

Canonical CDISC message form: `<TARGET> = null`
Canonical condition: `<GUARD_A> = null and <GUARD_B> = null`

## CDISC source

SDTMIG-AP Guide v1.0 section 2.1.1 covering Associated Persons (AP) domains.
CG0162: when RSUBJID and RDEVID are both null, the SREL variable must be
populated because it describes the relationship of the associated person to
the study (identified by STUDYID). SREL is always required in AP observations;
the condition narrows the semantic scope.

## P21 conceptual parallel (reference only)

P21 would express this as a compound `val:Condition` with two When-clauses
joined by `@and`, each testing for empty: `When="RSUBJID == '' @and RDEVID ==
''"` and `Test="SREL == ''"`. Herald re-expresses as an `{all}` of three
leaves -- two `empty` guards plus one `empty` target -- which is semantically
identical. No XML or DSL copy.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| Null / rtrim-empty cells fail `hasValue()` | `op_empty` rtrims then tests `!nzchar`; blank strings and NA both count as empty. Matches P21. |
| Missing column -> CorruptRuleException, rule disabled | Missing column returns NA mask from `op_empty` -> `{all}` -> advisory. More transparent than P21's silent disable. |
| Numeric zero -> populated (hasValue = true) | `op_empty` on numeric: `is.na(x)` -- NA = empty, 0 = populated. Matches. |

## herald check_tree template

```yaml check_tree
all:
- operator: empty
  name: %guard_a%
- operator: empty
  name: %guard_b%
- operator: empty
  name: %target%
```

Slots:
- `guard_a` -- first null guard (must be empty to enable the check)
- `guard_b` -- second null guard (must be empty to enable the check)
- `target`  -- column that must be populated when both guards are null

## Expected outcome

- Positive fixture: guard_a=null, guard_b=null, target=null -> fires 1x.
- Negative fixture: guard_a or guard_b populated -> does not fire (condition
  not satisfied). Also negative: all three populated -> no fire.
- `provenance.executability` -> `predicate`.

## Batch scope

1 rule: CG0162 (SREL must be populated when RSUBJID=null and RDEVID=null).
Scope class: AP (Associated Persons, SDTMIG-AP). Rule applies to AP-prefixed
SDTM datasets (APAE, APMH, APDM, etc.).
