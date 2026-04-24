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

## P21 edge-case audit (FindValidationRule.java)

| P21 behaviour | File:line | herald |
|---|---|---|
| Variable name `.toUpperCase()` at rule init | `FindValidationRule.java:57` | Walker uppercases `name` on `names(data)` lookup (rules-walk.R:156-163). ✓ |
| `CaseSensitive="Yes"` default on `Terms` match | `FindValidationRule.java:91-96` (default `isCaseSensitive = true`) | herald's `%in% names(data)` is case-sensitive; case-insensitive fallback at walker layer matches P21's case-sensitive default when uppercased. ✓ |
| `MatchExact="No"` allows `counter - matchCount < terms.size()` (partial counting) | `FindValidationRule.java:235-243` | herald's `exists` / `not_exists` is binary `%in%` -- effectively "at least one" matches P21's `MatchExact="No"` with `matchCount=0`. Equivalent for our use. |
| `When=` / `If=` optional activation | `FindValidationRule.java:174-176, 198-204` | Our `{all}` combinator with an `exists(var_a)` guard leaf achieves the same conditional activation (rule fires per-dataset when var_a is in the column list). |
| Per-dataset `Outcome` (one finding per violated dataset) | `FindValidationRule.java:227-259` | `.is_metadata_rule` collapse in R/rules-validate.R fires once per (rule x dataset). ✓ |
| `entry.hasValue()` check before processing | `FindValidationRule.java:208` | Metadata iteration in herald inspects `names(data)` which contains only named columns -- no equivalent "null column name" case. ✓ |

## Scope extension: SDTM-IG column-presence rules

Originally authored for ADaM-IG paired-variable rules, the template
also fits the SDTM-IG "when `<cond_var>` is present in dataset,
`<target_var>` must be present" shape -- same check tree
(`exists(cond_var) AND not_exists(target_var)` = violation). Added
11 SDTMIG rules (CG0057, 058, 060, 062, 090, 091, 092, 430, 468,
503, 661) that follow this metadata-conditional-presence pattern.
`--VAR` in slot values is expanded by the walker at runtime per
the dataset's domain prefix (`rules-walk.R:143-147`).

## herald check_tree template

The template below uses two slots -- `VAR_A` (secondary; must be
present) and `VAR_B` (primary; must also be present). `apply-pattern.R`
substitutes them per rule from the `.ids` CSV.

```yaml check_tree
expand: "%expand%"
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

## Batch 1 scope (complete)

All 58 matching rules converted:

- **52 concrete** rules with literal variable names (ARELTMU/ARELTM,
  BTOXGR/ATOXGR, ...). Template substitutes `%var_a%` / `%var_b%`
  from `presence-pair.ids`.
- **6 xx/y-indexed** rules (`ADaM-64, 75, 80, 97, 201, 559` --
  `TRTxxAN`/`TRTxxA`, `TRTPGyN`/`TRTPGy`, etc.). Each carries an
  `expand:` key (`xx` or `y`) that the engine's
  `R/index-expand.R::.expand_indexed()` walks at validate time
  against the dataset's actual columns, instantiating one
  `{all: [exists(...), not_exists(...)]}` sub-tree per concrete
  index value found, all wrapped under `{any}`.

`presence-pair.ids` carries a 4th column `expand` -- empty for the
52 concrete rules and `xx` / `y` for the 6 indexed ones. The
template below covers both cases: when `%expand%` is empty, the
`expand:` key collapses away at render time and the tree is a
plain `{all: [exists, not_exists]}`; when `%expand%` is populated,
the `expand:` key carries through and the engine handles per-index
expansion.

## Fixture strategy

`../fixtures/presence-pair/pos.json` is a BASIC DATA STRUCTURE (BDS)
dataset that contains *every* `VAR_A` from the 52 rules and *none* of
the corresponding `VAR_B`s. Each rule sees its `VAR_A` present and
`VAR_B` absent → fires.

`neg.json` contains every `VAR_A` AND every `VAR_B` → no rule fires.

Both fixtures declare `spec.class_map: {ADVS: BASIC DATA STRUCTURE}` so
the scope filter admits the ADaMIG BDS-scoped rules.
