# element-value-in-ref

## Intent

In the Trial Arms (TA) dataset, fires when an element code (`ETCD`) is
associated with more than one value of a reference dimension column
(`ref_col`). This identifies elements whose ELEMENT description would need to
be arm-agnostic (CG0322, where the dimension is ARM) or epoch-agnostic
(CG0323, where the dimension is EPOCH), because the element spans multiple
values of that dimension.

The pattern is scoped to both TE and TA domains. When applied to TE, the
`ref_col` (ARM or EPOCH) is absent and the operator returns NA (advisory).
When applied to TA, the operator checks that ETCD does not map to more than
one distinct value of the dimension column.

## CDISC source

SDTM-IG Conformance Rules v2.0:
- CG0322: "ELEMENT value does not refer to any specific ARM." Condition:
  "ELEMENT is associated with > 1 ARM." Cited guidance: "TESTRL should be
  expressed without referring to Arm. If the Element appears in more than one
  Arm in the Trial Arms dataset, then the Element description (ELEMENT) must
  not refer to any Arms."
- CG0323: "ELEMENT value does not refer to any specific EPOCH." Condition:
  "ELEMENT is associated with > 1 EPOCH." Cited guidance: parallel for EPOCH.

## P21 conceptual parallel (reference only)

P21 expresses these with a `val:Unique` on ETCD `GroupBy=ARM` (or EPOCH) to
identify multi-ARM / multi-EPOCH elements, then inspects ELEMENT text for
arm/epoch names (NLP step). Herald approximates the structural check only:
`op_is_not_unique_relationship(name=ETCD, related_name=ARM)` on TA detects
the multi-ARM condition that triggers the constraint. The NLP text-inspection
step is not automatable and is documented as a known gap.

## P21 edge-case audit

| Scenario | Herald decision |
|---|---|
| ETCD in TE absent from TA | Not checked by this pattern; covered by separate ETCD cross-reference rules. |
| TE domain (ARM/EPOCH absent) | Operator returns NA (advisory) -- column not present. |
| Single ARM per ETCD | Operator returns FALSE (pass) -- no violation. |

## herald check_tree template

```yaml check_tree
operator: is_not_unique_relationship
name: ETCD
value:
  related_name: "%ref_col%"
```

## Expected outcome

- Positive fixture (TA): two TA rows with the same ETCD but different ARM
  (or EPOCH) values -- both rows fire.
- Negative fixture (TA): each ETCD maps to exactly one ARM (or EPOCH) -- no
  rows fire.

## Batch scope

2 rules:
- CG0322 (TE + TA domains, ELEMENT variable, checks ETCD multi-ARM via
  ref_col=ARM)
- CG0323 (TE + TA domains, ELEMENT variable, checks ETCD multi-EPOCH via
  ref_col=EPOCH)
