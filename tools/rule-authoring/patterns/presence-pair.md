# presence-pair

## Intent

CDISC requires that when a "secondary" variable is included in an ADaM
dataset, its corresponding "primary" partner must also be included. This
is a metadata-level check (on the dataset's column list, not on row
values): the rule fires once per (rule × dataset) when the secondary is
present and the primary is missing.

Canonical message form:
`<VAR_A> is present and <VAR_B> is not present`

## CDISC source

Rule messages derive from ADaMIG section 3 (Standard Variables for
Subject-Level Analysis and Basic Data Structure Analysis). The cited
guidance in each YAML's `provenance.cited_guidance` is authoritative --
each rule's YAML links the exact section. See ADaM-111 (`ARELTM` →
`ARELTMU`) for an in-package worked example already converted.

## P21 conceptual parallel (reference only)

P21's `val:Find` primitive with `Target="Metadata"` implements the same
concept by iterating the dataset's variable list: when the current
variable matches `If="VARIABLE == '<VAR_A>'"` it asserts
`Terms="<VAR_B>"` is also in the list. We re-express this in herald's
operator vocabulary independently; no XML expression is copied.

## herald check_tree template

The template below uses two slots -- `VAR_A` (secondary; must be
present) and `VAR_B` (primary; must also be present). `apply-pattern.R`
substitutes them per rule from the `.ids` CSV.

```yaml check_tree
all:
- name: %var_a%
  operator: exists
- name: %var_b%
  operator: not_exists
```

Both leaves are `.METADATA_OPS` (registered in
`R/rules-validate.R::.METADATA_OPS`), so the walker's metadata-rule
collapse (`f893376`) fires the rule once per (rule × dataset) even
though each leaf mask is length `nrow(data)`. No per-row over-fire.

## Expected outcome

- Positive fixture: dataset has `VAR_A` column, lacks `VAR_B` → fires 1×.
- Negative fixture: dataset has both `VAR_A` and `VAR_B` → fires 0×.
- `provenance.executability` → `predicate`.

## Batch 1 scope

- 52 of 58 matching rules are parseable with literal variable names.
- 6 rules with `xx`/`y` indexing (e.g. `TRTxxAN`/`TRTxxA`) are deferred
  to a follow-up batch pending an `xx`-expansion helper.

## Fixture strategy

`../fixtures/presence-pair/pos.json` is a BASIC DATA STRUCTURE (BDS)
dataset that contains *every* `VAR_A` from the 52 rules and *none* of
the corresponding `VAR_B`s. Each rule sees its `VAR_A` present and
`VAR_B` absent → fires.

`neg.json` contains every `VAR_A` AND every `VAR_B` → no rule fires.

Both fixtures declare `spec.class_map: {ADVS: BASIC DATA STRUCTURE}` so
the scope filter admits the ADaMIG BDS-scoped rules.
