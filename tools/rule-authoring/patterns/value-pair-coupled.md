# value-pair-coupled

## Intent

ADaMIG Section 3 defines paired analysis variables where the two
members must be co-populated on every record: when one is populated
the other must be too (and vice versa). Most commonly this is a
display-string / numeric-code pair (`TRT01P` / `TRT01PN`, `AVALCAT1`
/ `AVALCA1N`, `STRAT1R` / `STRAT1RN`, ...).

Each CDISC rule checks a single direction:

- `<VAR_A> is populated and <VAR_B> is not populated` -- fire when
  A is populated on a record but B is blank on the same record.

A companion rule (usually numbered `rule_id + 1`) checks the reverse
direction. Rules come in pairs.

Canonical message form:
`On a given record, <VAR_A> is populated and <VAR_B> is not populated`

## CDISC source

Rule messages derive from ADaMIG v1.2 Section 3.2, Tables 3.2.x
(treatment, stratum, category variables). Each YAML's
`provenance.cited_guidance` repeats the relevant table cell. Most
read: *"When <A> and <B> are present, then on a given record, either
both must be populated or both must be null."*

## P21 conceptual parallel (reference only)

P21 models the one-direction coupling as a `val:ConditionalRequired`
(`ConditionalRequiredValidationRule.java:47-55` -- when the `When=`
predicate is true on the record, require the target variable to have
value). Herald re-expresses this concept as `{all: [non_empty(A),
empty(B)]}` under the walker's NA-propagating combinator -- no XML or
DSL copy.

P21 edge-case parity audit (Java source cross-check):

| P21 behaviour | File:line | herald decision |
|---|---|---|
| **`hasValue()` returns `this.value != null`** after `DataEntryFactory.create()` already rtrim-nulls a string | `DataEntryFactory.java:242-244,313-328` | `op_non_empty` / `op_empty` apply `sub("\\s+$","",x)` + `nzchar(...)` before testing; "X  " populated, "   " null, literal "NULL"/"0" populated. ✓ |
| **Variable name UPPERCASED in constructor** (`.toUpperCase()`) | `ConditionalRequiredValidationRule.java:42`, `MatchValidationRule.java`, `Metadata.java:138,163,185` | Walker does case-insensitive `name` resolution against `names(data)` at `rules-walk.R:156-163` before dispatching to the op. ✓ |
| **Missing required variable -> `CorruptRuleException` (entire rule disabled for the dataset)** | `AbstractValidationRule.java:148-161` | `op_empty`/`op_non_empty` on a missing column return NA; under `{all}`, NA collapses the tree to NA -> one advisory per (rule x dataset). herald is MORE TRANSPARENT: P21 silently disables, herald surfaces "could not verify". |
| **Per-index iteration via `#`/`@`/`_` placeholder** (MagicVariable.regexify compiles to `[0-9]{n}`, `[A-Za-z]+` etc.) | `MagicVariable.java:198-223` | `.expand_indexed()` does the same thing with `xx/y/zz/w` placeholders mapped to `[0-9]{2}` / `[1-9]`. Independent implementation of the same idea. ✓ |
| **Per-index partial coverage** (if TRT01P+TRT01PN present but TRT02P present without TRT02PN, `CorruptRuleException` disables the full rule) | `AbstractValidationRule.java:148-161` | herald's expansion creates one instance per concrete index value; each instance evaluates independently. xx=01 can fire, xx=02 emits NA->advisory. MORE GRANULAR than P21. |
| **`When=` short-circuit returns -1 (skip)** when pre-condition false | `AbstractScriptableValidationRule.java` (`checkExpression(...)` return path) | herald's NA-propagation under combinators achieves the same skip semantics without an explicit `When` slot. ✓ |
| **Zero-match iteration stub** -- when the `#`/`@` pattern finds no matching columns, P21 never schedules the rule (implicit from regex non-match) | `MagicVariable.java` expansion loop | `.expand_indexed()` returns `{narrative: "no y-indexed columns present"}` which the engine treats as narrative -> advisory, NOT fire. ✓ |

