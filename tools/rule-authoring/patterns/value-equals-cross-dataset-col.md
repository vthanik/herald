# value-equals-cross-dataset-col

## Intent

Fire when a variable's value does not equal the value of the corresponding
column in a reference dataset, joined by a key column (or composite key).
Fires TRUE on inequality; NA when the key has no matching row in the
reference or when required columns / dataset are absent.

## CDISC source

SDTM-IG Conformance Rules v2.0. Rules assert "VAR = REFDS.REFCOL" for
a row identified by a join key, e.g. "VISITDY = TV.VISITDY" (CG0032),
"DSSTDTC = DM.DTHDTC" (CG0069).

## P21 conceptual parallel (reference only)

P21 SD-series rules with `val:Lookup Variable="%JOINKEY% == %REFKEY%"
Where="%VAR% != %REFCOL%"`. Herald expresses the same predicate via
`op_differs_by_key` in a single check leaf.

## P21 edge-case audit

- Null on ref side: op returns NA (advisory) -- matches P21's
  no-match -> rule-disable path.
- Composite key (e.g. STUDYID+VISITNUM or USUBJID+ETCD): columns are
  pasted with unit-separator before lookup; duplicate composite keys in
  the reference take the first occurrence (same as P21 pick-first).
- Empty / whitespace values: `op_differs_by_key` delegates to
  `!=` which propagates NA on NA inputs; no rtrim applied here
  (unlike ordinal ops) to match P21's null-is-null semantic.

## herald check_tree template

```yaml check_tree
all:
- operator: differs_by_key
  name: "%var%"
  reference_dataset: "%ref_dataset%"
  reference_column: "%ref_column%"
  key: "%key%"
```

## Expected outcome

Fires on rows where `var != ref_dataset.ref_column` for the same key.
Returns NA (advisory) when the key has no match in the reference.

## Batch scope

7 SDTM-IG rules: CG0032, CG0069, CG0217, CG0218, CG0367, CG0409, CG0414.
