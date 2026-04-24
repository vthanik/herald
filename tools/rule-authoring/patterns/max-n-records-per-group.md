# max-n-records-per-group

## Intent

Within each group defined by `%group_keys%`, fires on ALL rows in the
group when more than `%max_n%` records have `%name%` equal to `%value%`.
Uses `op_max_n_records_per_group_matching`.

Canonical message form:
`There are more than <max_n> records with <name>='<value>' for
(<group_keys>)`

## CDISC source

ADaMIG baseline flag uniqueness rules:
- ADaM-154: Only one record per (USUBJID, PARAMCD, BASETYPE) may have
  ABLFL='Y'.
- ADaM-155: Only one record per (USUBJID, PARAMCD) may have ABLFL='Y'.

## P21 conceptual parallel (reference only)

P21 uses `val:Unique` with `GroupBy` + `Variable=ABLFL` + `When=ABLFL='Y'`.
herald uses `op_max_n_records_per_group_matching` which counts matching
rows per group and fires on ALL rows in violating groups.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| Null in group key creates its own group | `op_max_n_records_per_group_matching` uses paste/tapply including NA keys. Matches. |
| Only rows matching value counted | op counts only rows where name==value (rtrimmed). Matches. |
| ALL rows in violating group fire | op fires TRUE on every row in the group. Matches. |
| Missing column -> advisory | op returns NA on absent column. Matches. |

## herald check_tree template

```yaml check_tree
operator: max_n_records_per_group_matching
name: %name%
value: '%value%'
group_keys:
%group_keys%
max_n: %max_n%
```

The `%group_keys%` slot must be a YAML block with lines like:
```
- USUBJID
- PARAMCD
- BASETYPE
```
(no leading indent needed at the top-level `group_keys:` list).

## Expected outcome

- Positive: two rows with ABLFL='Y' for same (USUBJID, PARAMCD) -> both fire.
- Negative: only one ABLFL='Y' row per group -> no fire.
- Rows without ABLFL='Y' in a violating group still fire (all group rows fire).

## Batch scope

2 rules: ADaM-154, ADaM-155.
