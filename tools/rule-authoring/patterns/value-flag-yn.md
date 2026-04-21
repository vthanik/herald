# value-flag-yn

## Intent

*"`<VAR>` is present and has a value that is not Y or N"*. Per-row:
fires on populated rows whose value is anything other than `Y` or
`N`. Null / empty rows pass (consistent with the narrative "is
present and..." gate).

Canonical message form:
`<VAR> is present and has a value that is not Y or N`

## CDISC source

ADaMIG v1.0 Section 3.1 + variable-specific guidance. Y/N flag
variables (COMPLFL, FASFL, ITTFL, PPROTFL, SAFFL, RANDFL, ENRLFL,
...) must carry `Y` or `N` when populated; the null-allowed variant
uses the sibling pattern `value-flag-yn-or-null`.

- ADaM-19 (COMPLFL)
- ADaM-20 (FASFL)
- ADaM-21 (ITTFL)
- ADaM-22 (PPROTFL)
- ADaM-23 (SAFFL)
- ADaM-24 (RANDFL)
- ADaM-25 (ENRLFL)

## P21 conceptual parallel (reference only)

P21 uses `val:Compliance` with a codelist reference (typically NY)
or an inline `Terms = "Y,N"`. herald's `is_not_contained_by` op
does the same literal-set membership test per row without a CT
lookup.

The bundled CT (NY codelist) also carries `NA` (Not Applicable) and
`U` (Unknown) which are NOT allowed for these strict flag rules --
`is_not_contained_by` with the literal `[Y, N]` is the right tool.

## herald check_tree template

```yaml check_tree
all:
  - operator: non_empty
    name: %var%
  - operator: is_not_contained_by
    name: %var%
    value:
      - "Y"
      - "N"
```

Slots:
- `var` -- the flag variable (e.g. `COMPLFL`).

## Expected outcome

- Positive: row has `<var>` populated with a value other than `Y`
  or `N` -> fires.
- Negative: row has `<var>` = `Y` or `N` -> no fire.
- `<var>` empty / NA -> no fire (the `non_empty` gate filters).

## Batch scope

7 rules: ADaM-19..25 (ADSL Y/N flags).
