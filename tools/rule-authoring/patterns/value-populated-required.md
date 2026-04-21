# value-populated-required

## Intent

*"`<VAR>` must be populated on every record"*. Fires per record
when the variable is null/empty. Row-level equivalent of
`presence-required` (which checks column presence at dataset-level).

Canonical message form: `<VAR> is not populated`

## CDISC source

ADaMIG Section 3 CORE=Req row-level requirements: PARAM (196) and
PARAMCD (197) in BDS must be populated on every record. Applies
across all subjects and all parameters.

## P21 conceptual parallel (reference only)

P21 uses `val:Required Variable=X` with no `When=` (unconditional):

```
val:Required Variable="PARAMCD"
```

Semantics: for each record, `entry.hasValue()` must be true. Fails
when the cell is null/empty (`ConditionalRequiredValidationRule.java:47-55`
evaluates `entry.hasValue() ? 1 : 0`).

herald uses a single-leaf `op_empty` check that fires per row when
the cell is null/empty/whitespace-only (post-rtrim).

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `hasValue()` post-rtrim null | `DataEntryFactory.java:242-244,313-328` | `op_empty` rtrims + `nzchar` test; `""`, NA, `"   "` all count as empty. Matches. |
| Numeric NA -> hasValue false | NullDataEntry | R: `is.na(values)` covers both character and numeric NA. Matches. |
| Missing column -> `CorruptRuleException` | `AbstractValidationRule.java:148-161` | `op_empty` on missing column returns NA mask -> per-dataset advisory. More transparent. |
| `Optional=VAR` attribute -> skip when missing | parser | herald's NA-advisory gives the same no-fire outcome. |

## herald check_tree template

```yaml check_tree
operator: empty
name: %var%
```

Single-leaf row-level check. Fires on every row where `<var>` is
null/empty.

## Expected outcome

- Positive: any record with `<var>` null -> fires on that row.
- Negative: every record has `<var>` populated -> no fire.

## Batch scope

2 rules:
- ADaM-196: PARAM is not populated
- ADaM-197: PARAMCD is not populated

Both BDS-scoped (every record must carry non-null PARAM/PARAMCD).
