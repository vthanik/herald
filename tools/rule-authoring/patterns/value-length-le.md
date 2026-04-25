# value-length-le

## Intent

SDTMIG specifies maximum character lengths for controlled-terminology
code variables and certain free-text labels. E.g. `ACTARMCD` is
limited to 20 characters, `SETCD` / `ETCD` / `TSPARMCD` to 8, `TSPARM`
and `QLABEL` to 40. Each CDISC rule asserts the value byte-length on
every record falls within the published cap.

Canonical message form:
`<VAR> value length <= <NUM>`

## CDISC source

Rule messages come from SDTMIG-specific variable specifications in
the Trial Design, Special Purpose, and Supplemental Qualifier tables.
Each YAML's `provenance.cited_guidance` quotes the sentence
constraining the variable (e.g. *"ACTARMCD is limited to 20
characters..."*).

## P21 conceptual parallel (reference only)

P21 implements value-length caps via `val:Regex Variable="<VAR>"
Test=".{0,N}" Target="Data"` -- compile a regex with a bounded
repetition and run `matcher.matches()` per record
(`RegularExpressionValidationRule.java:55-77`). The record passes
when `matches()` returns true (length within bound) and fails
otherwise.

herald re-expresses the concept with its existing `longer_than(name,
value)` op: for each record, returns TRUE when
`nchar(<col>, type = "bytes") > value` (byte-length, matching SAS
XPT column-width semantics). No XML or Java copy.

## P21 parity folded into `longer_than`:

- **Byte-length, not character count** -- SAS XPT stores byte lengths;
  `nchar(..., type = "bytes")` matches P21's underlying character
  count in `DataEntryFactory.java` (Java Strings are code-unit
  counted, equivalent to bytes for ASCII / Latin-1 CDISC data).
- **NA passes** -- `longer_than` returns NA for NA inputs, so under
  `{leaf}` NA propagates to advisory rather than firing. P21's
  `RegularExpressionValidationRule.performValidation` returns pass
  (`return 1`) when `entry.hasValue() == false`
  (line 62) -- equivalent semantics.
- **rtrim whitespace** -- not applied to the length check. SAS XPT
  preserves trailing spaces as part of the stored value; both P21
  (regex over raw string) and herald treat the full byte length. A
  rule author who wants rtrimmed length should pre-trim at the
  ingest layer.

## herald check_tree template

The template uses two slots: `var` (column name) and `max_len`
(integer cap).

```yaml check_tree
operator: longer_than
name: %var%
value: %max_len%
```

`longer_than` fires TRUE (violation) on every row whose value exceeds
`max_len` bytes. Missing/NA values pass.

## Expected outcome

- Positive fixture: single-row dataset with `<VAR>` set to a value of
  length `max_len + 1` (e.g. 21 chars for a 20-cap rule) -> fires 1x.
- Negative fixture: `<VAR>` set to a value of length `max_len` (or
  shorter) -> fires 0x.
- `provenance.executability` -> `predicate`.

## Batch scope (8 of 8 candidate rules)

All 8 matching rules converted. Domains span DM, TA, TS, TV, and
SUPP-- (QLABEL under Supplemental Qualifiers). `tools/seed-fixtures.R`
picks the scope-declared domain and builds a minimal dataset with a
single row whose `<VAR>` cell has the target length.
