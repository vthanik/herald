# value-conditional-populated

## Intent

Two variables are paired such that populating one implies the
other must be populated too. The rule fires row-by-row when
`VAR_A` carries a value but `VAR_B` doesn't. Active-voice message;
the violation is directly described.

Two surface forms appear in the catalog:

- `<A> is populated and <B> is not populated`
- `On a given record, <A> is populated and <B> is not populated`

The "On a given record," prefix is prose emphasising per-row
evaluation; semantically identical to the bare form. 84 rules
total, all ADaM-IG (most BDS, some ADSL / OCCDS).

Examples:
- `ARELTM is populated and ARELTMU is not populated` (time
  variable needs its unit)
- `AWTDIFF is populated and AWTARGET is not populated` (analysis
  window diff needs its target)
- `BTOXGRL is populated and BTOXGRLN is not populated` (character
  toxicity grade needs its numeric equivalent)

## CDISC source

ADaMIG Section 3, "Related Variables" patterns. When a derived
variable has a paired character/numeric representation or a paired
unit, ADaMIG requires that populating one implies populating the
other.

## P21 conceptual parallel (reference only)

P21's `val:Condition` with `Test="<A> == ''"` guarded by
`When="<B> != ''"` implements the same concept (record-level):
fire when the When clause is satisfied AND the Test passes. In
herald we compose the two conditions as an `{all}` of row-level
leaves. Both approaches produce one finding per violating row.

## herald check_tree template

```yaml check_tree
all:
- name: %var_a%
  operator: non_empty
- name: %var_b%
  operator: empty
```

- `non_empty(A)` fires (TRUE) on rows where A has a value.
- `empty(B)` fires (TRUE) on rows where B is null/empty.
- `{all}` fires per row where BOTH conditions hold -- i.e. A is
  populated but B isn't.

Uses the same P21-compat null-check (rtrim then `nzchar`) as
`value-not-null` / `presence-pair`.

## Expected outcome

- Positive fixture: one row where A is "X" and B is "" -> 1 fire.
- Negative fixture: row where both are populated (no violation) OR
  row where both are empty (also no violation since A not populated).
- `provenance.executability` -> `predicate`.

## Scope

All 84 rules are ADaM-IG; the scope.classes field in each YAML
(BASIC DATA STRUCTURE, SUBJECT LEVEL ANALYSIS DATASET, OCCURRENCE
DATA STRUCTURE) is respected by herald's scope filter.
