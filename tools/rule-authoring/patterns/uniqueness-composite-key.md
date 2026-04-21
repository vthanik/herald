# uniqueness-composite-key

## Intent

*"The combination of `<KEY_1>, <KEY_2>, ...` must be unique within
the dataset"*. Fires on rows whose composite key (multi-column
tuple) is duplicated within the dataset.

Canonical message form: `<VAR> unique within <SCOPE>` or similar
(e.g. "SUBJID unique within a study").

## CDISC source

SDTMIG v3.2+ identifier-uniqueness rules:
  CG0150: `SUBJID unique within STUDYID`
  CG0151: `USUBJID unique within STUDYID` (across submission)
  CG0410: `VISITNUM unique within (STUDYID, USUBJID)` (per-subject
          visits)

## P21 conceptual parallel (reference only)

P21 uses `val:Unique Variable=<VAR> GroupBy=<key1,key2,...>` to
assert that within each distinct GroupBy tuple, the Variable's
distinct values count == the records count (i.e. no duplicates):

```
val:Unique PublisherID="CG0150"
  Variable = SUBJID
  When     = SUBJID != ''
  GroupBy  = STUDYID
```

P21's `Variable + GroupBy` semantic: each (STUDYID, SUBJID) tuple
must be unique. Equivalent to "the composite key (STUDYID, SUBJID)
has no duplicates". herald expresses this via
`op_is_not_unique_set(name = [STUDYID, SUBJID])` which counts
duplicate composite-key tuples and fires on every row in a
duplicated group.

## P21 edge-case audit (UniqueValueValidationRule.java)

| P21 behaviour | File:line | herald decision |
|---|---|---|
| GroupBy tuples are concatenated with a non-printable separator to avoid collisions | P21 `DataGrouping` hash-key | `op_is_unique_set` uses `do.call(paste, c(data[, names_vec], list(sep = "\x1f")))` -- Unicode unit separator as delimiter. Matches. |
| `Matching=Yes` mode: within each GroupBy tuple, Variable values must all be equal | `UniqueValueValidationRule.performValidation` | herald's `op_is_not_unique_relationship` covers this (in `uniqueness-grouped` pattern); `op_is_not_unique_set` handles the simpler composite-key-count form. Sibling patterns. |
| Null GroupBy tuple -> P21 excludes from grouping (When clause usually guards) | `FindValidationRule.java` When check | herald's `op_is_not_unique_set` treats NA keys as their own group (they'll all bucket together); CDISC rules typically guard with `var != ''`. Matches when a `non_empty` guard is added as a leaf. |
| `Matching=Yes` with null Variable -> excluded | similar | Same comment as above. |
| Missing required columns -> `CorruptRuleException` | `AbstractValidationRule.java:148-161` | `op_is_not_unique_set` returns NA mask -> advisory. |
| CaseSensitive=Yes default | default | herald's `paste`-based key is case-sensitive. Matches. |

## herald check_tree template

```yaml check_tree
operator: is_not_unique_set
name:
  - %key_1%
  - %key_2%
```

For 3-key composite (e.g. CG0410 with STUDYID, USUBJID, VISITNUM),
add a `key_3` slot or author the .ids with all slots listed.

## Expected outcome

- Positive: two rows share the same composite-key tuple -> both
  fire.
- Negative: every row has a unique composite-key tuple -> no fire.

## Batch scope

3 rules: CG0150 (SUBJID per STUDYID), CG0151 (USUBJID per STUDYID),
CG0410 (VISITNUM per STUDYID per USUBJID).
