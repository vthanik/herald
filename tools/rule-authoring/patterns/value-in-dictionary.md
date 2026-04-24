# value-in-dictionary

## Intent

Row-level assertion that a variable's value is a valid member of a
user-registered external clinical dictionary (MedDRA, WHO-Drug, etc.).
Fires when the value is NOT found in the named dictionary at the given
field/level. Returns NA (advisory) when the dictionary is not
registered, so the rule stays predicate without blocking validation.

Canonical message form:
`<VAR> = <DictName> <level>`

## CDISC source

SDTM variables that must hold valid entries from a licensed external
dictionary (MedDRA or WHO-Drug). The dictionary-derived variable pair
(term + code) is required to match the corresponding level of the
hierarchy. Rules are scoped to EVT class domains (typically AE, CM).

MedDRA levels supported:
- `llt` / `llt_code` -- Lowest Level Term / code
- `pt` / `pt_code` -- Preferred Term / code
- `hlt` / `hlt_code` -- High Level Term / code
- `hlgt` / `hlgt_code` -- High Level Group Term / code
- `soc` / `soc_code` -- System Organ Class / code

## P21 conceptual parallel (reference only)

P21 performs dictionary validation via its DictionaryValidator
(DictionaryValidator.java) which loads MedDRA from a configured path
and checks row values against the cached hierarchy. herald expresses
the same check via the Dictionary Provider Protocol:
`register_dictionary("meddra", meddra_provider(path, version))`.
When no provider is registered the op returns NA advisory with an
actionable message, matching P21's behaviour of disabling the check
when the dictionary path is unconfigured.

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| Case-sensitive term comparison by default | `contains()` is case-sensitive by default. Matches. |
| Trailing-space trimming before lookup | Op trims trailing spaces via `sub(" +$", "", ...)`. Matches. |
| NA / empty value: P21 skips (no fire) | herald returns NA for empty values (advisory). Conservative. |
| Unknown field: P21 disables rule | herald returns NA mask when `contains()` returns all-NA. Matches. |
| No dict registered: P21 logs warning, skips rule | herald records missing_ref -> advisory. More explicit. |

## herald check_tree template

```yaml check_tree
operator: value_in_dictionary
name: %var%
dict_name: %dict_name%
field: %field%
```

Slots:
- `var` -- the SDTM variable (may use `--` wildcard).
- `dict_name` -- registered dictionary name (e.g. `meddra`).
- `field` -- provider field to check (e.g. `pt`, `soc`, `pt_code`).

## Expected outcome

- Positive: fixture with a row whose `<var>` value is NOT in the
  dictionary at `<field>` -> fires (TRUE).
- Negative: all rows have valid dictionary entries -> fires 0x.

Note: fixtures cannot inject the dictionary -- the op returns NA
(advisory) when no dict is registered, so end-to-end integration
testing requires a registered provider.

## Batch scope

12 rules:
- CG0377 (`--LLT = MedDRA lowest level TERM`), dict_name=meddra, field=llt
- CG0378 (`--LLTCD = MedDRA lowest level code`), field=llt_code
- CG0379 (`--DECOD = MedDRA preferred TERM`), field=pt
- CG0380 (`--PTCD = MedDRA preferred TERM code`), field=pt_code
- CG0381 (`--HLT = MedDRA high level TERM`), field=hlt
- CG0382 (`--HLTCD = MedDRA high level TERM code`), field=hlt_code
- CG0383 (`--HLGT = MedDRA high level group TERM`), field=hlgt
- CG0384 (`--HLGTCD = MedDRA high level group TERM code`), field=hlgt_code
- CG0385 (`--BODSYS = MedDRA system organ class`), field=soc
- CG0386 (`--BDSYCD = MedDRA system organ class code`), field=soc_code
- CG0436 (`--SOC = MedDRA primary system organ class`), field=soc
- CG0437 (`--SOCCD = MedDRA primary system organ class code`), field=soc_code

All SDTMIG v3.2+, scope EVT/ALL, severity Medium.
