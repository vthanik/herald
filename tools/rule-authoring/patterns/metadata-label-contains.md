# metadata-label-contains

## Intent

ADaMIG Section 3.1.6 defines a naming convention where variables whose
names end in a canonical suffix must carry a label containing the
matching phrase (e.g. `*DT` -> "Date", `*TM` -> "Time", `*DTM` ->
"Datetime", `*STDT` -> "Start Date"). CDISC expresses this as a
metadata-level check: for every variable in the dataset whose name
ends in `<suffix>`, its LABEL attribute must contain `<value>` as a
substring. The rule fires once per (rule x dataset) when any matching
variable violates.

Canonical message form:
`A variable ending in <SUFFIX> must contain "<VALUE>" in the label`

## CDISC source

Rule messages derive from ADaMIG v1.1 Section 3.1.6, Item 2 (bracketed
`{phrase}` convention):

> Variable labels containing a word or phrase in brackets, e.g. {Time},
> should be replaced by the producer with appropriate text that
> contains the bracketed word or phrase somewhere in the text.

Each rule's YAML `provenance.cited_guidance` repeats the exact clause
for the specific suffix.

## P21 conceptual parallel (reference only)

P21 models metadata-level label checks via `val:Regex Target="Metadata"
Variable="LABEL"` (see `AD0016` for variable-label-length). The
primitive projects the variable list as a derived dataset with columns
{VARIABLE, LABEL, TYPE, LENGTH, ...} and runs a regex on the LABEL
column, filtered by a `When=` clause on the VARIABLE column. We take
the concept (metadata-as-derived-dataset) and re-express it in herald
by walking the actual column list and reading each column's `label`
attribute directly -- no XML expression or derived view is copied.

## herald check_tree template

The template uses two slots: `suffix` (variable-name ending, e.g. `DT`,
`TM`, `DTM`) and `value` (phrase that must appear in the label). The
op `label_by_suffix_missing` fires when at least one matching variable
has a label that does not contain `value` (case-insensitive substring,
absent-or-empty label counts as violation).

```yaml check_tree
operator: label_by_suffix_missing
suffix: '%suffix%'
value: '%value%'
```

This is a single-leaf tree. `label_by_suffix_missing` is registered in
`R/rules-validate.R::.METADATA_OPS` so the rule fires once per (rule x
dataset) even though each mask is length `nrow(data)`.

## Expected outcome

- Positive fixture: dataset has a `*<suffix>` column with a label NOT
  containing `<value>` -> fires 1x.
- Negative fixture: dataset has a `*<suffix>` column whose label
  contains `<value>` -> fires 0x.
- `provenance.executability` -> `predicate`.

## Fixture strategy

No shared fixture file. Each rule smoke-checks via the per-rule synth
path in `smoke-check.R`, which builds a minimal ADaM BDS dataset with
a single `<suffix>`-ending column, applies a label attribute directly
via `attr(df[[col]], "label") <- "..."`, and calls `validate()`. The
synth path is `label_by_suffix_missing`-aware (see smoke-check.R for
the branch).
