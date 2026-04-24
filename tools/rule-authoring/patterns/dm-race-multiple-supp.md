# dm-race-multiple-supp

## Intent

*"When SUPPDM contains more than one record whose QNAM begins
with `RACE` for a subject, the DM row's `RACE` must equal
`'MULTIPLE'`."*

Canonical message form: `RACE = 'MULTIPLE'`.
Canonical condition:    multiple RACE-prefixed QNAM records in
SUPPDM for the same USUBJID.

Fires per DM row when:
1. SUPPDM has >1 row with `QNAM` matching `^RACE` for this
   subject (guard), AND
2. The DM row's `RACE` value is not equal to `'MULTIPLE'`
   (assertion).

Covers the CDISC multiple-race capture rules (CG0140, CG0527).

## CDISC source

SDTMIG v3.2 / v3.3 DM assumption:

> If multiple races are collected then the value of RACE should
> be 'MULTIPLE' and the additional information will be included
> in the Supplemental Qualifiers dataset.
>
> If multiple races were collected and one was designated as
> primary, RACE in DM should be the primary race and additional
> races should be reported in SUPPDM.

Both narratives reduce to the same machine-checkable
precondition: "multiple RACE-prefixed QNAM rows in SUPPDM for
the subject".

## P21 conceptual parallel (reference only)

Pinnacle 21 does NOT encode CG0140 or CG0527. Both are marked
manual-review in the CDISC SDTMIG Conformance Rules v2.0
spreadsheet. herald authors the predicate directly from the
narrative, leveraging the SUPPDM row count over RACE-prefixed
QNAM values.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| (P21 has no implementation) | n/a | herald authors from narrative -- see `op_supp_row_count_exceeds` |
| Missing SUPPDM dataset | n/a | `.ref_ds(ctx,'SUPPDM')` -> NULL -> NA mask -> `{all}` NA -> one advisory per DM dataset |
| SUPPDM present but no RACE rows for subject | n/a | Row count 0 -> FALSE -> guard fails -> no fire |
| SUPPDM has exactly 1 RACE row for subject | n/a | Threshold > 1 requires strictly > 1; single-race rows should live in DM.RACE alone. No fire. |
| DM.RACE is NA | n/a | `not_equal_to(RACE, 'MULTIPLE')` on NA returns TRUE (NullComparison-parity). Row fires when guard is also TRUE. |
| DM.RACE = 'multiple' (lowercase) | n/a | Case-sensitive `==`: `'multiple' != 'MULTIPLE'` -> fires. Matches P21-style case-sensitive string equality. |

## herald check_tree template

```yaml check_tree
all:
- operator: supp_row_count_exceeds
  name: USUBJID
  ref_dataset: SUPPDM
  qnam_pattern: '^RACE'
  threshold: 1
- operator: not_equal_to
  name: RACE
  value: 'MULTIPLE'
```

## Expected outcome

- Positive: DM row with USUBJID='S1' AND RACE='ASIAN' AND SUPPDM
  has 2 rows with QNAM in {RACE1, RACE2} for S1 -> fires.
- Negative #1: DM row with RACE='MULTIPLE' AND SUPPDM has 2 RACE
  rows for the subject -> no fire (assertion FALSE).
- Negative #2: DM row with RACE='ASIAN' AND SUPPDM has only 1
  RACE row for the subject -> no fire (guard FALSE).
- Negative #3: DM row with RACE='ASIAN' AND SUPPDM has no rows
  for the subject -> no fire (guard FALSE).
- Missing SUPPDM dataset -> NA mask -> advisory.

## Batch scope

2 rules:
- CG0140 (SDTM-IG v3.2/3.3/3.4): RACE = 'MULTIPLE' when multiple
  SUPPDM records where RACE captured.
- CG0527 (SDTM-IG v3.3/3.4): RACE = 'MULTIPLE' when multiple
  races collected and primary race not specified.
