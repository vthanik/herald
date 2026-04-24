# submission-domains-from-ref-column

## Intent

Each value in a reference column of a reference dataset must correspond to
a domain dataset that is present in the submission. Fires per row when the
domain code in `reference_column` is NOT among the loaded datasets.

Used for RELREC.RDOMAIN (every related-record reference must point to a
present domain) and SUPP--.RDOMAIN (every supplemental qualifier must
reference its parent domain).

## CDISC source

SDTM-IG Conformance Rules v2.0:
- CG0373 -- Dataset present in study with DOMAIN = SUPP--.RDOMAIN
  (IG v3.2 8.4.2: one SUPPQUAL per domain dataset; SUPP-- denotes source)
- CG0374 -- Dataset present in study with DOMAIN = RELREC.RDOMAIN
  (Model v1.4 4.1.1: RDOMAIN is the two-character domain abbreviation)

## P21 conceptual parallel (reference only)

P21 checks RELREC.RDOMAIN via val:Lookup against the loaded dataset list
(DatasetLookupValidationRule.java). herald replicates with
`op_ref_column_domains_exist` which checks each row's RDOMAIN value against
`names(ctx$datasets)`.

## P21 edge-case audit

- NA / empty RDOMAIN values produce NA per row (advisory), not a fire. CDISC
  allows a null RDOMAIN when the record references the study-level RELREC
  construct, so blank is not always an error.
- Domain comparison is case-insensitive (CDISC domain codes are uppercase
  by convention but comparisons should be forgiving).
- If RELREC or the SUPP-- dataset itself is absent, the op returns NA for
  all rows (the reference column is missing). Missing datasets are tracked
  in ctx$missing_refs as usual.

## herald check_tree template

```yaml check_tree
operator: ref_column_domains_exist
reference_column: %reference_column%
```

## Expected outcome

- Positive fixture (RDOMAIN="XY", XY dataset absent): op fires -> 1 finding per bad row.
- Negative fixture (RDOMAIN="DM", DM dataset present): op passes -> 0 findings.
- Advisory fixture (RDOMAIN is NA): op returns NA -> advisory.
- `provenance.executability` -> `predicate`.
- Rules are NOT submission-scoped -- they are per-dataset (RELREC, SUPP--).

## Batch scope

Rules: CG0373 (SUPP--, reference_column=RDOMAIN), CG0374 (RELREC, reference_column=RDOMAIN).
