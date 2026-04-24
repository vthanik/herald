# variable-name-format

## Intent

*"All variable names must conform to a structural pattern (start with a
letter; contain only letters, digits, and underscores)."* Metadata-level
check: fires once per dataset when any column name violates the regex.

Canonical message forms:
- `A variable name does not start with a letter (A-Z)` (ADaM-14)
- `A variable name contains a character other than letters (A-Z), underscores (_), or numerals (0-9)` (ADaM-15)

## CDISC source

ADaMIG Section 3.1.6 (variable naming conventions). ADaM-14 and ADaM-15 in
the CDISC ADaM Conformance Rules v5.0. The same structural constraints appear
in SDTMIG Section 2.2.2 for SDTM datasets.

## P21 conceptual parallel (reference only)

P21 projects the variable list as a virtual metadata dataset (VARIABLE column)
and applies `val:Regex Target=Metadata Variable=VARIABLE`. ADaM-14 uses a
pattern like `^[A-Z].*`; ADaM-15 uses `^[A-Z][A-Z0-9_]*$`. herald uses the
metadata-level op `any_var_name_not_matching_regex` which iterates `names(data)`
directly and fires when any name fails the pattern.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| Variable names are compared uppercase (Metadata.java:138) | `any_var_name_not_matching_regex` uppercases all names before regex matching |
| Missing variable list (empty dataset) -> skip | Op returns FALSE (no fire) when `names(data)` is empty |
| ADaM-14 fires on first non-conforming name; not per-row | Op returns dataset-level mask (`.dataset_level_mask()`) -- fires once per dataset, not per row |

## herald check_tree template

```yaml check_tree
operator: any_var_name_not_matching_regex
value: "%regex%"
```

Slot `regex` is a positive-match regex; the op fires when any variable name
does NOT match it.

## Expected outcome

- ADaM-14 positive: dataset with a column `_BADNAME` -> fires.
- ADaM-14 negative: all columns start with `[A-Z]` -> no fire.
- ADaM-15 positive: dataset with a column `A-B` -> fires.
- ADaM-15 negative: all columns match `^[A-Z][A-Z0-9_]*$` -> no fire.

## Batch scope

2 rules: ADaM-14 (regex=^[A-Z]), ADaM-15 (regex=^[A-Z][A-Z0-9_]*$).
