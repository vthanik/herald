# value-in-srs-registry

## Intent

*"When TSPARMCD equals `<TSPARMCD>`, `<VAR>` is a valid entry in the FDA
Substance Registration System (SRS)"*. Fires when the variable is not found
in the SRS preferred-name or UNII code table. Returns NA advisory when the
SRS table has not been downloaded (user must run `download_srs()`).

Canonical message forms:
- `TSVAL is a valid preferred term from FDA Substance Registration System (SRS)`
- `TSVALCD is a valid unique ingredient identifier from FDA Substance Registration System (SRS)`

## CDISC source

SDTM-IG conformance rules -- TS domain SRS lookups:
- CG0442: TSVAL in SRS preferred term, TSPARMCD='CURTRT'.
- CG0443: TSVALCD in SRS UNII code, TSPARMCD='CURTRT'.
- CG0445: TSVAL in SRS preferred term, TSPARMCD='COMPTRT'.
- CG0446: TSVALCD in SRS UNII code, TSPARMCD='COMPTRT'.
- CG0450: TSVAL in SRS preferred term, TSPARMCD='TRT'.
- CG0451: TSVALCD in SRS UNII code, TSPARMCD='TRT'.

## herald check_tree template

```yaml check_tree
all:
- name: TSPARMCD
  operator: equal_to
  value: %tsparmcd%
- name: %var%
  operator: value_in_srs_table
  field: %field%
```

`all:` fires when BOTH: (a) TSPARMCD equals the expected parameter code, AND
(b) `%var%` is not found in the SRS registry for the given field.

When the SRS cache is absent, leaf (b) returns NA (advisory) for all rows and
the `all:` combinator propagates NA -- no false positives.

## Expected outcome

- Positive: TSPARMCD='CURTRT', TSVAL='UnknownDrug' (not in SRS) -> fires.
- Negative: TSPARMCD='CURTRT', TSVAL='ASPIRIN' (valid SRS PT) -> does not fire.
- Skip: TSPARMCD='INDIC' (wrong parameter) -> leaf (a) returns FALSE -> all: FALSE.
- Advisory: SRS cache empty -> leaf (b) returns NA -> finding is advisory.

## Batch scope

6 rules: CG0442, CG0443, CG0445, CG0446, CG0450, CG0451.
