# unit-variable-required-when-var-populated

## Intent

*"When `<var>` is populated with a numeric value, `<unit_var>` must also be
populated."* Fires per record when `var` is present and looks numeric but
`unit_var` is missing.

The numeric guard (`matches_regex` with a standard decimal pattern) is included
to avoid false positives on character-result fields like LBSTNRC where values
such as "0.8 - 1.2 mg/dL" are normal and do not require a companion unit.

Canonical message form: `<var> is expressed using the units in <unit_var>`

## CDISC source

SDTMIG v3.2-3.4: LB range columns (CG0186-0190) and general quantitative
assay limit columns (CG0399 --ULOQ, CG0466 --LLOQ). The conformance language
is "`<VAR>` is expressed using the units in `<UNIT_VAR>`", interpreted as:
VAR populated => UNIT_VAR populated.

## P21 conceptual parallel (reference only)

P21 encodes the same shape on result columns via SD0026 (`--ORRESU` required
when `--ORRES` is populated and looks numeric) and SD0029 (`--STRESU` required
when `--STRESC` or `--STRESN` populated). Both rules apply a regex guard to
restrict the check to numeric-looking values and carry an exemption list for
non-quantitative test types (Ratio, Antibody, Count, PH, SPGRAV, R2, R2ADJ,
STAT='NOT DONE').

Herald narrows to the numeric-only case and defers the test-type exemption
list -- the LB range and LOQ fields are always numeric by definition, and the
broader exemption list applies to a later cluster (CG0425).

## P21 edge-case audit

| P21 behaviour | herald decision |
|---|---|
| `@re` numeric guard: `^[-+]?[0-9]*\.?[0-9]+$` | Matched exactly; `matches_regex` with the same pattern. |
| `hasValue()` post-rtrim on UNIT_VAR | `op_empty` rtrims then `nzchar`-tests; `"   "` is empty. Matches. |
| Missing column on either var -> `CorruptRuleException` silences rule | Both `op_non_empty` and `op_empty` return NA mask on missing column; `{all}` propagates NA -> advisory. Matches spirit. |
| Test-type exemption list (Ratio, Antibody, ...) | NOT applied for this batch; deferred to CG0425. |

## herald check_tree template

```yaml check_tree
all:
- operator: non_empty
  name: %var%
- operator: matches_regex
  name: %var%
  value: "^[-+]?[0-9]*\\.?[0-9]+$"
- operator: empty
  name: %unit_var%
```

Slots:
- `var`      -- the numeric variable that must have a companion unit
- `unit_var` -- the unit variable that must be populated when var is numeric

## Expected outcome

- Positive: `var` is populated with a numeric string (e.g. "1.5") AND
  `unit_var` is null/empty -> fires on that row.
- Negative: `var` is null, or `var` is non-numeric text, or `unit_var` is
  populated -> no fire.

## Batch scope

7 rules:
- CG0186: var=LBORNRLO, unit_var=LBORRESU (LB original lower ref range)
- CG0187: var=LBORNRHI, unit_var=LBORRESU (LB original upper ref range)
- CG0188: var=LBSTNRLO, unit_var=LBSTRESU (LB standard lower ref range)
- CG0189: var=LBSTNRHI, unit_var=LBSTRESU (LB standard upper ref range)
- CG0190: var=LBSTNRC,  unit_var=LBSTRESU (LB standard ref range character;
  numeric guard prevents false positives on range strings like "0.8 - 1.2")
- CG0399: var=--ULOQ,   unit_var=--STRESU (upper limit of quantitation)
- CG0466: var=--LLOQ,   unit_var=--STRESU (lower limit of quantitation)
