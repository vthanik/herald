# define-xml-key-uniqueness

## Intent

*"Each record is unique per sponsor-defined key variables as documented
in the define.xml."* Fires on rows whose composite key (as declared in
`ItemGroupDef[@def:KeyVariables]`) is duplicated within the dataset.

Returns NA (advisory) when:
- No `define` object is supplied to `validate()`.
- The dataset has no key variables declared in define.xml.
- All declared key columns are absent from the data.

## CDISC source

SDTMIG v3.2+ Table 3.2.1 -- sponsor-defined natural keys.
CG0019: unique per define.xml KeyVariables.

## P21 conceptual parallel (reference only)

P21 reads `ItemGroupDef[@KeyVariables]` (a space-separated list of
ItemOIDs) from the define.xml at startup, resolves OIDs to variable
names, then applies an `is_unique` check for each dataset. The key
list is per-dataset and varies by submission.

herald mirrors this via `op_key_not_unique_per_define` which reads
`ctx$define$key_vars[[dataset]]` at rule-evaluation time.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| KeyVariables OIDs resolved to variable names once at startup | herald resolves at `read_define_xml()` time, stores name list | 
| Missing define.xml -> rule disabled | herald returns NA advisory, records missing_ref | 
| Dataset not in define.xml -> rule disabled | returns NA advisory | 
| Column absent from data -> column dropped from key | present columns are checked; all absent -> NA advisory |
| Composite key with NA cell | NA rows get their own NA group; usually guarded by non_empty |

## herald check_tree template

```yaml check_tree
operator: key_not_unique_per_define
```

No arguments -- the key columns are resolved from `ctx$define$key_vars`
keyed on `ctx$current_dataset` at evaluation time.

## Expected outcome

- Positive: define.xml declares keys [STUDYID, USUBJID, SESEQ] for SE;
  two rows share the same tuple -> both fire.
- Negative: all rows have a unique composite-key tuple per define.xml
  -> no fire.

## Batch scope

1 rule: CG0019 (unique per sponsor-defined key variables from define.xml).
