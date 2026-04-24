# dataset-name-prefix-by-class

## Intent

*"An ADaM dataset name must start with 'AD' when the dataset class is
non-missing (ADaM-496); conversely, a dataset name must NOT start with 'AD'
when the class is missing (ADaM-497)."*

Metadata-level check: fires once per dataset when the naming convention
for the assigned class is violated.

Canonical message forms:
- `A dataset name does not start with "AD" when dataset class is not missing`
- `A dataset name starts with "AD" when the dataset class is missing`

## CDISC source

ADaMIG v1.0-1.3, Section 4.1.2 (naming convention "ADxxxxxx") and ADaMIG
v1.1, Section 1.6 (non-ADaM analysis datasets must not start with "AD").
Rules ADaM-496 and ADaM-497 in the CDISC ADaM Conformance Rules v5.0.

## P21 conceptual parallel (reference only)

P21 checks the dataset name at the submission manifest level (SubmissionInfo
.getDatasets()) and verifies the prefix against the class attribute from
Define-XML. herald reads `ctx$current_dataset` (the name being evaluated) and
resolves the class via `infer_class()` / `ctx$spec`.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| Class is determined from Define-XML `DatasetDef/@Class` | herald uses `infer_class()` cascading through spec, name-based heuristics, and column-based prototype matching |
| Case-insensitive prefix check | herald uppercases both name and prefix before comparison |
| Empty dataset (0 rows) still evaluated | Metadata-level op evaluates unconditionally; `.dataset_level_mask()` handles 0-row data |

## herald check_tree template

```yaml check_tree
operator: dataset_name_prefix_not
prefix: "AD"
when_class_is_missing: %when_class_is_missing%
```

Slot `when_class_is_missing` is `false` for ADaM-496 (name must start with
"AD" when class is non-missing) and `true` for ADaM-497 (name must NOT start
with "AD" when class is missing).

## Expected outcome

- ADaM-496 positive: dataset named `NONADT`, class = "BASIC DATA STRUCTURE" ->
  fires.
- ADaM-496 negative: dataset named `ADEFF`, class = "BASIC DATA STRUCTURE" ->
  no fire.
- ADaM-496 negative: dataset named `NONADT`, class missing -> no fire (class
  condition not met).
- ADaM-497 positive: dataset named `ADEFF`, class missing -> fires.
- ADaM-497 negative: dataset named `NONADT`, class missing -> no fire.

## Batch scope

2 rules: ADaM-496 (when_class_is_missing: false), ADaM-497
(when_class_is_missing: true).
