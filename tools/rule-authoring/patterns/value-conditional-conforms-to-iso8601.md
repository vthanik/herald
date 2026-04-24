# value-conditional-conforms-to-iso8601

## Intent

*"When `<COND_VAR>` = `<COND_VAL>`, `<TARGET_VAR>` must conform to
ISO 8601 date format"*. Fires per record only when the guard condition
is satisfied AND the target value is non-null and does NOT parse as
valid ISO 8601.

Used for TS-domain parametric rules where a specific TSPARMCD value
implies TSVAL must carry an ISO 8601 date (e.g. DCUTDTC, SSTDTC,
SENDTC), and for TSVCDVER when TSVCDREF='CDISC'.

## CDISC source

SDTMIG Trial Summary (TS) domain and TSVCDREF parametric validation:
- CG0270: TSVAL conforms to ISO 8601 when TSPARMCD='AGEMAX'.
- CG0283: TSVAL conforms to ISO 8601 date when TSPARMCD=DCUTDTC.
- CG0285: TSVAL conforms to ISO 8601 date when TSPARMCD=SSTDTC.
- CG0286: TSVAL conforms to ISO 8601 date when TSPARMCD=SENDTC.
- CG0289: TSVCDVER = valid published version (date) when TSVCDREF='CDISC'.

## P21 conceptual parallel (reference only)

P21 uses `val:Regex` with a `When=TSPARMCD == '<code>'` clause.
herald uses `{all: [is_contained_by(cond_var, [cond_val]),
value_not_iso8601(target_var, kind)]}`. The `{all}` short-circuits:
if TSPARMCD differs, the first leaf returns FALSE and the row does
not fire.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| `When=` clause applied row-wise before regex test | `is_contained_by` as first `all` leaf; FALSE there means the row is NA-mask-propagated, no fire. Equivalent. |
| Null TSVAL -> passes (no regex requirement when null) | `op_value_not_iso8601` returns NA on null -> `{all}` advisory -> no fire. Matches. |
| Missing column -> advisory | Both ops return NA on absent column -> no fire. Matches. |
| Case-sensitive TSPARMCD comparison | `op_is_contained_by` uses exact string match. Matches (TSPARMCD is uppercase per SDTMIG). |

## herald check_tree template

```yaml check_tree
all:
- operator: is_contained_by
  name: %cond_var%
  value: [%cond_val%]
- operator: value_not_iso8601
  name: %target_var%
  kind: %kind%
```

Slots:
- `cond_var`   -- guard column (e.g. TSPARMCD, TSVCDREF)
- `cond_val`   -- literal value the guard must equal (e.g. AGEMAX, CDISC)
- `target_var` -- column whose value must be ISO 8601
- `kind`       -- `date` (all rules in this batch)

## Expected outcome

- Positive: `cond_var = cond_val` AND `target_var` holds a
  non-null, non-ISO-8601 value -> fires.
- Negative: `cond_var != cond_val` -> no fire (guard not met).
- Negative: `cond_var = cond_val` AND `target_var` is valid ISO 8601
  or null -> no fire.

## Batch scope

5 rules: CG0270, CG0283, CG0285, CG0286, CG0289.
