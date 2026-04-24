# trt-value-in-adsl-defined-set

## Intent

*"A non-missing record-level treatment variable `<VAR>` must equal at
least one value of the IG-defined character treatment variables in ADSL
whose names match the template `<TEMPLATE>`."*

Fires per row where the treatment value is populated but is not found in
the set of values collected across every ADSL column whose name matches
the index-template for the row's subject.

Canonical message form:
`A non-missing value of <VAR> is not equal to at least one value of the character treatment variables in ADSL defined in the IG`

## CDISC source

ADaMIG v1.1, Section 3.3.2, Table 3.3.2.1:

- TRTP -- "if populated, TRTP must match at least one value of the
  character planned treatment variables in ADSL (e.g., TRTxxP,
  TRTSEQP, TRxxPGy)."
- TRTA -- "TRTA must match at least one value of the character actual
  treatment variables in ADSL (e.g., TRTxxA, TRTSEQA, TRxxAGy)."

Rule IDs: ADaM-720 (TRTP -> TRTxxP), ADaM-897 (TRTA -> TRTxxA).

## P21 conceptual parallel (reference only)

P21 expands `%Variables[Role:ADSL Treatment]%` from the ADSL domain's
variable-level metadata and checks that the row value is in that union
set per subject. herald collapses the expansion into
`op_value_not_in_subject_indexed_set` which walks the template against
`names(ref_ds)` at runtime and unions values per USUBJID.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Per-subject match: union all matching template columns | `DataGrouping` | herald unions across ALL matching template columns per subject. |
| rtrim trailing spaces on both sides | `DataEntryFactory:313-328` | `sub("\\s+$","",...)` both sides. Matches. |
| Case-sensitive default | `Pattern.compile` default | `%in%` is case-sensitive. Matches. |
| Subject not in ADSL -> rule-disable | `Lookup` miss | herald returns NA for that row -> advisory. |
| Template matches no columns in ADSL -> rule-disable | `MagicVariable.isEmpty` | herald returns NA mask -> advisory. |
| Null/empty VAR -> skip | null-sentinel guard | NA -> advisory. Matches. |

## herald check_tree template

```yaml check_tree
operator: value_not_in_subject_indexed_set
name: %var%
reference_dataset: ADSL
reference_template: %template%
```

Slots:
- `var`      -- the record-level treatment variable (e.g. `TRTP`, `TRTA`).
- `template` -- index-template for ADSL treatment columns using the
                `xx` placeholder (e.g. `TRTxxP`, `TRTxxA`).

## Expected outcome

- Positive: row TRTP = "DRUG C" but ADSL only has TRT01P = "DRUG A" and
  TRT02P = "DRUG B" for this subject -> fires.
- Negative: row TRTP = "DRUG A" and ADSL has TRT01P = "DRUG A" for the
  same subject -> no fire.
- Row VAR null, or subject absent from ADSL, or template matches no ADSL
  columns -> NA -> advisory (no false fire).

## Batch scope

2 rules: ADaM-720 (TRTP -> TRTxxP), ADaM-897 (TRTA -> TRTxxA).
