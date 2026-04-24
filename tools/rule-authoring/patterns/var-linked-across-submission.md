# var-linked-across-submission

## Intent

When a SDTM linking variable (e.g. `--LNKGRP`, `--LNKID`) is present in a
domain, it must also appear in at least one other domain in the same submission.
A linking variable that exists only in a single dataset cannot fulfil its
purpose of linking related records across domains.

The rule fires once per (rule x evaluated dataset) when:
1. The linking variable IS present in the current dataset (column exists).
2. The linking variable is NOT present in any other loaded dataset.

Canonical message form:
`<VAR> is present in <DOMAIN> but not in any other domain`

## CDISC source

SDTM-IG v3.2 / v3.3 / v3.4, Section 6.1 (Relating Records Within and Across
Domains). CG0022 (--LNKGRP) and CG0024 (--LNKID) are the two primary rules.

Cited guidance for CG0022:
  "Identifier used to link related, grouped records across domains."
Cited guidance for CG0024:
  "Identifier used to link related records across domains."

Both rules share scope: classes=ALL, domains=ALL.

## P21 conceptual parallel (reference only)

P21 does not encode CG0022 or CG0024 as machine-checkable predicates in its
published ruleset; they are described as narrative checks. Herald implements
the cross-domain scan via `op_var_present_in_any_other_dataset` which reads
`ctx$datasets` at submission scope.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| Cross-domain checks run at submission level | `op_var_present_in_any_other_dataset` iterates all `ctx$datasets` except the current one |
| Absent domain list -> no check | When `ctx$datasets` is empty the op returns NA (advisory); rule is surfaced as skipped_refs |
| Column comparison is case-insensitive | `toupper(names(ds))` vs `toupper(col)` |
| Fires at most once per (rule x dataset) | Both `exists` and `var_present_in_any_other_dataset` use `.dataset_level_mask`; `not:` wrapper inverts |

## herald check_tree template

Slots: `var` (the column name as it appears in the dataset, e.g. `AELNKGRP`
for the AE domain -- the `--` prefix expands to the domain code at authoring
time).

```yaml check_tree
all:
- operator: exists
  name: %var%
- not:
    operator: var_present_in_any_other_dataset
    name: %var%
```

## Expected outcome

- Positive fixture (rule fires): dataset has `VAR` but no other loaded dataset
  has `VAR`. `op_exists` returns TRUE; `op_var_present_in_any_other_dataset`
  returns FALSE; `not:` inverts to TRUE -> overall TRUE -> rule fires.
- Negative fixture (rule passes): at least one other loaded dataset also has
  `VAR`. `op_var_present_in_any_other_dataset` returns TRUE; `not:` inverts to
  FALSE -> overall FALSE -> rule does not fire.

## Batch scope

2 rules: CG0022 (--LNKGRP, expanded to domain-specific column names per
submission), CG0024 (--LNKID, same expansion). Both scope ALL classes / ALL
domains.
