# presence-forbidden

## Intent

A specific variable must **NOT** be present in the dataset. CDISC
restricts certain variables to nonclinical (SEND) contexts, or
forbids them in particular domains where they would duplicate
information in another domain. The rule fires when the named
variable IS a column in the dataset -- the presence is the
violation.

Canonical message form:
`<VAR> not present in dataset`

Note: the message describes the COMPLIANT STATE ("expected: VAR is
not present"), NOT the violation. The rule fires in the opposite
case -- when VAR IS present. This is the reverse of the
`presence-pair` pattern where the message describes the violation
directly. Rule authors followed this passive-voice convention in
CDISC's v2.0 conformance XLSX; herald preserves the message text
verbatim and the engine flips the semantic via the operator
(`exists` instead of `not_exists`).

## CDISC source

- **SDTMIG Section 2.7** -- variables allowed in SEND only,
  forbidden in human clinical SDTM: `FETUSID`, `RPHASE`, `RPPLDY`,
  `RPPLSTDY`, `RPPLENDY`, `--NOMDY`, `--NOMLBL`, `--RPDY`,
  `--RPSTDY`, `--RPENDY`, `--DETECT`, `--USCHFL`, `--METHOD`,
  `--RSTIND`, `--RSTMOD`, `--IMPLBL`, `--RESLOC`, `--DTHREL`,
  `--EXCLFL`, `--REASEX`, `SPECIES`, `STRAIN`, `SBSTRAIN`,
  `RPATHCD`.
- **Domain-specific restrictions** -- variables forbidden in a
  particular domain where they would duplicate data. Examples:
  `AEOCCUR / AESTAT / AEREASND` are not Qualifiers of AE
  (Events-class qualifiers that AE excludes);
  `EXVAMT / EXVAMTU` are forbidden in EX when EC is used;
  `TRLOC / TRLAT / TRDIR / TRPORTOT` are forbidden in TR because
  TU already carries the anatomical-location qualifiers.

## P21 conceptual parallel (reference only)

P21's approach differs: they mark these variables with
`val:Core="Prohibited"` on the `ItemRef` in the ItemGroupDef (e.g.
`<ItemRef ItemOID="IT.AE.AEOCCUR" ... val:Core="Prohibited"/>`).
Prohibited columns then fire via a generic metadata rule rather
than a dedicated per-variable Required/Find rule. herald doesn't
model `Core="Prohibited"` yet, so each forbidden variable gets its
own concrete rule with an `exists` predicate -- same outcome,
different factoring.

## herald check_tree template

```yaml check_tree
all:
- name: %var_a%
  operator: exists
```

Single-leaf `{all}`. TRUE (the variable IS in `names(data)`) =
violation; fires once per (rule x dataset) via the metadata-rule
collapse in `R/rules-validate.R::.is_metadata_rule`.

For `--VAR` rules (e.g. `--DTHREL`), `%var_a%` carries the literal
`--<STEM>` token; the engine's `.expand_wildcard_args()` substitutes
the dataset's 2-char domain prefix at walk time. Message rendering
does the same substitution via `.render_domain_prefix()`, so a
finding on AE shows `"AEDTHREL not present in dataset"` rather than
`"--DTHREL not present in dataset"`.

## Expected outcome

- Positive fixture: dataset HAS the forbidden column -> fires 1x.
- Negative fixture: dataset lacks the forbidden column -> fires 0x.
- `provenance.executability` -> `predicate`.

## Scope considerations

Each rule's YAML already carries the correct class / domain scope:

- AE-specific (CG0040, CG0044, CG0304) -> scope.domains = AE
- EX-specific (CG0105, CG0107) -> scope.domains = EX
- TR-specific (CG0299-302) -> scope.domains = TR
- Human-SDTM-wide rules (CG0509+ for FETUSID, RPHASE) -> scope
  classes = ALL or SPECIAL PURPOSE / DM

`apply-pattern.R` leaves `scope` untouched and only rewrites
`check` and `provenance.executability`, so these constraints survive.
