# domain-code-format

## Intent

*"A domain-code or SRCDOM variable must conform to a structural format
(exact length in uppercase letters)."* Row-level regex check: fires when a
populated cell value does not match the required pattern.

Canonical message forms:
- `DOMAIN value length = 2` (CG0308)
- `DOMAIN value length = 4` (CG0309)
- `SRCDOM has a value that is not an SDTM domain name, ADaM dataset name, or null` (ADaM-746)
- `SRCDOM has a value that is not an SDTM domain name or null` (ADaM-180)

## CDISC source

- CG0308: SDTMIG v3.2 Section 2.2 -- each domain distinguished by a unique
  two-character code; applies to non-AP, non-RELREC domains.
- CG0309: SDTMIG v3.2 Section 2.2 -- AP-class domain codes are 4 characters.
- ADaM-746: ADaMIG v1.1 Section 3.3.9 -- SRCDOM must be a valid SDTM domain
  name or ADaM dataset name (or null).
- ADaM-180: ADaMIG v1.0 Section 3.2.8 -- SRCDOM must be a 2-character SDTM
  domain name (or null).

## P21 conceptual parallel (reference only)

P21 uses `val:Regex` with `Target="Data"` and a pattern that validates the
exact length (e.g. `^[A-Z]{2}$` for 2-char domain codes). herald re-expresses
this via the existing `op_not_matches_regex` leaf with a per-rule regex slot.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| Null / missing cell -> rule passes | `op_not_matches_regex` returns NA for NA/empty cells when `allow_missing = true` (default) |
| Case-sensitive match; CDISC domain codes are uppercase | regex patterns include only uppercase chars; CT values are uppercase |
| RELREC is excluded from CG0308 scope | Handled by `scope.domains` exclusion in the rule YAML |

## herald check_tree template

```yaml check_tree
operator: not_matches_regex
name: %var%
value: "%regex%"
```

Slots:
- `var`: column name to check (`DOMAIN` or `SRCDOM`)
- `regex`: positive-match regex; fires on non-match

## Expected outcome

- Positive: `DOMAIN = "ABCD"` under CG0308 (4 chars, not 2) -> fires.
- Negative: `DOMAIN = "AE"` under CG0308 (2 chars) -> no fire.
- Positive: `SRCDOM = "ABC"` under ADaM-180 (3 chars, not valid 2-char code) ->
  fires.
- Negative: `SRCDOM = "AE"` -> no fire. `SRCDOM = ""` -> no fire (null passes).

## Batch scope

4 rules: CG0308 (var=DOMAIN, regex=^[A-Z]{2}$), CG0309
(var=DOMAIN, regex=^[A-Z]{4}$), ADaM-746 (var=SRCDOM,
regex=^([A-Z]{2}|AD[A-Z0-9]{0,6})$), ADaM-180 (var=SRCDOM,
regex=^[A-Z]{2}$).
