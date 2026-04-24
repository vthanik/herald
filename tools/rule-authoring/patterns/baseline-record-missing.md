# baseline-record-missing

## Intent

*"Within a given value of `<OUTER_KEY>` for a subject, `<VAR>` is populated
and there is not at least one record where `<FLAG_VAR>` equal to `<FLAG_VALUE>`"*.
Fires every row in groups where the baseline variable is present on at least
one row but no row has the baseline flag set.

Canonical message form:
`Within a given value of PARAMCD for a subject, BASE is populated and there
is not at least one record with ABLFL equal to Y`

## CDISC source

ADaMIG Q10 Track 3 baseline-presence rules:
- ADaM-127: BASE populated but no ABLFL='Y' per PARAMCD+USUBJID. ADaMIG v1.0 3.2.4.
- ADaM-128: BASEC populated but no ABLFL='Y' per PARAMCD+USUBJID. ADaMIG v1.0 3.2.4.
- ADaM-691: BASE/ABLFL/Y per PARAMCD+USUBJID+SPDEVID (MDBDS). ADaMIG-MD v1.0.
- ADaM-692: BASEC/ABLFL/Y per PARAMCD+USUBJID+SPDEVID (MDBDS). ADaMIG-MD v1.0.

## P21 conceptual parallel (reference only)

P21 uses a `val:Condition` with a `When` clause on the `name` column being
non-null, then a `val:Lookup` for the flag row within the same parameter+subject
group. herald implements this as a single op that combines both steps.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| `When = BASE != ''` guard before checking flag | op uses "at least one non-NA name" as the group trigger. |
| Fires per parameter per subject | group_by=[PARAMCD,USUBJID] (or +SPDEVID for MDBDS). |
| All rows in violating group fire | herald fires all rows in the group where condition holds. |

## herald check_tree template

```yaml check_tree
operator: no_baseline_record
name: %name%
flag_var: %flag_var%
flag_value: %flag_value%
group_by:
- %group_by%
```

## Expected outcome

- Positive fixture: subject S1, PARAMCD='HR' has BASE=70 on two rows, no
  ABLFL='Y' row -> both rows fire.
- Negative fixture: subject S2, PARAMCD='HR' has BASE=70 and one ABLFL='Y'
  row -> no fires.
- Group where BASE is entirely NA -> no fire.

## Batch scope

4 rules: ADaM-127, ADaM-128, ADaM-691, ADaM-692.
