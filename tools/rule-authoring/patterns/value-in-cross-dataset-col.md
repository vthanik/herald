# value-in-cross-dataset-col

## Intent

Fire when a variable's value is not found in the value set of a specified
column in a reference dataset. Full-column membership check -- no
row-level key join; the entire reference column is treated as an allowed
set.

## CDISC source

SDTM-IG Conformance Rules v2.0 / AP Guide v1.0. Rules of the form
"VAR in REFDS.REFCOL", e.g. "APID in POOLDEF.POOLID" (CG0156),
"RSUBJID in DM.USUBJID" (CG0157), "RSUBJID in POOLDEF.POOLID" (CG0158).

## P21 conceptual parallel (reference only)

P21 val:Lookup with `Variable="%VAR%" From="%REFDS%" Where="%REFCOL%
!= null"` plus a membership check. Herald expresses the same predicate
via `op_missing_in_ref` with `reference_key` pointing at the reference
column.

## P21 edge-case audit

- Empty / null cell in `var`: op returns NA (advisory); null values are
  not checked for membership (CDISC allows null for optional variables).
- Reference dataset absent: op returns NA (advisory) and records to
  `ctx$missing_refs$datasets`.
- Reference column absent: op returns NA (advisory).
- Duplicate values in reference column are de-duplicated before the
  membership test.

## herald check_tree template

```yaml check_tree
all:
- operator: missing_in_ref
  name: "%var%"
  reference_dataset: "%ref_dataset%"
  reference_key: "%ref_column%"
```

## Expected outcome

Fires on rows where `data[[var]]` is not found among the values of
`ref_dataset[[ref_column]]`. Returns NA when the reference is absent or
the cell is null.

## Batch scope

3 SDTM-IG rules: CG0156, CG0157, CG0158.
