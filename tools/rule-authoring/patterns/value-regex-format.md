# value-regex-format

## Intent

*"`<VAR>` values must (or must not) match a regex pattern"*. Fires
per record based on regex polarity. The `op` slot selects the
direction:

- `matches_regex` -- violation when value MATCHES (used when the
  regex describes the invalid shape, e.g. "contains a non-word
  character").
- `not_matches_regex` -- violation when value does NOT match (used
  when the regex describes the valid shape, e.g. "starts with a
  letter").

## CDISC source

ADaMIG Section 3.1.6 variable-naming conventions (same conventions
P21 encodes via `val:Regex` in its XML configs). Rule text:

  - "VAR starts with a character other than a letter" (144)
  - "VAR has characters that are not letters, digits, and
    underscores" (145)

## P21 conceptual parallel (reference only)

P21 uses `val:Regex Variable=X Test=<pattern>`:

```
val:Regex ID="AD0013"
  Target="Metadata"
  Variable="VARIABLE"
  Test="[A-Z][A-Z0-9_]{0,7}"
```

P21's Test is a COMPLIANT-state regex; `matcher.matches()`
full-string; failing the match = fire
(RegularExpressionValidationRule.java:71). herald's
`op_matches_regex` fires TRUE on match, so the polarity inverts
(herald uses `not_matches_regex` for the same CDISC rule).

## P21 edge-case audit

| P21 behaviour | Source | herald decision |
|---|---|---|
| `matcher.matches()` full-string anchor | `RegularExpressionValidationRule.java:71` | `.anchor_regex` wraps unanchored patterns in `^(?:...)$`; user-anchored `^` or `$` passes through. Matches. |
| Null cell -> `entry.hasValue() == false` -> skip (rule passes) | line 62 | `op_matches_regex` / `op_not_matches_regex` return NA on null; under single leaf -> advisory. Matches (no false fire). |
| Case-sensitive regex (no `(?i)` by default) | Pattern.compile | R's `grepl(perl=TRUE)` default is case-sensitive. Matches. |
| Missing column -> `CorruptRuleException` | `AbstractValidationRule.java:148-161` | NA mask -> advisory. More transparent. |

## herald check_tree template

```yaml check_tree
operator: %op%
name: %var%
value: '%pattern%'
```

Slots:
- `op`      -- `matches_regex` (fire on match) or `not_matches_regex`
  (fire on non-match)
- `var`     -- column to test
- `pattern` -- PCRE regex (herald anchors if unanchored)

## Expected outcome

- Positive: record with a value that violates the pattern -> fires.
- Negative: compliant values OR null cells -> no fire.

## Batch scope

2 rules:
- ADaM-144 (`not_matches_regex(PARAMCD, '^[A-Za-z]')`): PARAMCD must
  start with a letter.
- ADaM-145 (`matches_regex(PARAMCD, '[^A-Za-z0-9_]')`): PARAMCD
  contains a character outside the allowed alphanumeric+underscore
  set.
