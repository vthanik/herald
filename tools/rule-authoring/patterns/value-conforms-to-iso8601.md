# value-conforms-to-iso8601

## Intent

*"`<VAR>` values must conform to ISO 8601 date or duration format"*.
Fires per record when the value is non-null and does NOT parse as
the declared format kind.

- `kind = "date"` -- SDTM extended ISO 8601 with dash-substitution
  for missing components (per SDTMIG 4.1.4). Accepts full dates,
  partial dates, and datetime strings.
- `kind = "duration"` -- ISO 8601 duration (e.g. `P2Y3M4DT6H`).

NA and empty values are advisory (NA returned, no fire).

## CDISC source

- CG0238: `--ORRES` in ISO 8601 date format (FND class, all domains).
  SDTMIG v3.2 4.1.4.9 -- dates stored as --ORRES results must be
  ISO 8601 formatted.
- CG0376: `TDSTOFF` = 0 or positive value in ISO 8601 Duration format.
  TD domain; SDTMIG v3.2 7.3 / Model v1.4 3.5.1.

## P21 conceptual parallel (reference only)

P21 uses `val:Regex Variable=X Test=<iso8601_pattern>` with
`matcher.matches()` (full-string). Herald uses `op_value_not_iso8601`
which applies the same validated regex internally; no per-rule inline
regex duplication needed.

## P21 edge-case audit

| P21 behaviour | Source | herald decision |
|---|---|---|
| Full-string regex match | `RegularExpressionValidationRule.java:71` | `op_invalid_date` / `.valid_iso8601_sdtm` uses anchored PCRE. Matches. |
| Null / missing -> skip (rule passes) | `entry.hasValue()` check | `op_value_not_iso8601` returns NA on null -> advisory, no fire. Matches. |
| Dash-substitution per SDTMIG 4.1.4 | P21 DATE_PATTERN allows dashes | `.valid_iso8601_sdtm` explicitly accepts dash-substituted partial dates. Matches. |
| Duration: P followed by at least one component | ISO 8601 duration grammar | `dur_re` in `op_invalid_duration` requires at least one designator after P; bare "P" rejected. Matches. |

## herald check_tree template

```yaml check_tree
operator: value_not_iso8601
name: %var%
kind: %kind%
```

Slots:
- `var`  -- column to validate (may use `--` wildcard prefix)
- `kind` -- `date` or `duration`

## Expected outcome

- Positive: record with a non-null value that is not valid ISO 8601
  of the specified kind -> fires.
- Negative: valid ISO 8601 value OR null/empty -> no fire.

## Batch scope

2 rules:
- CG0238: `--ORRES` date (FND domains) -- wildcard prefix, engine
  expands to the domain prefix at validate time.
- CG0376: `TDSTOFF` duration (TD domain).
