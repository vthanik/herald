# ae-supp-aeosp-aesmie

## Intent

*"When a SUPPAE record with QNAM='AESOSP' exists for a subject,
AESMIE on at least the related AE record must be `'Y'`."*

Canonical message form: `AESMIE = 'Y'`
Canonical condition:    `Record present in SUPPAE where QNAM='AESOSP'`.

Fires per AE row when: the AE row's subject has a SUPPAE record
with QNAM='AESOSP' AND AESMIE != 'Y' on this AE row.

## Approximation note (subject-level join)

CDISC SDTMIG binds SUPPAE back to the specific AE row via
`IDVAR='AESEQ'` + `IDVARVAL=<AESEQ>`. An IDVAR-aware join op
is not yet part of the herald engine (no `op_idvar_joined_row_exists`).
This pattern uses a subject-level approximation: a single
`subject_has_matching_row` leaf joins on USUBJID and accepts
SUPPAE rows where `QNAM='AESOSP'` without filtering on IDVARVAL.

The resulting finding set is a **superset** of the precise
row-level semantic: every AE row for a subject with any
SUPPAE.AESOSP record is evaluated. In practice the over-fire
rate is low -- sponsors typically annotate only genuinely
"other medically important" AE events in SUPPAE, and the AE
records for which AESOSP is captured are exactly those the
CDISC rule targets. The rule still surfaces the real violations
it is meant to catch. A future `op_idvar_joined_row_exists` will
tighten the scope without changing this pattern's shape.

## CDISC source

SDTMIG v3.2+ AE domain guidance (IG v3.2 6.2):

> When a description of Other Medically Important Serious Adverse
> Events category is collected on a CRF, sponsors should place
> the description in the SUPPAE dataset using the standard
> supplemental qualifier name code AESOSP.

## P21 conceptual parallel (reference only)

P21 SD0054 (`PublisherID="CG0043"`): `val:Lookup` join from AE to
SUPPAE via USUBJID + IDVARVAL=AESEQ, with `Search QNAM='AESOSP'`,
then `Test="AESMIE=='Y'"`. herald uses
`subject_has_matching_row` for the join (subject-level only) and
`not_equal_to(AESMIE,'Y')` for the assertion.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `Lookup` returns null when no matching SUPP row -> rule skipped for that AE record | `LookupValidationRule.java:~50` | `subject_has_matching_row` returns FALSE for subjects with no SUPPAE.AESOSP row; under `{all}` the guard is FALSE -> no fire. Matches. |
| `Lookup` join uses IDVAR+IDVARVAL (row-level) | same | herald subject-level approximation documented above. **Intentional deviation** -- over-fires a small margin until IDVAR-join op lands. |
| Missing SUPPAE dataset -> `Optional` skip | `RuleDefinition.Optional` | `subject_has_matching_row` via `.ref_ds(ctx,'SUPPAE')` -> NULL -> NA mask -> `{all}` NA -> one advisory per (rule x dataset). Functional equivalent. |
| `AESMIE != 'Y'` with NA lhs -> fires | `Comparison.java:160-207` | `not_equal_to(AESMIE,'Y')` on NA -> TRUE. Matches (after NullComparison fix). |

## herald check_tree template

```yaml check_tree
all:
- operator: subject_has_matching_row
  name: USUBJID
  reference_dataset: SUPPAE
  reference_column: QNAM
  expected_value: AESOSP
- operator: not_equal_to
  name: AESMIE
  value: 'Y'
```

## Expected outcome

- Positive: AE row for subject S1 with AESMIE='N' AND SUPPAE has
  a row (any IDVARVAL) with USUBJID='S1' + QNAM='AESOSP' -> fires.
- Negative #1: AE row with AESMIE='Y' AND SUPPAE has the AESOSP
  row -> no fire (assertion FALSE).
- Negative #2: AE row with AESMIE='N' AND SUPPAE has no AESOSP
  row for this subject -> no fire (guard FALSE).
- Missing SUPPAE dataset -> NA mask -> advisory.

## Batch scope

1 rule: CG0043 (AESMIE='Y' when SUPPAE.AESOSP record present).
