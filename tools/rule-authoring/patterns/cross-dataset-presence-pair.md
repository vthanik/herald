# cross-dataset-presence-pair

## Intent

When a variable exists in the source SDTM dataset it was derived from, the
corresponding ADaM copy must also be present in the ADaM dataset being
validated. This is a metadata-level check (column list, not row values):
the rule fires once per (rule x dataset) when the SDTM source variable is
present in the reference dataset and the expected ADaM column is absent from
the current dataset.

Canonical message form:
`<REF_DS>.<REF_VAR> is present but <VAR> is not present`

## CDISC source

Rules derive from ADaMIG OCCDS v1.1, Sections 3.2.4 and 3.2.8
(Tables of Conditionally Required Variables for the Adverse Event SubClass).
Each rule's `provenance.cited_guidance` is authoritative. The five rules in
scope are ADaM-641 through ADaM-645.

## P21 conceptual parallel (reference only)

P21 models this as a two-step val:Find: first check that the source SDTM
variable exists (Target="Metadata" over the reference domain), then check
that the derived variable is absent from the current dataset. herald
re-expresses both checks independently in its operator vocabulary using an
`{all}` combinator; no XML expression is copied.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| Source column existence checked against SDTM domain variable list | `op_exists(DS.VAR)` routes DS lookup through `.ref_ds(ctx, DS)` and checks `VAR %in% names(ref_ds)` -- dataset-level mask. |
| Target absence checked against current ADaM domain variable list | `op_not_exists(VAR)` checks `VAR %in% names(data)` -- dataset-level mask. |
| Fires once per (rule x dataset) when condition holds | Both `exists` and `not_exists` are registered `.METADATA_OPS`; the `{all}` combinator and the metadata-rule collapse in `rules-validate.R` ensure one finding per (rule x dataset). |

## herald check_tree template

Slots: `ref_ds` (SDTM source domain, e.g. `AE`), `var` (the variable name,
e.g. `AESTDY`). The `ref_ds.var` notation in the first leaf is interpreted
by `op_exists` as a cross-dataset column presence check.

```yaml check_tree
all:
- name: %ref_ds%.%var%
  operator: exists
- name: %var%
  operator: not_exists
```

## Expected outcome

- Positive fixture: ADaM dataset lacks `VAR`; reference SDTM dataset has
  `VAR` column. Rule fires 1x per (rule x dataset).
- Negative fixture: ADaM dataset already has `VAR`. Rule does not fire.
- `provenance.executability` -> `predicate`.

## Batch scope

5 rules: ADaM-641 (AESTDY), ADaM-642 (AEENDY), ADaM-643 (AEDUR),
ADaM-644 (AESEV), ADaM-645 (AETOXGR). All reference SDTM dataset AE.
Scope classes: OCCURRENCE DATA STRUCTURE, ADVERSE EVENT.
