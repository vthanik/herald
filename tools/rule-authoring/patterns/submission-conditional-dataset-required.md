# submission-conditional-dataset-required

## Intent

A CDISC domain dataset is REQUIRED when the study collected a specific
category of data. The guard is supplied by `study_metadata` passed to
`validate(study_metadata = list(collected_domains = c("MB", "PC", ...)))`.

When `study_metadata` is not supplied, the `study_metadata_is` op returns
NA for every row, the `all:` combinator propagates NA, and the finding is
advisory ("this rule could not be evaluated: supply study_metadata").

When `study_metadata` is supplied and the domain is in `collected_domains`,
the guard fires (TRUE) and the paired `not_exists` check runs. If the
dataset is absent it fires a definitive finding.

## CDISC source

SDTM-IG Conformance Rules v2.0:
- CG0191 -- MB dataset present in study (if microbiology collected)
- CG0318 -- PC dataset present in study (if PK concentration data collected)

## P21 conceptual parallel (reference only)

P21 models this via study-level flags injected at validation startup
(StudyContext.java). herald surfaces it as an optional caller-supplied map.

## P21 edge-case audit

- When collected_domains does not contain the key domain the guard returns
  FALSE and the rule does not fire -- correct: domain not collected, dataset
  not required.
- When study_metadata is NULL the rule is advisory, not skipped. It appears
  in result$findings with status=advisory so the reviewer knows to check.

## herald check_tree template

```yaml check_tree
all:
- operator: study_metadata_is
  key: collected_domains
  value: %domain%
- operator: not_exists
  name: %dataset%
```

## Expected outcome

- Positive fixture (study_metadata supplied, domain collected, dataset absent):
  both ops fire -> 1 finding.
- Negative fixture A (dataset present): not_exists passes -> 0 findings.
- Negative fixture B (domain not in collected_domains): guard FALSE -> 0 findings.
- Advisory fixture (study_metadata NULL): all ops return NA -> advisory finding.
- `provenance.executability` -> `predicate`.
- `scope.submission: true` must be present in the YAML.

## Batch scope

Rules: CG0191 (MB), CG0318 (PC).
