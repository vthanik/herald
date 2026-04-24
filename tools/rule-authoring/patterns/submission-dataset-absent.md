# submission-dataset-absent

## Intent

A specific CDISC domain dataset MUST NOT be present in the submission.
Fires when the domain IS present in the loaded dataset map.

Used for domains that are explicitly prohibited in a given standard version
(e.g., SJ is not permitted in human clinical trials under SDTM-IG 3.4).

These rules are evaluated at the submission level -- once per validate()
call, not once per dataset. The finding dataset is `<submission>`.

## CDISC source

SDTM-IG Conformance Rules v2.0:
- CG0646 -- SJ dataset not present (Model v2.0 Subject Repro Stages:
  "Not in human clinical trials.")

## P21 conceptual parallel (reference only)

P21 has a parallel SubmissionValidator check for deprecated/prohibited
datasets. herald routes via scope.submission: true + op_exists.

## P21 edge-case audit

- When the submission has zero datasets, op_exists returns FALSE (no fire),
  which is correct: if there are no datasets the prohibited one isn't present.
- CG0646 is version-gated (SDTM-IG 3.4 only); standard_versions in the YAML
  already constrains application.

## herald check_tree template

```yaml check_tree
operator: exists
name: %dataset%
```

## Expected outcome

- Positive fixture: submission includes %dataset% -> op_exists fires -> 1 finding.
- Negative fixture: submission lacks %dataset% -> op_exists passes -> 0 findings.
- `provenance.executability` -> `predicate`.
- `scope.submission: true` must be present in the YAML.

## Batch scope

Rules: CG0646 (SJ).
