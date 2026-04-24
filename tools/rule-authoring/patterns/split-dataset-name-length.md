# split-dataset-name-length

## Intent

*"An SDTM dataset name must have a length within a prescribed range."*
Metadata-level check: fires once per dataset when `nchar(dataset_name)` falls
outside `[min_len, max_len]`.

Canonical message forms:
- `Split dataset names length > 2 and <= 4` (CG0017)
- `Split dataset names length <= 8` (CG0018)
- `Suppqual dataset names <= 8 characters` (CG0205)

## CDISC source

SDTMIG v3.2 Section 4.1.1.7 (split domains may use names up to 4 chars;
AP-class dataset names are 4 chars; SUPPQUAL names up to 8 chars).
Rules CG0017, CG0018, and CG0205 in the CDISC SDTM/SDTMIG Conformance
Rules v2.0.

## P21 conceptual parallel (reference only)

P21 reads the dataset file name from the submission manifest (SubmissionInfo
.getDatasets()) and applies character-length checks per domain class. herald
uses `ctx$current_dataset` to obtain the current dataset name at evaluation
time, which is set by `rules-validate.R` before each dataset is walked.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| Dataset name is the stem without extension | `ctx$current_dataset` carries the name as registered in the submission, without extension |
| Only the split or SUPPQUAL datasets are checked (scope filter) | Herald scope filtering via `scope.classes` and `scope.domains` in the rule YAML handles dataset selection before the op is called |
| Length is in characters (ASCII dataset names) | `nchar(ds_name, type = "chars")` -- ASCII names only in CDISC context |

## herald check_tree template

```yaml check_tree
operator: dataset_name_length_not_in_range
min_len: %min_len%
max_len: %max_len%
```

Slots `min_len` and `max_len` are integers. Omit (set to empty) to skip the
corresponding bound check. CG0018 and CG0205 use only `max_len`; CG0017 uses
both.

## Expected outcome

- CG0017 positive: dataset named "AE" (len=2, below min_len=3) -> fires.
- CG0017 positive: dataset named "AECLIN" (len=6, above max_len=4) -> fires.
- CG0017 negative: dataset named "AESP" (len=4, within [3,4]) -> no fire.
- CG0018 positive: dataset named "SUPPQAL2X" (len=9 > 8) -> fires.
- CG0018 negative: dataset named "SUPPAE" (len=6 <= 8) -> no fire.

## Batch scope

3 rules: CG0017 (min_len=3, max_len=4), CG0018 (min_len=, max_len=8),
CG0205 (min_len=, max_len=8).
