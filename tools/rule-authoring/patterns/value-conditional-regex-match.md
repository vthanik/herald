# value-conditional-regex-match

## Intent

A record-level rule of the form *"when `<COND_VAR_1>` AND `<COND_VAR_2>`
are both null, `<TARGET_VAR>` must not match `<PATTERN>`"*. Compound
null-guard combined with a regex assertion on a separate column.

Canonical message form: `<TARGET_VAR> ^= <VAR_REFERENCE>`
(CDISC user DSL shorthand; the `<VAR_REFERENCE>` stands for a family
of variable names represented by the regex.)

## CDISC source

SDTMIG v3.2+ section 8.3.1 covers RELREC usage for dataset-level
relationships. When `USUBJID` and `IDVARVAL` are both null, the
`RELREC` row relates entire datasets rather than individual records;
in that mode `IDVAR` cannot name a record-level qualifier like
`--SEQ` (which is only meaningful within a subject within a domain).
CG0201 is the sole in-scope rule at present.

## P21 conceptual parallel (reference only)

P21's SD1264 (`PublisherID="CG0201"`) uses a single `val:Condition`
with a compound `When=` clause and a regex `Test=`:

```
Test="!(IDVAR @re '.*SEQ')"
When="IDVARVAL == '' @and USUBJID == ''"
```

P21's `@re` compiles to a `Pattern.matcher(...).matches()` full-string
check (`RegularExpressionValidationRule.java:71`), and the `!(...)`
inverts the Test sense. herald re-expresses as a 3-leaf `{all}` where
the regex leaf is used in its natural polarity (TRUE on match =
violation), no negation wrapper needed. No XML/DSL copy.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `@re` compiles to `Pattern.matcher(...).matches()` -- full-string match | `RegularExpressionValidationRule.java:71` | herald's `.anchor_regex` wraps unanchored patterns (`.*SEQ` -> `^(?:.*SEQ)$`), matching P21's full-string semantic. |
| `@and` evaluates LHS, short-circuits if false | `Expression.java` && handling | `{all}` evaluates all leaves element-wise, then combines via `&` with NA-propagation. Row-level short-circuit isn't meaningful since we operate on masks, but the outcome matches. |
| `''` on a string column = rtrimmed null | `DataEntryFactory.java:69-79,313-328` | `op_empty` rtrims + `nzchar`: `""`, NA, and `"   "` all count as empty. Matches. |
| Negated Test `!(expr)` -- rule passes when the inner Test is FALSE | `ConditionalValidationRule` via `Expression` | herald uses the regex leaf directly (TRUE=match=violation) without negation. Equivalent outcome. |
| Missing column -> `CorruptRuleException` | `AbstractValidationRule.java:148-161` | Any leaf's missing-column returns NA -> `{all}` -> advisory. Safer than P21's silent disable. |
| Cross-class scope (`RELREC` isn't in P21's class taxonomy; P21 scopes via domain name directly) | `ItemGroupDef` config | herald's scope filter accepts the rule's declared class (`SPC`) against RELREC via the `pick_dataset_for_scope` class-fallback (smoke-check.R: when infer_class returns NA, use declared scope class). |

## herald check_tree template

```yaml check_tree
all:
- operator: empty
  name: %cond_var_1%
- operator: empty
  name: %cond_var_2%
- operator: matches_regex
  name: %target_var%
  value: '%pattern%'
```

Slots:
- `cond_var_1`, `cond_var_2` -- guard columns, both must be null
- `target_var` -- column whose value is regex-matched
- `pattern` -- PCRE fragment (herald anchors to full-string match)

## Expected outcome

- Positive: cond_var_1 and cond_var_2 both null AND target matches
  pattern -> fires on the matching row.
- Negative: any of the three conditions absent -> no fire.

## Batch scope

1 rule: CG0201 (`IDVAR ^= --SEQ` under `IDVARVAL = null AND
USUBJID = null`).
