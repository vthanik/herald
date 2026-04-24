# relrec-idvar-seq

## Intent

A RELREC record-level rule of the form *"when `IDVAR` ends with `SEQ` (i.e.,
contains a `--SEQ` variable name), `RELTYPE` must be populated"*. The rule
fires when IDVAR matches the `.*SEQ` pattern AND RELTYPE is null on the same
row.

Canonical CDISC message: `RELTYPE = null`
Canonical condition: `IDVAR populated with a --SEQ value`

## CDISC source

SDTMIG v3.2 section 8.2.1 / 8.3.1 covering RELREC (Related Records special-
purpose dataset). IDVAR names the key variable used to join/merge records
between datasets. When IDVAR points to a sequence variable (e.g. `AESEQ`),
RELTYPE (which identifies the hierarchical level -- ONE or MANY) must be
populated because the relationship type is meaningful for record-level joins.
The cited guidance: "Values should be either ONE or MANY. Used only when
identifying a relationship between datasets."

Note: a complementary rule (CG0201, `value-conditional-regex-match` pattern)
handles the case where USUBJID and IDVARVAL are both null -- in that case
IDVAR must NOT be a --SEQ variable. CG0419 is the converse: when IDVAR IS a
--SEQ variable, RELTYPE must be present.

## P21 conceptual parallel (reference only)

P21 would express this as `val:Condition When="IDVAR @re '.*SEQ'" Test=
"RELTYPE == ''"`. Herald re-expresses as an `{all}` combinator of two leaves:
a `matches_regex` leaf on IDVAR and an `empty` leaf on RELTYPE. The `@re`
operator in P21 uses full-string matching (`Pattern.matcher.matches()`);
herald's `op_matches_regex` anchors via `.anchor_regex` to match the same
semantic. No XML or DSL copy.

## P21 edge-case audit

| P21 behaviour | herald |
|---|---|
| `@re` full-string match -- `.*SEQ` anchored to entire value | herald's `.anchor_regex` wraps unanchored patterns: `.*SEQ` -> `^(?:.*SEQ)$`. Matches P21. |
| Null IDVAR -> hasValue false -> condition not satisfied -> passes | `op_matches_regex` returns NA on null IDVAR; `{all}` propagates NA -> advisory. Functionally equivalent (no false fire). |
| Null RELTYPE -> empty -> violation when IDVAR matches | `op_empty` returns TRUE on null RELTYPE. Combined with TRUE from regex leaf, `{all}` fires. Correct. |
| Missing column -> CorruptRuleException, silent disable | Missing column returns NA mask -> advisory. More transparent. |

## herald check_tree template

```yaml check_tree
all:
- operator: matches_regex
  name: %idvar%
  value: '%seq_pattern%'
- operator: empty
  name: %reltype%
```

Slots:
- `idvar`        -- the variable identifying the key column (typically IDVAR)
- `seq_pattern`  -- regex matching --SEQ-style names (typically `.*SEQ`)
- `reltype`      -- the relationship-type variable (typically RELTYPE)

## Expected outcome

- Positive fixture: IDVAR="AESEQ", RELTYPE="" -> fires 1x.
- Negative fixture (a): IDVAR="AEGRPID", RELTYPE="" -> no fire (IDVAR does
  not end with SEQ).
- Negative fixture (b): IDVAR="AESEQ", RELTYPE="ONE" -> no fire (RELTYPE
  populated).
- `provenance.executability` -> `predicate`.

## Batch scope

1 rule: CG0419 (RELTYPE must be populated when IDVAR ends with SEQ).
Scope class: SPC (Special Purpose). Domain: RELREC.
