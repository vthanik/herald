# value-conditional-null-eq

## Intent

A record-level rule of the form *"when `<COND_VAR>` equals `<LIT>`,
`<TARGET_VAR>` must be null"*. Sister to `value-conditional-populated`
(same shape at the leaf level but inverted assertion). Fires when the
equality guard holds AND the target is populated.

Canonical message form: `<TARGET_VAR> = null`
Canonical condition:   `<COND_VAR> = '<LIT>'`

## CDISC source

SDTMIG v3.2+: rules on DS epoch, TE element code, TA ETCD gating of
ordering / epoch. The `check.condition` field carries the guard in
SAS-like DSL; `outcome.message` is the naked assertion.

## P21 conceptual parallel (reference only)

P21 implements via `val:Condition When="%COND_VAR% == '<LIT>'"
Test="%TARGET_VAR% == ''"` (ConditionalValidationRule.java:42-48).
The When-clause short-circuits skip (-1) when false; otherwise the
Test must be true for the record to pass. herald re-expresses as
`{all: [equal_to(cond_var, lit), non_empty(target_var)]}` where the
`{all}` TRUE == violation. No XML or DSL copy.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `When` clause references a null lhs -> `NullComparison.evaluate` returns false -> skip record | `Comparison.java:92-108` | `op_equal_to` on NA returns `NA`; under `{all}` NA propagates -> advisory. When cond_var is null, herald emits advisory rather than silently skipping -- more transparent. |
| rtrim-null applies to both lhs and rhs before string compare | `DataEntryFactory.java:69-79,313-328` | `op_equal_to` -> `.coerce_compare` -> character compare; trailing whitespace on the cell is trimmed at fixture load / XPT ingest (SasTransportDataSource.java:184,287). Matches P21. |
| Case-sensitive equality by default | `Comparison.java:194-205` (no ignore-case flag) | `op_equal_to` uses R's case-sensitive `==`. Matches P21. |
| Missing target column -> `CorruptRuleException` (rule disabled) | `AbstractValidationRule.java:148-161` | `op_non_empty` on a missing column returns NA mask -> advisory. More transparent. |
| Value of literal with trailing space inside quotes (e.g. `'PROTOCOL MILESTONE '`) | parsing literal strip only the quotes | herald stores the literal verbatim; authors should avoid trailing spaces. |
| **P21 combines `--STRF`/`--ENRF` under a single Test with AND** (SD1042: `Test="%Domain%STRF == '' @and %Domain%ENRF == ''"`) | XML: SD1042 (CG0420/421) | Herald splits CG0420 and CG0421 into separate rules; each fires independently per violating column. Reviewer gets granular findings. |
| **`Optional=VAR` on declared columns** -- P21 skips the rule when listed columns are missing from the dataset | P21 `RuleDefinition.Optional` parser | Herald returns NA mask on missing columns; under `{all}` collapses to NA -> advisory. Functional equivalent. |
| **P21 uses `Optional=--OCCUR, --PRESP`** on SD0041/0042/1042 to skip when either column is missing | same | Same -- advisory-on-NA. |

## herald check_tree template

```yaml check_tree
all:
- operator: equal_to
  name: %cond_var%
  value: '%cond_lit%'
- operator: non_empty
  name: %target_var%
```

Slots:
- `cond_var`    -- the guard column
- `cond_lit`    -- the literal the guard compares against (single-quoted
  to preserve strings like `PROTOCOL MILESTONE`)
- `target_var`  -- column whose populated value is the violation

## Expected outcome

- Positive: cond_var == lit AND target_var populated -> fires 1x.
- Negative: cond_var == lit AND target_var empty -> fires 0x.
- Negative #2: cond_var != lit (guard blocks) -> fires 0x regardless.

## Batch scope

3 rules: CG0073 (DSCAT='PROTOCOL MILESTONE' -> EPOCH=null),
CG0152 (ETCD='UNPLAN' -> ELEMENT=null), CG0206 (ETCD='UNPLAN' ->
TAETORD=null).
