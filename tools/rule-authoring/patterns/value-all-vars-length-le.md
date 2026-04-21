# value-all-vars-length-le

## Intent

*"No character value may exceed `<N>` characters on any record,
across all character columns"*. Row-level check that sweeps every
character column and fires when at least one cell in that row has
a value longer than the byte-cap.

Canonical message form:
`The length of a character value is greater than <N> characters`

## CDISC source

SDTMIG Section 4.1.5.3.2 / ADaMIG Section 3 General Variable Naming
Conventions: character values must be ≤ 200 bytes (SAS Transport v5
storage format limit). Values longer than that require SUPPQUAL
splitting with `--TERM1`, `--TERM2`, etc.

## P21 conceptual parallel (reference only)

P21 SD1096 uses a complex `val:Lookup` to detect 200-char values
that might need SUPPQUAL splitting, then verifies the SUPPQUAL row
exists. herald's check is simpler -- it fires on any row with a
>200-char cell in any character column, leaving SUPPQUAL-pairing
verification as a separate reviewer step.

Shared P21 convention: row-level regex `.{0,200}` via
`val:Regex Variable=X Test=".{0,200}"` applied per cell. Our op
iterates all character columns and returns TRUE on rows with any
overflowing cell.

## P21 edge-case audit

| P21 behaviour | File:line | herald decision |
|---|---|---|
| `matcher.matches()` full-string bound (`.{0,200}` anchors implicit) | `RegularExpressionValidationRule.java:71` | `op_any_value_exceeds_length` checks `nchar(..., type="bytes") > N`; equivalent for the byte-count semantic. |
| rtrim trailing spaces before length count | `DataEntryFactory.java:313-328` | `sub("\\s+$", "", v)` before `nchar`. Matches. |
| Skip null cells | `RegularExpressionValidationRule.java:62` | `is.na(v)` -> FALSE (no fire). Matches. |
| Byte-length vs char-length for multi-byte UTF-8 | `nchar(type="bytes")` | same as P21 (String bytes). Matches for ASCII CDISC data. |

## herald check_tree template

```yaml check_tree
operator: any_value_exceeds_length
value: %max_len%
```

## Batch scope

1 rule: ADaM-17 (`value: 200`).
