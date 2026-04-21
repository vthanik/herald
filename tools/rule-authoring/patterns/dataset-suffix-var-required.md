# dataset-suffix-var-required

## Intent

*"A variable with a suffix of `<SUFFIX>` is not present in
`<DATASET>`"*. Fires once per (rule x dataset) when the
suffix-scoped dataset contains no column whose name ends in the
required suffix.

Canonical message form:
`A variable with a suffix of <SUFFIX> is not present in <DATASET>`

## CDISC source

ADaMIG v1.0 Section 3.1. ADSL must carry at least one flag variable
(suffix `FL`) signalling analysis-population membership (SAFFL,
ITTFL, PPROTFL, etc.).

- ADaM-48: suffix `FL` required in ADSL.

## P21 conceptual parallel (reference only)

P21's `val:Find Variable = VARIABLE Terms = "*FL" MatchExact = No
Target = Metadata` iterates the dataset's variable list and fires
when no column name matches the wildcard. herald's op consumes the
`endsWith()` directly on `toupper(names(data))`.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Wildcard case-insensitive | `Pattern.CASE_INSENSITIVE` | `toupper()` both sides. Matches. |
| Empty dataset still checked | Block-level evaluation | herald runs against the column list, unaffected by row count. Matches. |
| Suffix absent -> rule-disable | `Pattern.compile` throws | herald's op returns FALSE when `suffix = ""` (no fire, no advisory). Pragmatic. |

## herald check_tree template

```yaml check_tree
operator: no_var_with_suffix
suffix: %suffix%
```

Slots:
- `suffix` -- the required variable-name suffix (e.g. `FL`).

Scope is controlled at the rule level (e.g. `classes: SUBJECT LEVEL
ANALYSIS DATASET` for ADaM-48). The op itself is dataset-agnostic.

## Expected outcome

- Positive: no column in scope carries the suffix -> fires once.
- Negative: at least one column carries the suffix -> no fire.

## Batch scope

1 rule: ADaM-48 (`FL` suffix in ADSL).
