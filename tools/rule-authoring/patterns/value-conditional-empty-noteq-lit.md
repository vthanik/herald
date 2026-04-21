# value-conditional-empty-noteq-lit

## Intent

*"When `<COND_VAR>` is null, `<TARGET_VAR>` must NOT equal
`<TARGET_LIT>`"*. Null-guard + reject-specific-value assertion. Fires
when the guard variable is empty AND the target equals the forbidden
literal.

Canonical message form: `<TARGET_VAR> ^= '<TARGET_LIT>'`
Canonical condition:    `<COND_VAR> = null`

## CDISC source

SDTMIG v3.2+: Trial Elements consistency -- when an element doesn't
carry an unplanned-description (SEUPDES null), its ETCD cannot equal
`'UNPLAN'` because the element is a planned one (CG0210).

## P21 conceptual parallel (reference only)

P21 SD1266 (`PublisherID="CG0210"`):

```
val:Condition
  Test="ETCD != 'UNPLAN'"
  When="SEUPDES == ''"
  Optional="SEUPDES"
```

P21 semantic: when SEUPDES is empty, Test must pass (ETCD != UNPLAN).
Fails when guard met AND Test fails (ETCD == UNPLAN). Herald
re-expresses as `{all: [empty(cond), equal_to(target, 'lit')]}` where
`{all}` TRUE (violation) when guard holds AND target IS the forbidden
literal. No XML/DSL copy.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `== ''` post-rtrim null | `DataEntryFactory.java:313-328` + `Comparison.NullComparison` | `op_empty` rtrims + `nzchar`. Matches. |
| `!= 'UNPLAN'` with null lhs -> NullDataEntry.compareTo returns -1 -> `!=` true -> rule PASSES (no fire on null target) | `DataEntryFactory.java:349-357` + `Comparison.java:160-207` | `op_equal_to` on NA with non-null literal returns FALSE (after our recent NullComparison-parity fix). Under `{all: [empty, equal_to]}`, NA target -> equal_to=FALSE -> {all}=FALSE -> no fire. **Matches P21.** |
| `Optional="SEUPDES"` -- skip when SEUPDES column missing | P21 `RuleDefinition.Optional` | `op_empty` on missing column returns NA -> `{all}` NA -> advisory. Functional equivalent. |
| Case-sensitive literal match default | `Comparison.java:194-205` | R's `==` is case-sensitive. Matches. |

## herald check_tree template

```yaml check_tree
all:
- operator: empty
  name: %cond_var%
- operator: equal_to
  name: %target_var%
  value: '%target_lit%'
```

## Expected outcome

- Positive: cond_var null AND target_var == target_lit -> fires.
- Negative: cond_var populated (guard blocks) OR target_var != lit
  (no violation) -> no fire.

## Batch scope

1 rule: CG0210 (ETCD != 'UNPLAN' when SEUPDES null).
