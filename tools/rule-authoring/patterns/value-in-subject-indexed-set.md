# value-in-subject-indexed-set

## Intent

*"A row value `<NAME>` must equal at least one of the subject's
templated reference values `<TEMPLATE>` in `<REF_DS>`"*. Fires per
row whose value is not found in the subject-keyed set built by
collecting values across every reference column that matches the
template for the row's subject.

Canonical message form:
`There is a value of <NAME> without a matching value in <REF_DS>.<TEMPLATE>`

## CDISC source

ADaMIG v1.0 Section 3.3 + Section 4.5. Per-subject analysis values
(APHASE, ASPER, TRTP, TRTA) must fall within the subject-level
domain of valid values declared in ADSL via index-templated
variables (APHASE1..n, PxxSw, TRT01P..TRTnnP, TRT01A..TRTnnA).

- ADaM-500: APHASE -> ADSL.APHASE{w}

(Plan Q19/Q22/Q23.)

## P21 conceptual parallel (reference only)

P21 builds a union set from `%Variables[Role:ADSL Treatment]%`
magic-variable expansion and evaluates `val:Match ID=... Variable=
TRTP Target=Data Role="ADSL Treatment Variables"`. herald collapses
the iteration into the op, which walks every `TEMPLATE` placeholder
combination against `names(ref_ds)` at runtime and aggregates
values per subject.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Per-subject match: first matching ref row | `DataGrouping` | herald unions across ALL matching ref rows per subject -- same outcome for ADSL (1 row per USUBJID) but correct for multi-row refs too. |
| rtrim trailing spaces on both sides | `DataEntryFactory:313-328` | `sub("\\s+$","",...)` both sides. Matches. |
| Case-sensitive default | `Pattern.compile` default | `%in%` is case-sensitive. Matches. |
| Subject not in reference -> rule-disable | `Lookup` miss | herald returns NA for that row -> advisory. Matches. |
| Template matches no columns -> rule-disable | `MagicVariable.isEmpty` | herald returns NA mask -> advisory. Matches. |

## herald check_tree template

```yaml check_tree
operator: value_not_in_subject_indexed_set
name: %name%
reference_dataset: %ref_ds%
reference_template: %template%
```

Slots:
- `name`     -- the column on the current dataset (e.g. `APHASE`).
- `ref_ds`   -- the reference dataset (typically `ADSL`).
- `template` -- index-templated column name using herald
                placeholders (`xx`, `zz`, `y`, `w`): e.g. `APHASEw`,
                `TRTxxP`, `PxxSw`.

## Expected outcome

- Positive: row value not in the subject's union of
  template-resolved column values -> fires.
- Negative: row value in set -> no fire.
- Row's subject absent from `ref_ds` OR template matches no columns
  OR row `name` value null -> NA -> advisory (no false fire).

## Batch scope

1 rule: ADaM-500 (APHASE -> ADSL.APHASE{w}).
