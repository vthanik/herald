# value-compare-subject-templated-ref

## Intent

*"On a given record, the value of `<NAME>` is not equal to the
reference dataset's `<TEMPLATE>` column, where placeholders resolve
from other columns on the same row"*. Per-row: each row resolves its
own target ADSL column from its placeholder-column values, joins by
subject key, and fires if the two values differ.

Canonical message form:
`On a given record, the value of <NAME> is not equal to the value
of variable <TEMPLATE> where xx equals the value of <XX_COL> and
w equals the value of <W_COL>`

## CDISC source

ADaMIG v1.2 Section 3.3.3. Period / subperiod / phase timing
variables in BDS / OCCDS must equal their subject-level counterparts
in ADSL (per-period indexed column).

- ADaM-600: ASPRSDTM vs ADSL.PxxSwSDM (xx=APERIOD, w=ASPER)
- ADaM-603: ASPREDTM vs ADSL.PxxSwEDM (xx=APERIOD, w=ASPER)

## P21 conceptual parallel (reference only)

P21 uses `val:Match` with a `%ColumnName%` magic variable that is
itself parameterised by row values:
`%Variable = "Pxx%APERIOD%Sw%ASPER%SDM" From="ADSL"`. herald
collapses the substitution into the op, with explicit placeholder
-> index-column mapping in `index_cols` and ADaMIG formatting rules
(`xx`/`zz` -> `%02d`, `y`/`w` -> `%d`).

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Index column value not integer -> skip row | `Integer.parseInt` | `suppressWarnings(as.integer(...))`; NA -> row NA (advisory). Matches. |
| Resolved column missing in ref -> skip row | `MagicVariable.isMissing` | row NA (advisory). Matches. |
| Subject missing in ref -> skip row | `Lookup` miss | row NA (advisory). Matches. |
| rtrim trailing spaces both sides | `DataEntryFactory:313-328` | `sub("\\s+$","",...)`. Matches. |
| Case-sensitive compare default | `String.equals` | `!=` on rtrimmed strings. Matches. |

## herald check_tree template

```yaml check_tree
operator: not_equal_subject_templated_ref
name: %name%
reference_dataset: %ref_ds%
reference_template: %template%
index_cols:
  %ph_a%: %col_a%
  %ph_b%: %col_b%
```

Slots:
- `name`      -- column on the current dataset (e.g. `ASPRSDTM`).
- `ref_ds`    -- reference dataset (typically `ADSL`).
- `template`  -- templated reference column name (e.g. `PxxSwSDM`).
- `index_cols` -- mapping from placeholder names (`xx`, `w`, ...) to
                  current-dataset columns whose row values supply the
                  concrete index value. At least one entry required.

Optional slots:
- `key`           -- subject key on current dataset (default `USUBJID`).
- `reference_key` -- key on the reference dataset (defaults to `key`).

## Expected outcome

- Positive: row value != resolved reference value -> fires.
- Negative: row value == resolved reference value -> no fire.
- Any resolve failure (index-column NA, resolved column absent in
  ref, subject absent in ref, value NA on either side) -> row NA ->
  advisory per (rule x dataset).

## Batch scope

2 rules: ADaM-600 (ASPRSDTM), ADaM-603 (ASPREDTM).
