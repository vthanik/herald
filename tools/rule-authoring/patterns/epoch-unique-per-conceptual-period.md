# epoch-unique-per-conceptual-period

## Intent

Fires when a grouping column (`name`) maps to more than one value of a
related column (`related_name`), indicating that the grouping value is not
uniquely associated with a single conceptual trial period or element
description. Two rules share this shape:

- **CG0250 (TA):** Each value of `EPOCH` must map to exactly one trial period
  (`TAETORD`). If EPOCH appears in multiple TAETORD values, the EPOCH label is
  ambiguous across periods.
- **CG0325 (TE):** Each `ETCD` (element code) must have exactly one `ELEMENT`
  description. If the same ETCD has multiple ELEMENT texts, the element
  definition is inconsistent.

## CDISC source

SDTM-IG Conformance Rules v2.0:
- CG0250: "Each value of EPOCH is not associated with more than one conceptual
  trial period." Section IG v3.2 7.2.
- CG0325: "The combination of ELEMENT, TESTRL, TEENRL, and TEDUR is unique for
  each ETCD." Assumption 15: "Elements that have different start and end rules
  are different Elements and must have different values of ELEMENT and ETCD."

## P21 conceptual parallel (reference only)

P21 expresses these as `val:Unique Variable=<related> GroupBy=<name>` with
`Matching=Yes` (each unique grouping value maps to exactly one related value).
Herald uses `op_is_not_unique_relationship(name, value.related_name)` which
fires all rows in a violating group.

## P21 edge-case audit

| Scenario | Herald decision |
|---|---|
| NA in `name` or `related_name` | Row excluded from uniqueness count (same as P21). |
| Trailing whitespace | Both columns are rtrim-normalised before comparison. |
| Fires only 2nd+ duplicate (P21 Matching=Yes) | Herald fires ALL rows in violating group. Documented deviation (CONVENTIONS.md section 4). |

## herald check_tree template

```yaml check_tree
operator: is_not_unique_relationship
name: "%name%"
value:
  related_name: "%related_name%"
```

## Expected outcome

- Positive fixture: two rows with the same `name` value but different
  `related_name` values -- both rows fire.
- Negative fixture: every `name` value maps to exactly one `related_name`
  value -- no rows fire.

## Batch scope

2 rules:
- CG0250 (TA domain, EPOCH -> TAETORD, TDM class)
- CG0325 (TE domain, ETCD -> ELEMENT, TDM class)
