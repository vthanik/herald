# submission-dataset-required

## Intent

A specific CDISC domain dataset MUST be present in the submission.
Fires when the domain is absent from the loaded dataset map.

Used for unconditional required domains (DM is always required in every
human study; TM is required whenever MIDS or RELMIDS is used).

These rules are evaluated at the submission level -- once per validate()
call, not once per dataset. The finding dataset is `<submission>`.

## CDISC source

SDTM-IG Conformance Rules v2.0:
- CG0368 -- DM dataset present in study (Model v1.4 2.2.6)
- CG0501 -- TM dataset present in study (Model v1.7 2.2.5, via MIDS)
- CG0502 -- TM dataset present in study (Model v1.7 2.2.5, via RELMIDS)

## P21 conceptual parallel (reference only)

P21 checks submission-level dataset presence via SubmissionValidator.java
validateDatasetList(). herald routes via scope.submission: true + op_not_exists.

## P21 edge-case audit

- P21 does not fire when the submission has zero datasets loaded. herald
  likewise defers to op_not_exists(.ds_present) which returns FALSE when
  ctx$datasets is NULL or empty.
- TM check: P21 fires TM-required only when any dataset contains MIDS or
  RELMIDS. CG0501/CG0502 route via unconditional
  submission-required to match the "must be present" assertion. The condition
  (MIDS or RELMIDS present) is captured in scope.domains / the existing YAML
  condition narrative; the engine assertion is op_not_exists(TM).

## herald check_tree template

```yaml check_tree
operator: not_exists
name: %dataset%
```

## Expected outcome

- Positive fixture: submission lacks %dataset% -> op_not_exists fires -> 1 finding.
- Negative fixture: submission includes %dataset% -> op_not_exists passes -> 0 findings.
- `provenance.executability` -> `predicate`.
- `scope.submission: true` must be present in the YAML.

## Batch scope

Rules: CG0368 (DM), CG0501 (TM), CG0502 (TM).
