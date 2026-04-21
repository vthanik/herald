# paired-var-consistency-param

## Intent

*"Within a parameter, there is more than one value of `<A>` for a
given value of `<B>`, considering only those rows on which both
variables are populated"*. Same 1:1 invariant as
`uniqueness-grouped` but the grouping is scoped per PARAMCD, not
per whole dataset. Fires on every row inside a violating
(PARAMCD, B) bucket.

Canonical message form:
`Within a parameter, there is more than one value of <A> for a
given value of <B>, considering only those rows on which both
variables are populated`

## CDISC source

ADaMIG Section 3, functional-dependency constraints for paired
variables WITHIN a parameter. Paired abbreviation + numeric or
label + code variables such as AVALCATy/AVALCAyN,
CHGCATy/CHGCATyN, MCRITyML/MCRITyMN, ANRLO/ANRLOC, AyLO/AyLOC,
BTOXGR/BTOXGRN, ATOXGRL/ATOXGRLN, BCHGCATy/BCHGCAyN.

32 rules; ADaM-IG. Many carry the `y` index placeholder (1-9).

## P21 conceptual parallel (reference only)

P21 expresses this with `val:Unique` and `GroupBy = STUDYID,
PARAMCD, <B>` plus `Matching = Yes`. herald reuses the same op
as `uniqueness-grouped` (`op_is_not_unique_relationship`), passing
`group_by = [PARAMCD]` in the `value:` block so the 1:1 invariant
is enforced per parameter rather than per dataset.

rtrim + NA semantics match the sibling pattern.

## herald check_tree template

```yaml check_tree
expand: "%expand%"
all:
- name: %var_b%
  operator: is_not_unique_relationship
  value:
    related_name: %var_a%
    group_by:
      - PARAMCD
```

- `name` is the group key per-PARAMCD.
- `value.related_name` is the dependent variable whose value must
  be unique per (PARAMCD, name).
- `expand` is `y` for indexed variable pairs (AVALCATy,
  CHGCATy, ...), empty for fixed-name pairs (ANRLO / ANRLOC).

## Expected outcome

- Positive fixture: two rows with identical (PARAMCD, B) but
  different A values -> both fire.
- Negative fixture: every (PARAMCD, B) combination has a single A
  value -> no fires.
- Rows with NA in either variable are excluded from the counting
  (matches the CDISC message's "considering only those rows on
  which both are populated" clause).

## Batch scope

32 rules: ADaM-327..334 (category / code), 340-341 (MCRIT),
342-351 (analysis range LO/HI + character), 381-388 (baseline
toxicity grade), 395-400 (analysis toxicity grade), 584-585,
588-589 (baseline change category).
