# suffix-presence-pair

## Intent

*"When a column ending in `<SUFFIX_PRESENT>` exists in the dataset, the
column with the same stem ending in `<SUFFIX_REQUIRED>` must also exist."*
This is a **metadata-level** (column-existence) check, not a row-value
check. Uses `stem` expansion to bind both leaf names to the same concrete
stem.

Canonical message form:
`A variable with a suffix of <SUFFIX_PRESENT> is present but a variable
with the same root and a suffix of <SUFFIX_REQUIRED> is not present`

## CDISC source

ADaMIG v1.0, Section 3, Item 3 (General Variable Naming Conventions):
"The names of all other character flag (or indicator) variables end in FL,
and the names of the corresponding numeric flag (or indicator) variables
end in FN. If the flag is used, the character version (*FL) is required
but the numeric version (*FN) can also be included."

- ADaM-7: when `*FN` column exists in the dataset, the character flag
  `*FL` must also exist.

## P21 conceptual parallel (reference only)

P21 implements this as a `val:Find` rule with `Target="Metadata"`, using
a wildcard variable pattern to find all `*FN` columns, then asserting
their `*FL` counterparts are also in the variable list. We re-express
this independently using herald's `exists` / `not_exists` operators.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| Variable name `.toUpperCase()` at init | Walker uppercases `name` on `names(data)` lookup. |
| Rule fires once per (rule x dataset), not per row | Both `exists` and `not_exists` are `.METADATA_OPS`; walker collapse fires once per dataset. |
| `stem` wildcard matches any prefix (e.g. COMPL in COMPLFL) | herald's `expand: [suffix_present, suffix_required]` drives `.expand_indexed()` to find all `*FN` columns and bind each with its `*FL` sibling. |

## herald check_tree template

```yaml check_tree
expand:
- %suffix_present%
- %suffix_required%
all:
- operator: exists
  name: stem%suffix_present%
- operator: not_exists
  name: stem%suffix_required%
```

Slots:
- `suffix_present` -- the suffix that exists and triggers the check
  (e.g. `FN`).
- `suffix_required` -- the suffix that must also be present (e.g. `FL`).

## Expected outcome

- Positive: dataset has stem+suffix_present column but lacks
  stem+suffix_required column -- fires once per (rule x dataset).
- Negative: dataset has both columns, OR dataset has neither -- no fire.
- `provenance.executability` -> `predicate`.

## Batch scope

1 rule: ADaM-7 (FN present -> FL must be present).
