# triple-presence-guard

## Intent

*"When `<VAR_A>` is present and `<VAR_B>` is present, `<VAR_C>` must
also be present"*. A metadata-level check (column presence): fires once
per (rule x dataset) when both guard columns exist and the required
column does not.

Canonical message form:
`<VAR_A> is present and <VAR_B> is present but <VAR_C> is not present`

Examples:
- `TRTPGy is present and TRTA is present but TRTAGy is not present`
- `TRxxPGy is present and TRTxxA is present but TRxxAGy is not present`

## CDISC source

ADaMIG treatment-group pooling integrity rules:
- ADaM-239: TRTPGy present + TRTA present -> TRTAGy required (y expand).
- ADaM-764: TRTPGy present + TRTA present -> TRTAGy required (y expand,
  v1.1+ ig_version with wider y range).
- ADaM-368: TRxxPGy present + TRTxxA present -> TRxxAGy required (xx,y).

## herald check_tree template

```yaml check_tree
expand: "%expand%"
all:
- name: %var_a%
  operator: exists
- name: %var_b%
  operator: exists
- name: %var_c%
  operator: not_exists
```

All three leaves are `.METADATA_OPS` -- the walker collapses the result
to one finding per (rule x dataset). `expand:` drives index expansion so
a single rule YAML covers all concrete index combinations.

## Expected outcome

- Positive: dataset has var_a and var_b columns but not var_c -> fires 1x.
- Negative: dataset has all three (var_a, var_b, var_c) -> no fire.
- Skip: dataset lacks var_a or var_b -> guard leaf FALSE -> all: FALSE.

## Batch scope

3 rules: ADaM-239, 368, 764.
