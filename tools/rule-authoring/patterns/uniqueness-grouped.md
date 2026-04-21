# uniqueness-grouped

## Intent

Within the scoped dataset, for each distinct value of a "group key"
variable, a "dependent" variable should have at most one distinct
value. The rule fires on rows whose group key is part of a violating
group (multiple distinct dependent values within it).

Canonical message form:
`There is more than one value of <A> for a given value of <B>[, considering only those rows on which both variables are populated]`

Examples:
- `There is more than one value of PARAM for a given value of PARAMCD`
- `There is more than one value of APERIODC for a given value of APERIOD`
- `There is more than one value of TRTSEQP for a given value of TRTSEQPN`

This batch covers the **simplest form** -- no additional grouping
qualifier. Variants like "Within a parameter, there is more than
one value of ..." or "Within a given value of X, ..." introduce a
composite group key (PARAMCD or X plus the stated B) and will be
handled in a follow-up batch.

## CDISC source

ADaMIG Section 3, functional-dependency constraints between paired
variables (coded + label, numeric + character, abbreviation + full
form). ADaMIG requires a 1:1 relationship within each dataset.

57 rules matched the simple form; all ADaM-IG. Most common pairings:
PARAMCD/PARAM, APERIODC/APERIOD, TRTSEQP/TRTSEQPN, AESEV/AESEVN,
ARELTM/ARELTMU.

## P21 conceptual parallel (reference only)

P21's `val:Unique` primitive with `GroupBy=<B>` and
`Variable=<A>` and `Matching=Yes` implements the same concept.
herald uses `is_not_unique_relationship` which already takes
(name, value.related_name) and wraps the group-by logic internally.

Deviations we make from P21 (`UniqueValueValidationRule.java`):

- **Right-trim null** (P21 DataEntryFactory.java:313-328): we now
  apply `.rtrim_na()` to both variables before counting distinct
  values. `"Heart Rate"` and `"Heart Rate "` collapse to one value;
  `"   "` collapses to NA.
- **Row-tagging semantic**: P21 fires only the 2nd+ duplicate row
  in a violating group; herald fires EVERY row in the violating
  group. More complete reviewer context at the cost of more
  findings. Documented in CONVENTIONS.md section 4.
- **NA group key**: herald excludes rows with NA in either
  variable entirely ("considering only those rows on which both
  are populated"). P21 keeps NULL group keys in their own logical
  group. herald is stricter; matches the CDISC message clause.

## herald check_tree template

```yaml check_tree
expand: "%expand%"
all:
- name: %var_b%
  operator: is_not_unique_relationship
  value:
    related_name: %var_a%
```

- `name` is the GROUP key (the "for a given value of B" variable).
- `value.related_name` is the DEPENDENT ("more than one value of A"
  variable).
- `expand` is empty for concrete-name rules; for indexed rules it
  holds `xx` / `y` / `zz` / `w` (or a comma-separated list for
  multi-placeholder). When empty the engine's `.parse_expand_spec`
  returns `character()` -> no expansion, rule runs once.

Fires per row for rows whose group-key value is in a violating
group.

## Expected outcome

- Positive fixture: two rows with same `B`, different `A` values.
  Both rows fire.
- Negative fixture: rows where every `B` maps to exactly one `A`.
  No fires.
- `provenance.executability` -> `predicate`.
