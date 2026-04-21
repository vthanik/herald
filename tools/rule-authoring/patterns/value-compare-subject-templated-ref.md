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

P21 does NOT encode ADaM-600 / ADaM-603 in its XML configs (the rule is
authored from the ADaMIG narrative directly). Value-equality semantics
below track P21's `DataEntryFactory.compareToAny()` so when P21 does
author equivalents in the future, herald and P21 agree on every
value-pair verdict.

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Index column value not integer -> skip row | `Integer.parseInt` | `suppressWarnings(as.integer(...))`; NA -> row NA (advisory). Matches. |
| Resolved column missing in ref -> skip row | lookup miss | row NA (advisory). Matches. |
| Subject not in ref -> skip row (Lookup no-match) | `LookupValidationRule` | row NA (advisory). Matches. |
| rtrim trailing SPACE on both sides | `DataEntryFactory.java:313-328` | `sub(" +$","",...)` on the key; value rtrim is done inside `.cdisc_value_equal`. Matches. |
| Both sides NULL -> equal (no fire) | `NullDataEntry.compareToAny:355-356` | `.cdisc_value_equal(NA,NA) == TRUE`. Matches. |
| One side NULL -> not equal (fire) | same | `.cdisc_value_equal` returns FALSE when one is NA and the other is not. Matches. |
| Both sides numeric -> BigDecimal equality (`"1" == "1.0"`) | `DataEntryFactory.java:159-160` | `as.numeric()` on both, `==` when both parse. Matches. |
| Both sides datetime -> prefix equality (`"2024-01-01" == "2024-01-01T00:00:00"`) | `DataEntryFactory.java:172-180` | Match `.CDISC_DATE_RX` (same ISO regex as P21 DATE_PATTERN) on both, `startsWith` both ways. Matches. |
| 4-digit integer treated as year | `DataEntryFactory.java:173,175` | `nchar == 4 & !grepl("\\.", .)` marks numeric-year candidates as date for fuzzy compare. Matches. |
| Case-sensitive `==` default | `Comparison.java:195` | `==` on strings is case-sensitive. Matches. |

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
