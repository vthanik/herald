# cross-lookup

## Intent

A row's value in one variable must exist as a value in another
dataset's column. Classic referential-integrity check --
e.g., every AE.USUBJID must appear in DM.USUBJID; every SV.VISITNUM
must appear in TV.VISITNUM.

Canonical message form:
`<VAR> in <REF_DOM>.<REF_COL>`

The message describes the COMPLIANT state (passive voice). Rule
fires when the row's `VAR` value is NOT in the target dataset's
column.

Examples:
- `USUBJID in DM.USUBJID` -- every record's subject must be a
  registered subject in the Demographics dataset.
- `VISITNUM in TV.VISITNUM` -- visit numbers must be defined in
  the Trial Visits dataset.
- `ARM in TA.ARM` -- arm labels must be defined in the Trial Arms
  dataset.
- `IETESTCD in TI.IETESTCD` -- inclusion/exclusion test codes must
  be defined in the Trial Inclusion/Exclusion dataset.

24 rules matched the simple form, all SDTM-IG.

## CDISC source

SDTMIG Section 8 (Representing Relationships and Data) and the
Trial Design Model datasets (TA, TE, TI, TM, TS, TV). These rules
assert referential integrity between a subject-level dataset and
its governing trial-design dataset.

## P21 conceptual parallel (reference only)

P21's `val:Lookup` primitive (`LookupValidationRule.java`)
implements the same concept: declare a `From` dataset and check
that each row's variable value exists there. herald expresses this
as `is_not_contained_by(VAR, DOM.COL)` where the engine's
`substitute_crossrefs` (from commit `7b4b010` plus dotted-ref
support in `dd2ae4d`) resolves `DOM.COL` to the unique non-NA
values of `datasets[[DOM]][[COL]]` at walk time.

When the reference dataset is missing from the submission, the
resolver logs an "unresolved_crossref" entry and the leaf short-
circuits to NA -- surfacing as one advisory per (rule x dataset)
rather than a silent false-pass.

## herald check_tree template

```yaml check_tree
all:
- name: %var_a%
  operator: is_not_contained_by
  value: %ref%
```

- `%var_a%` is the row-level column being checked.
- `%ref%` carries the dotted reference (e.g. `DM.USUBJID`). The
  engine's dotted-ref resolver expands it to the unique values at
  walk time.

TRUE (`var_a` value NOT in resolved set) = violation under CDISC
CORE semantics. Fires per row.

## Expected outcome

- Positive fixture: dataset with a row whose `var_a` value is NOT
  in the reference dataset -> fires.
- Negative fixture: `var_a` values all present in the reference
  dataset -> no fires.
- Reference dataset missing from submission: advisory (engine can't
  verify).
- `provenance.executability` -> `predicate`.

## Scope

All 24 rules are SDTM-IG. Per-rule YAML scope (domain / class) is
respected by herald's scope filter as usual. The reference datasets
(DM, TA, TV, TI, POOLDEF, SV) are standard SDTM domains present in
any conformant submission.
