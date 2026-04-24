# loinc-code-valid

## Intent

*"--LOINC = valid code in the version of the LOINC dictionary specified
in define.xml."* Fires when a row value in a `--LOINC` column is not
found in the LOINC dictionary registered for this validation run.

Returns NA (advisory) when:
- No `loinc` dictionary is registered via `register_dictionary()` /
  `loinc_provider()`.
- The column is empty or NA.

The LOINC version to use is declared in the define.xml
(`MetaDataVersion/def:Standard[@Name="LOINC"]/@Version`). The caller
is responsible for registering the correct version via `loinc_provider()`.

## CDISC source

SDTMIG Model v1.4 section 2.2.3. CG0400.

## P21 conceptual parallel (reference only)

P21 reads the LOINC version from define.xml and looks up codes against
a local LOINC distribution. herald expresses the same check via the
Dictionary Provider Protocol: `register_dictionary("loinc", loinc_provider(...))`.
The version declared in define.xml is informational; the user selects
the matching LOINC distribution when constructing the provider.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| Reads LOINC version from define.xml | caller responsibility -- pass correct version to loinc_provider |
| Empty --LOINC value: skip row | op returns NA for empty/NA values |
| No LOINC dict configured: rule disabled | missing_ref logged, NA advisory returned |

## herald check_tree template

```yaml check_tree
operator: value_in_dictionary
name: "--LOINC"
dict_name: loinc
field: loinc_num
```

The `--LOINC` name is the SDTM suffix wildcard for the topic variable
LOINC column (e.g. LBTEST LOINC -> LBLOINC).

## Expected outcome

- Positive: a row with an unrecognised LOINC code fires.
- Negative: all rows have valid LOINC codes -> no fire.
- Advisory: no loinc dictionary registered -> NA advisory (missing_ref
  logged in result$skipped_refs).

## Batch scope

1 rule: CG0400 (--LOINC valid per define.xml-declared LOINC version).
