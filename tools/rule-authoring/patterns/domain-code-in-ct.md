# domain-code-in-ct

## Intent

*"The DOMAIN variable must contain a value that is a valid CDISC-published
Domain Code."* Row-level check using the bundled SDTM CT DOMAIN codelist.
Fires when a populated DOMAIN cell is not in the codelist.

Canonical message form:
`DOMAIN = valid Domain Code published by CDISC`

## CDISC source

SDTMIG v3.2+ Section 2.6. Rule CG0001 in the CDISC SDTM/SDTMIG Conformance
Rules v2.0. The DOMAIN codelist (short name "DOMAIN" in the SDTM CT) contains
the CDISC-reserved 2- and 4-character domain codes.

## P21 conceptual parallel (reference only)

P21 resolves CG0001 against its embedded SDTM CT via a `val:CT` check on the
DOMAIN column. herald delegates to the existing `op_value_in_codelist` op,
which auto-resolves the SDTM CT via the Dictionary Provider Protocol
(ct_provider("sdtm")). The DOMAIN codelist in SDTM CT is non-extensible;
sponsor custom domain codes that are not in the CT are intentionally allowed
by the rule condition ("Not custom domain"), so `extensible = true` is
appropriate here to pass unknown sponsor codes as advisory rather than error.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| Custom domain codes pass (not in CDISC reserved list) | `extensible: true` -- non-CT values pass; only NA -> advisory |
| DOMAIN must be present (CG0313 handles absence) | op returns NA when column absent; advisory only |
| Case-sensitive CT lookup | `op_value_in_codelist` uses `ignore_case = false` |

## herald check_tree template

```yaml check_tree
operator: value_in_codelist
name: DOMAIN
codelist: DOMAIN
extensible: true
package: sdtm
```

No slots required -- this is a single-rule pattern; the YAML is applied
directly to CG0001.

## Expected outcome

- Positive: DOMAIN = "XY" where "XY" is not in the CDISC DOMAIN codelist and
  is not a custom sponsor code (edge case: only fires for truly invalid codes
  when extensible=false; with extensible=true this is advisory).
- Negative: DOMAIN = "AE" (a CDISC-reserved domain code) -> no fire.

## Batch scope

1 rule: CG0001.
