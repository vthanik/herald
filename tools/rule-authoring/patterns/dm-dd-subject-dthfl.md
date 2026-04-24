# dm-dd-subject-dthfl

## Intent

*"When any record exists in the DD dataset for a subject,
`DM.DTHFL` for that subject must be `'Y'`."*

Canonical message form: `DTHFL = 'Y'`
Canonical condition:    `DD record present for subject`.

Fires per DM row when: the subject's USUBJID is present in DD
(any row, any DDTESTCD) AND DTHFL != 'Y' on the DM row.

## CDISC source

SDTMIG v3.2+ DM spec + DD domain assumption:

> DTHFL: Indicates the subject died. Should be Y or null. Should
> be populated even when the death date is unknown.
>
> DD Assumption 1: This domain captures information pertaining
> to the death of a subject, including the causes of death.

If DD has any record for a subject, the subject died, so DM
must carry DTHFL='Y' for that subject.

## P21 conceptual parallel (reference only)

P21 SD0159 (`PublisherID="CG0133"`): `val:Condition` with
`When="DD.USUBJID exists for DM.USUBJID"` (implemented via
a DD presence Lookup) and `Test="DTHFL == 'Y'"`. herald
re-expresses as
`{all: [has_next_corresponding_record(USUBJID,{reference_dataset:DD}), not_equal_to(DTHFL,'Y')]}`.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Lookup returns null when no DD row for subject -> no fire | `LookupValidationRule.java` | `has_next_corresponding_record` returns FALSE for subjects absent from DD; under `{all}` guard FALSE -> no fire. Matches. |
| `DTHFL != 'Y'` with NA lhs -> fires | `Comparison.java:160-207` | `not_equal_to(DTHFL,'Y')` on NA returns TRUE (after NullComparison-parity fix). Matches. |
| Missing DD dataset -> `Optional` skip | `RuleDefinition.Optional` | `has_next_corresponding_record` via `.ref_ds(ctx,'DD')` -> NULL -> NA mask -> `{all}` NA -> one advisory per DM dataset. Functional equivalent. |
| DTHFL = '' (empty string) != 'Y' -> fires | post-rtrim null check | After P21 fix, `not_equal_to('','Y')` returns TRUE -> fires. Matches. |
| DTHFL = 'y' (lowercase) != 'Y' -> fires | case-sensitive match | R's `==` is case-sensitive; `'y'` != `'Y'` -> fires. Matches. |

## herald check_tree template

```yaml check_tree
all:
- operator: has_next_corresponding_record
  name: USUBJID
  value:
    reference_dataset: DD
    by: USUBJID
- operator: not_equal_to
  name: DTHFL
  value: 'Y'
```

## Expected outcome

- Positive: DM row with USUBJID='S1' AND DTHFL='N' AND DD has
  any row with USUBJID='S1' -> fires.
- Negative #1: DM row with DTHFL='Y' AND DD has the subject
  record -> no fire (assertion FALSE).
- Negative #2: DM row with DTHFL='N' AND DD has no row for this
  subject -> no fire (guard FALSE).
- Missing DD dataset -> NA mask -> advisory.

## Batch scope

1 rule: CG0133 (DTHFL='Y' when DD record present for subject).
