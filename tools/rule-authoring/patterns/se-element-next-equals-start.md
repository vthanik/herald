# se-element-next-equals-start

## Intent

For each subject in SE, and for every element except the last in trial-element
order, the end date-time of element i (`SEENDTC`) must equal the start
date-time of element i+1 (`SESTDTC`). Fires on row i when the gap exists.

## CDISC source

SDTM-IG Conformance Rules v2.0, CG0207. Cited guidance: "Since there are, by
definition, no gaps between Elements, the value of SEENDTC for one Element will
always be the same as the value of SESTDTC for the next Element."

## P21 conceptual parallel (reference only)

P21 expresses this as a per-subject sorted sequence check across adjacent SE
records (TrialElementEndDateCheck). Herald uses the new
`op_next_row_not_equal` op which sorts rows by `TAETORD` within `USUBJID`
and compares row i's `name` value against row i+1's `prev_name` value.

## P21 edge-case audit

| Scenario | Herald decision |
|---|---|
| Last element in group | Returns FALSE -- no next element to compare against. |
| NA in SEENDTC or SESTDTC | Returns NA (advisory) for that row pair. |
| Single element per subject | Returns FALSE -- no adjacent pair. |
| SEENDTC == SESTDTC of next (pass) | Returns FALSE. |
| Unsorted input rows | Sorted by TAETORD within USUBJID before comparison. |

## herald check_tree template

```yaml check_tree
operator: next_row_not_equal
name: SEENDTC
value:
  prev_name: SESTDTC
  order_by: TAETORD
  group_by:
    - USUBJID
```

## Expected outcome

- Positive fixture: subject with two SE records where SEENDTC of element 1
  does not equal SESTDTC of element 2 -- row 1 fires, row 2 (last) does not.
- Negative fixture: subject with two SE records where SEENDTC of element 1
  exactly equals SESTDTC of element 2 -- neither row fires.

## Batch scope

1 rule: CG0207 (SE domain, SEENDTC variable, SPC class).
