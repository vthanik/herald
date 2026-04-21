# value-study-day

## Intent

SDTM `--STDY` / `--ENDY` variables store the study-day offset of a
record's `--STDTC` / `--ENDTC` from the subject's reference start
date (`DM.RFSTDTC`). CDISC defines a specific formula with a
day-zero correction; the rule asserts the stored value equals the
computed one on every record.

Canonical message form: `<VAR>DY is properly calculated per study day algorithm`
Canonical condition:    anchor date is a complete YYYY-MM-DD

## CDISC source

SDTMIG v3.2+ Section 4.4 (Study Day):

> If the date of the observation is on or after the sponsor-defined
> reference start date (RFSTDTC), `--xxDY = target - anchor + 1`.
> Otherwise `--xxDY = target - anchor` (no +1, no day zero).

Applies to CG0220 (--STDY computation) and CG0222 (--ENDY
computation) in the current batch.

## P21 conceptual parallel (reference only)

P21 uses a DSL function `:DY(anchor, target)` that encodes the
CDISC formula:

```
val:Condition PublisherID="CG0220"
  Test="%Domain%STDY == :DY(SUB:RFSTDTC, %Domain%STDTC)"
  When="SUB:RFSTDTC @re '\d{4}-\d{2}-\d{2}.*' @and
        %Domain%STDTC @re '\d{4}-\d{2}-\d{2}.*' @and
        %Domain%STDY != ''"
```

The When clause requires both date fields to parse as complete
YYYY-MM-DD (the day-zero correction is only valid for complete
dates) AND the study-day field to be non-null.

herald re-expresses via `op_study_day_mismatch(name=--STDY,
reference_dataset=DM, reference_column=RFSTDTC,
target_date_column=--STDTC)`. The op implements the CDISC formula
directly and returns TRUE on rows where the stored day differs from
the computed one.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `@re '\d{4}-\d{2}-\d{2}.*'` on both dates -- only process records where both dates are complete ISO dates | `RegularExpressionValidationRule.java:71` | `iso_date_prefix()` extracts and validates `^YYYY-MM-DD`; returns NA when the input is missing a complete date. Matches. |
| Null row STDY -> skip (When clause requires STDY != '') | `Comparison.NullComparison` | `op_study_day_mismatch` returns NA when `as.integer(stored_day)` fails or when anchor/target dates are missing -> advisory, not fire. Matches spirit. |
| `:DY()` function semantic: target >= anchor -> diff+1; target < anchor -> diff | P21's DSL implementation | `op_study_day_mismatch` uses the same formula: `ifelse(diff >= 0L, diff + 1L, diff)`. Matches. |
| Subject without a DM row -> SUB:RFSTDTC unresolved -> rule skips | Lookup/Subject lookup path | `op_study_day_mismatch` returns NA (anchor_for_row NA) -> advisory. Matches (spirit). |
| Timezone / partial-time component after the date | `DateTime` type in DataEntryFactory | `iso_date_prefix` strips to YYYY-MM-DD and `as.Date()` parses; time / timezone suffixes ignored. Correct for day-level comparison. |

## herald check_tree template

```yaml check_tree
operator: study_day_mismatch
name: %study_day_var%
reference_dataset: %ref_ds%
reference_column: %ref_col%
target_date_column: %target_date_var%
key: USUBJID
```

## Expected outcome

- Positive: row has complete dates and stored study-day differs from
  computed -> fires.
- Negative: stored matches computed, OR any date missing/partial ->
  no fire.

## Batch scope

2 rules: CG0220 (`--STDY = :DY(SUB:RFSTDTC, --STDTC)`),
CG0222 (`--ENDY = :DY(SUB:RFSTDTC, --ENDTC)`).

Scope class ALL (SDTM events/interventions/findings all carry
--STDY/--ENDY), so the walker's `--VAR` expansion resolves per
domain at runtime.
