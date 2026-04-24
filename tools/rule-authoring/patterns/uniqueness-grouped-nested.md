# uniqueness-grouped-nested

## Intent

*"Within a given value of `<OUTER_KEY>`, there is more than one value of
`<VAR_A>` for a given value of `<VAR_B>`"*. Extension of
`paired-var-consistency-param` where the outer grouping scope can be a
composite key (e.g. `[PARAMCD]`, `[PARAMCD, USUBJID]`,
`[PARAMCD, USUBJID, SPDEVID]`). Fires every row in a violating group.

Canonical message form:
`Within a given value of <OUTER>, there is more than one value of <VAR_A>
for a given value of <VAR_B>`

## CDISC source

ADaMIG Q10 composite-group uniqueness cluster. Covers:
- Category/reference pairs scoped to PARAMCD (AVALCATy/AVAL, BASECATy/BASE, etc.)
- Visit/timepoint label:number pairs (AVISIT/AVISITN, ATPT/ATPTN, SHIFT/SHIFTN)
- Baseline pairs per subject + PARAMCD (BASE/BASEC within USUBJID+PARAMCD)
- Treatment group pooling pairs (TRTPGy/TRTP, TRxxPGy/TRTxxP, TRxxAGy/TRTxxA)
- Medical device BDS baseline pairs per device+subject+PARAMCD

## P21 conceptual parallel (reference only)

P21 expresses these with `val:Unique` and `GroupBy = STUDYID, <OUTER_KEY...>,
<VAR_B>` plus `Matching = Yes`. herald reuses `op_is_not_unique_relationship`
with a list-valued `group_by` for the outer composite key.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| Fires only 2nd+ duplicate row (`Matching=Yes` first-row skip) | herald fires ALL rows in violating group for reviewer clarity. Documented deviation in CONVENTIONS.md section 4. |
| rtrim-null on both columns before uniqueness check | Both op and pattern apply `.rtrim_na`. |
| NA in either variable excludes that row from the count | Confirmed: `is_not_unique_relationship` excludes rows where either column is NA. |

## herald check_tree template

```yaml check_tree
operator: is_not_unique_relationship
name: %var_b%
value:
  related_name: %var_a%
  group_by:
  - %group_by%
```

Note: for multi-column group_by, separate values with `\x1f` in the ids
slot. The pattern uses a single `%group_by%` slot that becomes one group_by
entry. Rules needing composite keys (e.g. PARAMCD + USUBJID) are authored
directly as separate YAML files.

## Expected outcome

- Positive fixture: two rows with identical (outer_key, VAR_B) but different
  VAR_A values -> both fire.
- Negative fixture: every (outer_key, VAR_B) combination has exactly one
  VAR_A value -> no fires.
- Rows with NA in either variable are excluded from the count (matches CDISC
  message clause).

## Batch scope

28 rules across Q10 Track 1:
- ADaM-221, 222, 224, 226: AVAL/BASE/CHG/PCHG category-vs-numeric per PARAMCD.
- ADaM-583, 587: BCHG/PBCHG category pairs per PARAMCD.
- ADaM-693, 694: BASE/BASEC pairs per PARAMCD+USUBJID+SPDEVID (MDBDS).
- ADaM-727, 728: AVISITN/AVISIT per PARAMCD.
- ADaM-729, 791: ATPTN/ATPT per PARAMCD.
- ADaM-732, 733: BASE/BASEC per PARAMCD+USUBJID.
- ADaM-736, 737: SHIFTy/SHIFTyN per PARAMCD (indexed).
- ADaM-742, 743: AVALC/AVAL per PARAMCD.
- ADaM-747, 748, 749, 750, 751: AVAL/BASE/CHG/PCHG category per PARAMCD (v1.1+).
- ADaM-231, 756: TRxxPGy/TRTxxP per-study (SLAS, double-indexed).
- ADaM-234, 759: TRxxAGy/TRTxxA per-study (SLAS, double-indexed).
- ADaM-322: TRTPGy/TRTP per-study (BDS+ODS, single-indexed).
