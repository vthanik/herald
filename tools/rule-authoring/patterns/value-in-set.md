# value-in-set

## Intent

*"`<VAR>` must be in a controlled set of literals (plus null)"*. Row
fires when the variable is populated with a value NOT in the allowed
set. Null is implicitly allowed (matches CDISC's `in ('Y', null)`
shorthand).

Canonical message form: `<VAR> in ('<LIT_1>', '<LIT_2>', ...)` or
`<VAR> in ('<LIT_1>', null)`.

## CDISC source

SDTMIG v3.2+ non-extensible codelist subsets. CG0085 asserts
`--PRESP in ('Y', null)`; CG0131 asserts `DTHFL in ('Y', null)`.

## P21 conceptual parallel (reference only)

P21 uses `val:Match` with `Variable=<VAR>`, `Terms=<allowed>`,
`Delimiter=,`. Example (CG0085 via
`%Variables.Config.CodeList.Extensible:N%`):

```
val:Match
  Variable = %Variables.Config.CodeList.Extensible:N%
  Terms    = %Variable.Config.CodeList.Values%
  Delimiter= %Variable.Config.CodeList.Delimiter%
```

P21 resolves the Variable and Terms from its embedded CT codelists
at rule compile time. herald expresses the same via explicit
`is_not_contained_by` with the set of allowed literals, authored
per-rule.

## P21 edge-case audit (FindValidationRule.java:181-225)

| P21 behaviour | Source | herald decision |
|---|---|---|
| `val:Match` with `Terms` iterates the variable values against the allowed set; fires when a value isn't in the set | `FindValidationRule.java:208-222` | `op_is_not_contained_by` returns TRUE when the cell value is not in the set. Matches. |
| rtrim-null on the cell value before set-membership check | `DataEntryFactory.java:313-328` | `op_is_contained_by` rtrims via `sub("\\s+$","",raw)` + nzchar; all-whitespace or empty cells return NA. Matches. |
| Null / empty cell -> `hasValue() == false` -> rule passes (treats null as allowed) | `FindValidationRule.java:208` | `op_is_not_contained_by` returns NA on missing; under a single leaf, NA -> advisory per rule-dataset (not per row). **Matches CDISC's "null allowed" semantic.** |
| `CaseSensitive="Yes"` default | `FindValidationRule.java:91-96` | herald's `%in%` is case-sensitive. CDISC CT values uppercase. Matches. |
| Multi-word values with spaces in Terms (`'Screen Failure'`) | P21 parses quoted tokens | herald accepts multi-word strings in value list verbatim. Matches. |
| Missing column | `val:Required` precondition | `op_is_not_contained_by` returns NA on missing column -> advisory. Matches. |

## herald check_tree template

```yaml check_tree
operator: is_not_contained_by
name: %var%
value: [%allowed%]
```

Slot `allowed` is a comma-separated quoted literal list that
renders inside a YAML `[...]` sequence (e.g. `'Y'` for a single
allowed literal).

## Expected outcome

- Positive: variable populated with a value NOT in allowed set ->
  fires.
- Negative: variable in allowed set OR null -> no fire.

## Batch scope

2 rules: CG0085 (`--PRESP in ('Y', null)`),
CG0131 (`DTHFL in ('Y', null)`).
