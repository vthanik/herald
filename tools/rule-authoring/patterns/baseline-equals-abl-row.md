# baseline-equals-abl-row

## Intent

*"BASETYPE is [not present | populated], `<B_VAR>` is populated, and `<B_VAR>` is
not equal to `<A_VAR>` where ABLFL is equal to Y for a given value of PARAMCD for
a subject"*. Within each (USUBJID, PARAMCD [, BASETYPE]) group, the baseline
variable must equal the analysis variable on the record flagged ABLFL='Y'.

Canonical message form:
`BASETYPE is not present, BASE is populated, and BASE is not equal to AVAL where
ABLFL is equal to Y for a given value of PARAMCD for a subject`

## CDISC source

ADaM-IG baseline consistency rules:
- ADaM-181: BASE vs AVAL per USUBJID+PARAMCD, BASETYPE absent.
- ADaM-182: BTOXGR vs ATOXGR per USUBJID+PARAMCD, BASETYPE absent.
- ADaM-183: BNRIND vs ANRIND per USUBJID+PARAMCD, BASETYPE absent.
- ADaM-354: ByIND vs AyIND per USUBJID+PARAMCD, BASETYPE absent (indexed y).
- ADaM-698: BASE vs AVAL per USUBJID+SPDEVID+PARAMCD, BASETYPE absent.
- ADaM-699: BNRIND vs ANRIND per USUBJID+SPDEVID+PARAMCD, BASETYPE absent.
- ADaM-703: ByIND vs AyIND per USUBJID+SPDEVID+PARAMCD, BASETYPE absent (indexed).
- ADaM-744: BTOXGR vs ATOXGR per USUBJID+PARAMCD+BASETYPE, BASETYPE populated.
- ADaM-745: BNRIND vs ANRIND per USUBJID+PARAMCD+BASETYPE, BASETYPE populated.
- ADaM-789: BASE vs AVAL per USUBJID+PARAMCD+BASETYPE, BASETYPE populated.
- ADaM-790: ByIND vs AyIND per USUBJID+PARAMCD+BASETYPE, BASETYPE populated (indexed).

## basetype_gate semantics

- `absent`: entire dataset is skipped (returns FALSE) when BASETYPE column is
  present. Rule applies only when BASETYPE is not a variable in the dataset.
- `populated`: only rows where BASETYPE is non-null are evaluated. Rows with
  BASETYPE=null are passed (FALSE).
- `any`: no gate (not used in the current batch).

## herald check_tree template

```yaml check_tree
expand: "%expand%"
operator: base_not_equal_abl_row
b_var: %b_var%
a_var: %a_var%
group_by:
%group_keys%
basetype_gate: %basetype_gate%
```

## Expected outcome

- Positive: subject S1, PARAMCD='HR', ABLFL='Y' row has AVAL=70; another row has
  BASE=75 (different) -> fires.
- Negative: subject S1, PARAMCD='HR', ABLFL='Y' row has AVAL=70; another row has
  BASE=70 (same) -> does not fire.
- NA advisory: group has no ABLFL='Y' row -> advisory (NA).
- Basetype absent gate: BASETYPE column present in dataset -> all FALSE.
- Basetype populated gate: row where BASETYPE is null -> skipped (FALSE).

## Batch scope

11 rules: ADaM-181, 182, 183, 354, 698, 699, 703, 744, 745, 789, 790.
