# metadata-var-name-length

## Intent

*"No variable name may exceed `<N>` characters"*. Metadata-level
check: fires once per dataset when any column name is longer than
the byte-cap. Default cap for CDISC-conformant datasets is 8
(SAS v5 XPT limit).

Canonical message form:
`The length of a variable name exceeds <N> characters` /
`Variable name length <= <N>`

## CDISC source

ADaMIG Section 3.1.6 + SDTMIG Section 2.2.2: CDISC requires variable
names ≤ 8 characters (SAS Transport v5 limit). Rules ADaM-13 and
SDTM CG0310 cover the same assertion for their respective standards.

## P21 conceptual parallel (reference only)

P21's AD0013 combines length, start-with-letter, and word-chars-only
in one regex:

```
val:Regex ID="AD0013" Target="Metadata"
  Variable="VARIABLE"
  Test="[A-Z][A-Z0-9_]{0,7}"
```

P21 projects the variable list as a virtual metadata dataset (rows
of VARIABLE, LABEL, TYPE, LENGTH, ORDER) and regex-fails each row's
VARIABLE column. The `{0,7}` quantifier caps post-first-char length
at 7, for a total of 8 chars.

herald uses a dedicated `op_any_var_name_exceeds_length(value=N)`
that iterates `names(data)` directly and fires when any name
exceeds N bytes. Start-with-letter + word-chars-only checks are
expressed separately via `value-regex-format` patterns when those
rules come up (e.g. ADaM-144 / ADaM-145 for PARAMCD).

## herald check_tree template

```yaml check_tree
operator: any_var_name_exceeds_length
value: %max_len%
```

Metadata-level collapse via `.METADATA_OPS` -> one finding per
(rule × dataset).

## Batch scope

2 rules: ADaM-13, CG0310 (both use `value: 8`).
