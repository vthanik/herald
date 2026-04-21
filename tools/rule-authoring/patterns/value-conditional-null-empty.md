# value-conditional-null-empty

## Intent

A record-level rule of the form *"when `<COND_VAR>` is null,
`<TARGET_VAR>` must also be null"*. Sibling to
`value-conditional-null-populated`: this one asserts that the
target stays blank when the guard itself is blank (key-pair
consistency). Fires when cond_var is null BUT target_var is
populated -- a dangling qualifier value.

Canonical message form: `<TARGET_VAR> = null`
Canonical condition:   `<COND_VAR> = null`

## CDISC source

SDTMIG v3.2+: `--TPTREF` dependence (CG0008 / CG0026),
`--TRTV` dependence (CG0106 / CG0108), RELREC `RDOMAIN/IDVAR` pair
(CG0164 / CG0465), `ARMCD/ARM` + `ACTARMCD/ACTARM` code-label
pairing (CG0521 / CG0522), `SVPRESP` dependence (CG0658).

## P21 conceptual parallel (reference only)

P21 uses `val:Condition When="%COND_VAR% == ''" Test="%TARGET_VAR%
== ''"` (ConditionalValidationRule.java:42-48). The `==` null comparison
dispatches to `NullComparison.evaluate` (Comparison.java:92-108),
which treats `record.getValue(<var>)` as null when `hasValue() ==
false` (post-rtrim). herald re-expresses as
`{all: [empty(cond_var), non_empty(target_var)]}` -- cond-null AND
target-populated = violation. No XML or DSL copy.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `== null` dispatches to `NullComparison`, which checks `!entry.hasValue()` (post-rtrim) | `Comparison.java:92-108` + `DataEntryFactory.java:313-328` | `op_empty` rtrims trailing spaces before `nzchar`; `"   "`, `""`, `NA` all count as empty. Matches. |
| `When=` evaluating true runs the Test; Test fail -> record reported | `ConditionalValidationRule.java:47-48` | `{all: [empty, non_empty]}` TRUE only when cond empty AND target populated = P21's fail path. Matches. |
| rtrim on BOTH sides of the null check | `DataEntryFactory.create` applies to all string values on load | herald applies at op layer via `op_empty` / `op_non_empty`. Same net semantics. |
| Missing column -> `CorruptRuleException` rule disable | `AbstractValidationRule.java:148-161` | `op_empty` / `op_non_empty` on missing column return NA; `{all}` NA -> advisory. More transparent. |
| Numeric null vs character "" distinction | numeric `NULL_ENTRY` vs character `""` after rtrim | R: numeric NA is `NA_real_`, character NA is `NA_character_`; `op_empty` treats both uniformly (`is.na(...)` covers both). Matches. |
| Both sides null -> rule passes (no finding) | When true + Test true -> return 1 | `{all: [empty(cond)=TRUE, non_empty(target)=FALSE]}` = FALSE -> no fire. Correct. |
| cond_var null, target_var non-null -> Test fails -> finding emitted | return 0 | `{all: [empty=TRUE, non_empty=TRUE]}` = TRUE -> fires. Matches P21 fail path. |
| **P21 writes the rule as `val:Required` on the contrapositive direction** -- e.g. SD1361 (CG0521) `Test="ARMCD == '' @and ARM == ''" When="ARMCD == '' @or ARM == ''"` covers BOTH directions (ARMCD->ARM and ARM->ARMCD) in a single rule | XML: SD1361/1362 | Herald splits CG0521 (ARMCD null -> ARM null) and CG0522 (ACTARMCD null -> ACTARM null) as separate rules, each directional. Combined firing coverage matches P21's biconditional. |
| **P21 combines several CDISC rule ids** in one `val:Condition` via `PublisherID="CG0164, CG0166"` (SD1065) sharing the same When/Test | same | Herald maps 1:1 per CDISC id. Each YAML is a distinct rule. More granular findings. |
| **`val:Required` vs `val:Condition`** -- P21 emits `val:Required` for "when X, Y required" (SD0034, SD0036). Functionally equivalent to `val:Condition Test="Y != ''"`. | `RequiredValidationRule.java` vs `ConditionalValidationRule.java` | Herald uses the same `{all: [empty(guard), non_empty(target)]}` shape for both encodings; the two P21 encodings are semantic sugar over the same logic. |

## herald check_tree template

```yaml check_tree
all:
- operator: empty
  name: %cond_var%
- operator: non_empty
  name: %target_var%
```

Slots:
- `cond_var`    -- guard column, must be null to enable the check
- `target_var`  -- column whose populated value (alongside null
  cond_var) is the violation

## Expected outcome

- Positive: cond_var null AND target_var populated -> fires 1x.
- Negative: cond_var populated OR target_var null -> fires 0x.

## Batch scope

9 rules: CG0008, CG0026, CG0106, CG0108, CG0164, CG0465, CG0521,
CG0522, CG0658.
