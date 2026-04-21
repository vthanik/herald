# value-conditional-populated-eq-lit

## Intent

*"When `<COND_VAR>` is populated, `<TARGET_VAR>` must equal
`<TARGET_LIT>`"*. Populated-guard version of
`value-conditional-literal-assert`: instead of `VAR in (set)` the
guard is `VAR ^= null` (SAS DSL for "not null").

Canonical message form: `<TARGET_VAR> = '<TARGET_LIT>'`
Canonical condition:    `<COND_VAR> ^= null`

## CDISC source

SDTMIG v3.2+: `--PRESP` pre-specification under `--OCCUR ^= null`
(CG0089); DM death-flag under `DTHDTC ^= null` (CG0435); SV response
under `SVOCCUR ^= null` (CG0654). The guard signals that the event
was observed / pre-specified, so the target must carry its
canonical value.

## P21 conceptual parallel (reference only)

P21: `val:Condition When="%COND_VAR% != ''" Test="%TARGET_VAR% == '<LIT>'"`
(ConditionalValidationRule.java:42-48). When the guard passes, Test
must be true. herald re-expresses as
`{all: [non_empty(cond_var), not_equal_to(target, '<lit>')]}` -- the
`{all}` fires when guard is met AND target differs from the literal.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `hasValue()` post-rtrim on the guard | `DataEntryFactory.java:242-244,313-328` | `op_non_empty` rtrims and `nzchar`-tests; `"   "` is null, `"X "` populated. Matches. |
| `== 'LIT'` compared after rtrim of both sides | `DataEntryFactory.create` + `Comparison` | XPT rtrims at ingest; `op_equal_to` compares trimmed strings. Matches. |
| `== '<LIT>'` with NULL_ENTRY lhs -> NullDataEntry.compareToAny returns -1 -> `==` false -> `!=` true -> rule fires on null target | `DataEntryFactory.java:349-357` + `Comparison.java:160-207` | After our recent fix to `op_equal_to` (ops-compare.R: NA vs non-null literal -> FALSE), `not_equal_to(NA, 'LIT')` returns TRUE -> fires. **Matches P21.** |
| Case-sensitive literal comparison default | `Comparison.java:194-205` | R's `==` is case-sensitive. Matches. |
| Missing target column -> `CorruptRuleException` | `AbstractValidationRule.java:148-161` | `op_not_equal_to` on missing column returns NA -> advisory. More transparent. |
| `When=` false (guard null) -> skip record | `ConditionalValidationRule.java:47` | `non_empty(cond_var) = FALSE` on null guard -> `{all}` = FALSE -> no fire. Matches. |
| **P21 writes the rule as CONTRAPOSITIVE of CDISC narrative** -- e.g. SD0034 (CG0008) targets `Variable=%Domain%TPTREF When=%Domain%ELTM != ''` (populated-ELTM -> required-TPTREF); CDISC narrative says `TPTREF = null -> ELTM = null`. Logically equivalent biconditional. | XML: SD0034; Java: `RequiredValidationRule.java` `performValidation` | Herald follows CDISC narrative direction. When P21 uses contrapositive, the firing record set is the same. No functional deviation. |
| **P21 combines several CDISC rules into one XML `val:Condition`** via `@or` / `@and` chains (e.g. SD0041 combines CG0086/087/089/654). Message lists the combined scope. | `AbstractScriptableValidationRule` + XML rule | Herald maps 1:1 per CDISC rule id. Each YAML becomes its own check_tree, each fire is its own finding. **More granular** than P21 by design (one finding per CDISC rule per dataset per row). |
| **P21 combines `--STRF` and `--ENRF` checks into one Test** (`SD1042: Test="%Domain%STRF == '' @and %Domain%ENRF == ''"`) with `Optional="%Domain%STRF, %Domain%ENRF"` | XML: SD1042 | Herald splits into CG0420 (STRF) and CG0421 (ENRF), each with its own `non_empty` leaf. A record with STRF populated but ENRF null fires only CG0420 -- reviewer sees the exact violating variable. P21 fires both messages for the same record. |
| `Optional=VAR` attribute -- when the listed column is missing, P21 skips the rule | P21 `RuleDefinition.Optional` parser | Herald returns NA mask on a missing column for every op; under `{all}` this collapses to NA -> one advisory per (rule x dataset). Functional equivalent. |

## herald check_tree template

```yaml check_tree
all:
- operator: non_empty
  name: %cond_var%
- operator: not_equal_to
  name: %target_var%
  value: '%target_lit%'
```

## Expected outcome

- Positive: cond_var populated AND target_var != target_lit (or null
  after our P21 fix) -> fires.
- Negative: cond_var populated AND target_var == target_lit -> no
  fire.
- Negative #2: cond_var null (guard blocks) -> no fire regardless.

## Batch scope

3 rules: CG0089 (--PRESP='Y' when --OCCUR populated),
CG0435 (DTHFL='Y' when DTHDTC populated), CG0654 (SVPRESP='Y' when
SVOCCUR populated).
