# value-not-null

## Intent

A named variable's value must not be null or empty in any record of
the dataset. Per-row check -- each null/empty value in the dataset
becomes a separate finding. Unlike presence-pair or
presence-forbidden, this pattern is **NOT** metadata-level; it
reads row content.

Canonical message form:
`<VAR> ^= null`

Using the CDISC passive-voice convention (same as
`presence-forbidden`), the message describes the compliant state
("VAR is not equal to null"). The rule fires when VAR IS null --
`empty(VAR)` returns TRUE under CDISC CORE semantics (TRUE =
violation).

## CDISC source

SDTMIG Section 4.1.5 designates certain variables as **Required**
(Core="Req"), meaning they must be included AND always populated.
CDISC's v2.0 conformance XLSX expresses the "always populated" half
as per-variable "VAR ^= null" rules.

Examples: `EPOCH ^= null` (epoch always populated); `RFSTDTC ^=
null` (reference start date required); `--DECOD ^= null` (coded
term always populated); `--ORRES ^= null` (original result always
populated).

## P21 conceptual parallel (reference only)

P21's `val:Required` primitive in
`ConditionalRequiredValidationRule.java` handles this: per-record
target, fires when `entry.hasValue()` is FALSE for the specified
Variable. P21's Variable attribute may be a single column or a
magic-variable pattern (`%Variables[*DECOD]%`) expanded at rule
instantiation. herald's `--VAR` wildcard serves the same purpose.

Difference: P21 also treats column absence as an "Unrecoverable"
disable-the-rule signal (no findings fired). herald's `empty` op
returns NA when the column is missing, surfacing as an advisory
("column not in dataset, can't verify"). Both are defensible; we
prefer surfacing the unverifiable case rather than silently
skipping.

## herald check_tree template

```yaml check_tree
all:
- name: %var_a%
  operator: empty
```

`empty` returns TRUE when the row's value is NA or an empty string.
Under `{all}` this fires per-row. `--VAR` expansion runs at walk
time (`R/rules-walk.R::.expand_wildcard_args`), so `--DECOD`
becomes `AEDECOD` on AE and the rule checks that column's values.

Message rendering substitutes `--` with the dataset's 2-char prefix
(`R/rules-findings.R` calls `.render_domain_prefix()`), so a
finding on AE reads `"AEDECOD ^= null"` rather than `"--DECOD ^=
null"`.

## Expected outcome

- Positive fixture: dataset has the column with at least one NULL
  row -> fires once per null row.
- Negative fixture: dataset has the column with all non-null values
  -> fires 0x.
- Column absent entirely: advisory (engine cannot verify).
- `provenance.executability` -> `predicate`.

## Scope considerations

Each rule's YAML carries the correct class / domain scope via the
standard normalisation -- `EVT`, `INT`, `FND`, etc. already handled
by `.rule_scope_matches_ctx` (commit 6b0a202).
