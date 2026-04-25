# presence-required

## Intent

A specific variable MUST be present in the dataset. Mirror of
`presence-forbidden`: the message directly names the violation
(active voice), so the rule fires exactly when the column is
absent.

Canonical message form:
`<VAR> is not present`

Compared to patterns we've already shipped:

- `presence-forbidden` -- message is the COMPLIANT state
  (`"VAR not present in dataset"`); rule uses `exists` (TRUE = var
  is there when it shouldn't be).
- `presence-required` -- message is the VIOLATION (`"VAR is not
  present"`); rule uses `not_exists` (TRUE = var missing when it
  should be there).

All 39 candidates are ADaM-IG. These are the required variables per
ADaMIG section 3 (PARAM, PARAMCD, AVAL, AEDECOD, AEBODSYS, AESER,
CNSR, TRTEMFL, AESEQ, ...).

## CDISC source

ADaMIG Section 3 (Standard Variables). Each rule's YAML carries
`scope.classes` that restricts the check to the dataset class where
the variable is REQUIRED (BDS, OCCDS, ADSL). E.g., `PARAM is not
present` applies only to BDS datasets; `AEDECOD is not present`
applies only to OCCDS (specifically the AE-derived ADAE).

## P21 conceptual parallel (reference only)

P21's `val:Required` with `Target="Metadata"` implements the same
concept: assert that the named variable is present in the column
list. herald's `not_exists` under the metadata-rule collapse
(`R/rules-validate.R::.is_metadata_rule`) fires once per
(rule x dataset). No row iteration.

## herald check_tree template

```yaml check_tree
all:
- name: %var_a%
  operator: not_exists
```

All 39 rules have concrete variable names (no `--VAR` wildcards or
indexed placeholders). Simpler case than presence-forbidden.

## Expected outcome

- Positive fixture: dataset lacks the column -> fires 1x.
- Negative fixture: dataset has the column -> fires 0x.
- `provenance.executability` -> `predicate`.

## Scope considerations

ADaMIG class scope is authoritative. The engine's scope filter +
class-detection (`R/class-detect.R`) already maps ADSL, BDS, OCCDS
correctly. `tools/seed-fixtures.R` picks the right concrete dataset
per rule when seeding golden fixtures.
