# herald rule-authoring patterns

Each pattern under this directory documents a conceptual category of CDISC
conformance rule plus the machinery to convert every narrative YAML in that
category to an executable `check_tree`.

Authoring flow (see `../../../.claude/plans/cached-nibbling-penguin.md`):

1. `discover-patterns.R` scans `tools/handauthored/cdisc/**/*.yaml`, clusters
   by `outcome.message` skeleton, updates `../progress.csv`.
2. Pick the largest unclaimed cluster, author this directory's
   `<pattern>.md` (intent, CDISC source, P21 conceptual parallel, herald
   `check_tree` template).
3. Build rule-id list + slot substitutions at `<pattern>.ids` (CSV;
   first column `rule_id`, additional columns fill template slots).
4. `apply-pattern.R --pattern <name> --ids patterns/<name>.ids` writes the
   rendered `check_tree` into every matching YAML and flips
   `provenance.executability` → `predicate`.
5. `Rscript tools/seed-fixtures.R` seeds golden fixtures for the converted
   rules under `tests/testthat/fixtures/golden/` and validates each via
   `validate()` during seeding.
6. Commit per pattern.

## Pattern naming

Kebab-case, semantic prefix. See the approved plan for the full vocabulary
(`presence-`, `value-`, `metadata-`, `uniqueness-`, `regex-`, `cross-`,
`dataset-`, `temporal-`).

## Clean-room P21 usage

P21's XML under `/Users/vignesh/projects/p21-community/configs/2204.0/` may
be consulted for **conceptual** understanding of how a CDISC rule is
typically validated (per-row vs metadata, grouped-by, conditional). Never
copy their XML, variable-expansion syntax, DSL expressions, or rule IDs
into herald. Each pattern doc records the P21 conceptual parallel in prose
as a cross-reference only.
