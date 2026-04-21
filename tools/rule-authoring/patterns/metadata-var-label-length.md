# metadata-var-label-length

## Intent

*"No variable label may exceed `<N>` characters"*. Metadata-level
check: fires once per dataset when any column's LABEL attribute
exceeds the byte-cap. Default cap is 40 (CDISC standard).

Canonical message form:
`The length of a variable label is greater than <N> characters` /
`Variable label length <= <N>`

## CDISC source

ADaMIG Section 3.1.6 + SDTMIG Section 2.2.2: CDISC requires labels
≤ 40 characters. ADaM-16 and CG0311 cover both standards.

## P21 conceptual parallel (reference only)

P21's AD0016:

```
val:Regex ID="AD0016" Target="Metadata"
  Variable="LABEL"
  Test=".{0,40}"
```

Project variable list as metadata, regex-fail any LABEL row where
the value has >40 characters. herald iterates columns via
`op_any_var_label_exceeds_length(value=N)`, reading each column's
`attr("label")` directly. Null / empty labels are skipped (matching
P21's `hasValue() == false` skip at
`RegularExpressionValidationRule.java:62`).

## herald check_tree template

```yaml check_tree
operator: any_var_label_exceeds_length
value: %max_len%
```

Metadata-level collapse via `.METADATA_OPS`.

## Batch scope

2 rules: ADaM-16, CG0311 (both use `value: 40`).