Non-parity (intentional):

- **Label consistency** -- ADaMIG also implies paired variables should
  have semantically-related labels (TRT01P -> "Planned Treatment 1",
  TRT01PN -> "Planned Treatment 1 (N)"). P21 does not verify this;
  herald doesn't either. Out of scope for this pattern.
- **Type consistency** -- the `*N` member should be numeric while
  the stem is character. P21 does not verify type coupling; herald
  doesn't either. Out of scope.

## herald check_tree template

The template uses three slots: `var_a` (populated-check side),
`var_b` (empty-check side), and `expand` (placeholder name: `xx`, `y`,
`zz`, or `w`). For non-indexed pairs `expand` is empty and
`apply-pattern.R` renders a plain `{all}` tree.

```yaml check_tree
expand: "%expand%"
all:
- name: %var_a%
  operator: non_empty
- name: %var_b%
  operator: empty
```

**Note on YAML 1.1 booleans**: `y`, `w`, and any truthy token must
stay quoted as `"y"` / `"w"` through the full round-trip. `yaml`'s
default reader interprets bare `y:` / `yes:` as boolean `TRUE`, which
would collapse `expand: y` to `expand: TRUE` and break the
placeholder. The template wraps `%expand%` in double quotes so the
read parse preserves the string.

`.expand_indexed()` instantiates one sub-tree per concrete index value
found in the dataset's column list, wrapped under `{any}`. Any
instance with `A populated + B empty` fires.

## Expected outcome

- Positive: single-row dataset with `<VAR_A>` populated and `<VAR_B>`
  blank -> fires 1x.
- Negative: both populated -> fires 0x. Both blank -> fires 0x.
- `provenance.executability` -> `predicate`.

## Batch scope (54 of 54 candidate rules)

All 54 matching rules covered. Three mechanical shapes:

1. **Single placeholder** (48 rules, `expand: xx` / `y` / `zz` / `w`)
   -- `TRTxxP` / `TRTxxPN`, `MCRITyML` / `MCRITyMN`, `STRATwR` /
   `STRATwRN`. Different-stem pairs like `AVALCATy` / `AVALCAyN` also
   fit because `.collect_indexed_names_any()` unions the values
   found across both templates.
2. **Multi-placeholder** (4 rules, `expand: xx,y`) -- `TRxxPGy` /
   `TRxxPGyN` combines both `xx` AND `y` in the same name. The engine
   compiles one regex per template (e.g. `^TR([0-9]{2})PG([1-9])N$`),
   iterates the Cartesian product of (xx, y) tuples actually found
   in columns, and substitutes the whole tuple into each instance.
   Mirrors P21's `MagicVariable.regexify` which maps each `#` / `@`
   / `_` wildcard to a separate regex capture group
   (MagicVariable.java:198-223).
3. **Stem + index** (2 rules, `expand: stem,y`) -- `stemGRyN` /
   `stemGRy`. The `stem` placeholder is a prefix wildcard
   (`[A-Z][A-Z0-9]+`) that matches any alphanumeric root. The engine
   extracts per-column (stem, y) pairs the same way as multi-index;
   each discovered stem becomes its own instance (ATOX, BTOX, ...)
   so messages render as "ATOXGR1N is populated and ATOXGR1 is not
   populated" rather than the template form. Rule 375 / 376 scope
   to `classes: ALL` because CDISC's suffix-style text does not
   bind to a single ADaM structural class.

## Fixture strategy

Golden fixtures seeded per rule by `tools/seed-fixtures.R`: minimal
ADSL (or class-appropriate) dataset with two rows and columns named
per the probed-index value; positive leaves `<VAR_A>` populated and
`<VAR_B>` blank, negative inverts.
