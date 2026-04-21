# dataset-label-match

## Intent

*"A dataset named `<DATASET>` must have the dataset label
`<EXPECTED>`"*. Fires once per (rule x dataset) when the in-scope
dataset's `attr(., "label")` does not match the expected string
(case-insensitive, whitespace-trimmed).

Canonical message form:
`A dataset is named <DATASET> and the dataset label is not
"<EXPECTED>"`

## CDISC source

ADaMIG v1.0 Section 3.1: the ADSL dataset label must be
`Subject-Level Analysis Dataset`. Other named datasets have
reserved labels similarly.

- ADaM-320: ADSL -> "Subject-Level Analysis Dataset".

## P21 conceptual parallel (reference only)

P21 uses `val:Match` with `%Dataset.Define.Label%` against the
Define-XML label entry. herald reads the label from
`attr(data, "label")`, which the XPT and Dataset-JSON readers
populate at ingest.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| Case-sensitive default | `String.equals` | herald trims and upper-cases both sides before compare. More forgiving; matches CDISC authoring intent (labels aren't case-authoritative). |
| Trailing whitespace ignored | P21 runs `trim()` at ingest | herald `trimws()` both sides. Matches. |
| Missing label -> rule-disable | `MagicVariable.isMissing` | herald returns NA mask when label attribute is absent -> advisory. Matches P21 semantics. |

## herald check_tree template

```yaml check_tree
operator: dataset_label_not
expected: %expected%
```

Slots:
- `expected` -- the required dataset label string.

Scope is rule-defined (e.g. `classes: SUBJECT LEVEL ANALYSIS
DATASET` for ADaM-320). The op reads the current dataset's label
attribute; it does not cross-reference other datasets.

## Expected outcome

- Positive: dataset label differs from `expected` (after trim +
  case fold) -> fires once.
- Negative: labels match -> no fire.
- Label attribute absent -> NA -> advisory.

## Batch scope

1 rule: ADaM-320 (ADSL label).
