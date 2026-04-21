# Rule-authoring interview log

Running record of Q&A used to drive narrative-rule conversion.
Options follow the convention: **(a) is always the recommended
approach**, alternatives rank-ordered after.

Use Ctrl-F on rule_id to find the decision that covers a rule.

---

## Q1 -- conditional-null cluster (24 SDTM rules)

**Cluster:** CG0141, CG0145, CG0159, CG0180-184, CG0225, CG0249,
CG0295, CG0296, CG0365, CG0366, CG0419, CG0459, CG0520, CG0523,
CG0524, CG0534, CG0649 and siblings.

All share assertion shape "VAR must be null" plus a bespoke English
condition per rule.

**Options offered:**
- (a) one reusable pattern per condition grammar -- `in-set`,
  `equal-literal`, `cross-dataset-lookup`; 4-5 primitives cover
  everything; future rules reuse.  *[recommended]*
- (b) hand-translate each rule's condition inline as a bespoke
  `when:` leaf.

**User answer:** (a).

**Decisions locked:**
- Build shared condition primitives first; reuse across rules.
- Keep (a) as the recommended path in all future option lists.

---

## Q2 -- CT-dependent conditional-null sub-cluster (~15 of the 24)

**Cluster:** conditions in Q1 that depend on CDISC Controlled
Terminology: CG0180-184 (LBORRES = continuous measurement),
CG0459, CG0649 (ISO 21090 null flavor), CG0523, CG0524 (subject
assignment sentinels), etc.

**Options offered:**
- (a) convert only the ~15 machine-translatable ones this pass,
  leave CT-dependent + pure-prose rules narrative with a
  `blocker_tag` note.
- (b) build a minimal CT-codelist lookup op (`value_in_codelist`)
  and a stub for prose semantics right now.

**User answer:** (b)-style -- go further than (a): "lets keep the
latest CT of sdtm and adam as rds, devise simplified elegant plan".

**Decisions locked:**
- Bundle latest SDTM + ADaM CT as RDS under `inst/rules/ct/` (copy
  heraldrules-v0: 492 KB + 3.4 KB; effective 2026-03-27).
- User-invoked `download_ct(package, version, dest)` to fetch NCI
  EVS releases into `tools::R_user_dir("herald","cache")`.
- `available_ct_releases()` merges bundled + cache + remote index.
- `load_ct(package, version)` with 4-way precedence:
  bundled | latest-cache | YYYY-MM-DD | explicit .rds path.
- `op_value_in_codelist(name, codelist, extensible, match_synonyms,
  package)` lazy-loads via `ctx$ct`.
- Maintainer workflow: `data-raw/ct-refresh.R` pulls latest to
  `inst/rules/ct/`.
- CRAN-safe: no network in `.onLoad`, inst/ under 5 MB.
- **Source URL**: NCI EVS at `https://evs.nci.nih.gov/ftp1/CDISC/`
  -- `/SDTM/`, `/ADaM/`, `/SEND/` with `Archive/` holding dated
  quarterly releases.

**Delivered (commit `d85aff0`):** inst/rules/ct/*.rds, R/ct-load.R,
R/ct-cache.R, R/ct-fetch.R, op_value_in_codelist, 33 tests,
value-flag-yn pattern (7 rules: ADaM-19..25).

---

## Q3 -- paired-variable consistency cluster (~70 rules)

**Cluster:** two sibling message families.

- **"within a dataset, there is more than one value of VAR1 for a
  given value of VAR2, considering only those rows on which both
  variables are populated"** -- 38 ADaM rules.
  Examples (numeric-char pairs that must be 1:1 per dataset):
  PARAM/PARAMN (740-741), STUDYID/STUDYIDN (802-803),
  SUBJID/SUBJIDN (817-818), SITEID/SITEIDN (822-823),
  USUBJID/USUBJIDN (812-813), BLQFL/BLQFN (837-838), etc.
- **"within a parameter, there is more than one value of VAR1 for
  a given value of VAR2"** -- 32 ADaM rules. Same shape, but the
  1:1 invariant is enforced per PARAMCD group. Examples:
  AVALCATy/AVALCAyN (327-328), CHGCATy/CHGCATyN (331-332),
  MCRITyML/MCRITyMN (340-341), ANRLO/ANRLOC (342-343), AyLO/AyLOC
  (347).

**Engine reuse:** the existing
`op_is_not_unique_relationship(name, value = {related_name,
group_by})` (in `R/ops-cross.R:28`) already covers both families.
The `group_by` slot is empty for "within a dataset", set to
`[PARAMCD]` for "within a parameter".

**Options offered:**
- (a) Two sibling patterns -- `paired-var-consistency-dataset`
  (no group_by) + `paired-var-consistency-param` (group_by
  PARAMCD). Both use the same op; only the group_by slot differs.
  Slot layout: (var1, var2). Converts all 70 rules cleanly.
  *[recommended]*
- (b) One parametric pattern with a conditional `group_by` slot
  that stays empty for "within a dataset". Single pattern doc,
  but the template MD gets harder to read.
- (c) Do only the 38 "within a dataset" rules now; punt the
  PARAMCD-grouped ones until later.

**User answer:** (a).

**Decisions locked:**
- Two sibling patterns, shared op.
- Reuse existing `uniqueness-grouped` for the 38 "within a dataset"
  rules (no group_by) -- no new pattern doc needed; 38 rows
  appended to `uniqueness-grouped.ids`.
- New `paired-var-consistency-param` for the 32 "within a parameter"
  rules (`group_by: PARAMCD`). Slots: `var_a`, `var_b`, `expand`.
- Guard: the existing op already ignores rows where either variable
  is NA, so no extra `non_empty` leaf is required.
- Rule scope stays whatever each YAML already declares.

**Engine fix landed alongside:**
- `.substitute_index` in `R/index-expand.R` now recurses into
  `value.related_name` / `value.group_by` so the `y` index placeholder
  resolves across all op args, not just leaf `name`. Previously the
  op got `related_name: "AVALCATy"` literal -> NA mask -> silent pass.

**Delivered (commit to follow):**
- 70 rules converted: 38 via `uniqueness-grouped`, 32 via
  `paired-var-consistency-param`.
- Tests: 2324 / 2324 (no new tests; existing uniqueness tests cover
  the shape).
- Progress: 626 -> 696 predicate.

---
