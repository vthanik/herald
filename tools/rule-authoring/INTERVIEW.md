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

## Q4 -- conditional literal-assertion cluster (~21 SDTM rules)

**Cluster (outcome message + trigger condition per rule):**

- **VAR = LIT** (15 rules): CG0041 (AESER='Y'), CG0042 (AESER='N'),
  CG0043 (AESMIE='Y'), CG0067 (DSDECOD='DEATH'), CG0071
  (DSTERM='COMPLETED'), CG0133 (DTHFL='Y'), CG0140 (RACE='MULTIPLE'),
  CG0192 (MBTESTCD='ORGANISM'), CG0196 (PEORRES='NORMAL'),
  CG0525-0527 (RACE sentinels), CG0563 (RSDRVFL='Y'),
  CG0615 (MBTSTDTL='DETECTION'), CG0616 (MBTESTCD='MCORGIDN').
- **VAR in (LIT, ...)** (6 rules): CG0117 (ACTARM in 4 sentinels),
  CG0120 (ARM in 2), CG0124 (ACTARMCD in 4), CG0128 (ARMCD in 2),
  CG0174 (FAOBJ in --TERM/--TRT/--DECOD), CG0653 (SVPRESP in Y/null).

Shape: outcome is `<VAR> = '<LIT>'` or `<VAR> in (<LIT>,...)`;
firing happens only when the rule's condition is met (same Q1
condition grammar story).

**Options:**
- (a) Two patterns: `value-conditional-equal-literal` +
  `value-conditional-in-literal-set`. Both use the existing
  `equal_to` / `is_contained_by` ops plus an `all: [when:,
  assert:]` combinator wrapping the condition from Q1 primitives.
  Slots: `(var, literal | literal_list, when_clause)`.  *[recommended]*
- (b) Build a single parametric pattern that branches on whether
  the outcome is equal-literal vs in-set. One pattern doc to
  maintain; template logic grows.
- (c) Hand-translate each of the 21 inline -- no reuse.

**User answer:** _(pending)_

---

## Q5 -- ADSL <-> DM per-subject consistency (8 rules)

**Cluster:** ADaM-204..210, 367. All of the shape
*"ADSL.USUBJID = DM.USUBJID and ADSL.X != DM.X"*. X = AGE, AGEU,
SEX, RACE, SUBJID, SITEID, ARM, ACTARM.

**Existing engine:** `op_differs_by_key` already implements the
exact join-by-USUBJID-and-compare shape. No new op needed.

**Options:**
- (a) Author `adsl-dm-consistency` pattern with slots
  `(var, ref_dataset=DM)`. Rule scope stays `ADSL`. One .ids row
  per variable. Leverages the P21-aligned `.cdisc_value_equal`
  already baked into the op family (numeric + date fuzzy +
  POSIXct canonicalisation).  *[recommended]*
- (b) Extend `op_shared_values_mismatch_by_key` to accept a
  fixed subset of shared columns (SEX, RACE, etc.), one rule
  fires if ANY mismatches. Coarser -- P21 emits one finding per
  mismatching variable; (b) would merge them.

**User answer:** _(pending)_

---

## Q6 -- simple cross-dataset equality (10 rules)

**Cluster 1 (equality, 7 rules):** CG0032 VISITDY=TV.VISITDY,
CG0069 DSSTDTC=DM.DTHDTC, CG0217 TAETORD=SE.TAETORD, CG0218
EPOCH=SE.EPOCH, CG0367 RSUBJID=DM.USUBJID, CG0409
STUDYID=DM.STUDYID, CG0414 ETCD=TE.ETCD.

**Cluster 2 (membership, 3 rules):** CG0156 APID in POOLDEF.POOLID,
CG0157 RSUBJID in DM.USUBJID, CG0158 RSUBJID in POOLDEF.POOLID.

**Existing engine:** `op_matches_by_key` handles equality after
join; `op_missing_in_ref` handles "value present in ref column".
Neither needs a new op.

**Options:**
- (a) Two patterns reusing the existing ops:
  `value-equals-cross-dataset-col` (slots: var, ref_ds, ref_col,
  join_key) and `value-in-cross-dataset-col` (same slots).
  Both handle the "VAR.VAR" outcome shape.  *[recommended]*
- (b) Single composite pattern with a `mode: equal|in` slot.

**User answer:** _(pending)_

---

## Q7 -- cross-dataset presence pair (5 rules)

**Cluster:** ADaM-641..645. Shape:
*"AE.AESTDY is present but AESTDY is not present"*. Fires when
the source SDTM variable exists (AE.AESTDY) but the ADaM copy
is absent from the current dataset.

**Existing engine:** combination -- `exists(SDTM_DS.VAR)` joined
with `not_exists(ADaM_VAR)` via an `all:` combinator. `op_exists`
already handles dataset-qualified names via the crossrefs table
(`X.Y` reference resolution).

**Options:**
- (a) Author `cross-dataset-presence-pair` pattern using the
  `all: [exists(<ref_ds>.<var>), not_exists(<var>)]` combinator
  template. Slot `(ref_ds, var)`. Metadata-level.  *[recommended]*
- (b) Introduce new op `op_ref_col_populated_but_current_missing`
  for a single-leaf version.

**User answer:** _(pending)_

---

## Q8 -- unit-consistency cluster (7 rules)

**Cluster:** CG0186-0190 (LBORNRLO/HI, LBSTNRLO/HI/C expressed
using LBORRESU/LBSTRESU), CG0399 (--ULOQ vs --STRESU), CG0466
(--LLOQ vs --STRESU).

Shape: *"`<VAR>` is expressed using the units in `<UNIT_VAR>`"* --
per-row assertion that when VAR is populated, UNIT_VAR is also
populated AND VAR's implicit unit matches. In practice CDISC
interprets this narrowly: VAR present => UNIT_VAR present.

**Options:**
- (a) Narrow reading -- pattern `unit-variable-populated-when-var-populated`
  using `all: [non_empty(<var>), empty(<unit_var>)]` combinator.
  This catches the common case (LBORNRLO populated, LBORRESU
  missing). No unit-string equivalence done at validation time
  since CDISC doesn't define a unit-alias table here.  *[recommended]*
- (b) Build a unit-alias table (mg/mL == mg/ml == ...) and check
  VAR's declared unit matches UNIT_VAR's value. Requires
  curation; out of scope.

**User answer:** _(pending)_

---

## Q9 -- dataset-presence-in-study (10 rules)

**Cluster:** CG0191 (MB), CG0318 (PC), CG0368 (DM), CG0501 (TM),
CG0502 (TM), CG0646 (SJ), CG0373 (SUPP-- domain), CG0374
(RELREC), etc.

Shape: *"`<DOMAIN>` dataset present in study"*. Several are
conditional -- "IF the study collected X THEN domain Y is
required". Others are unconditional (DM is always required).

**Existing engine:** submission-level routing via
`scope.submission: true` + `op_not_exists(name=<DS>)` already
landed (ADaM-1 pattern). Same mechanism works here.

**Options:**
- (a) Pattern `submission-dataset-required` for the
  unconditional ones (CG0368 DM, CG0501/CG0502 TM, CG0646 SJ).
  Condition-bearing ones (CG0191 MB "if microbiology collected",
  CG0318 PC "if PK collected") need the Q1 condition grammar --
  defer until that lands.  *[recommended]*
- (b) Convert everything, stubbing unresolvable conditions as
  narrative leaves so the rule runs advisory-only.

**User answer:** _(pending)_

---

## Q10 -- composite-group uniqueness (39 rules)

**Cluster:** messages start with *"Within a given value of
`<OUTER>`, ..."* -- ADaM-127, 128, 131, 151, 221, 222, 224, 226,
and siblings. Shape extends Q3's paired-var-consistency with an
outer grouping scope (typically PARAMCD + an index), e.g.
*"Within a given value of PARAMCD, there is more than one value
of AVALCATy for a given value of AVAL"*.

**Existing engine:** `op_is_not_unique_relationship` already
accepts `group_by: [c1, c2, ...]`. No new op needed.

**Options:**
- (a) Author `uniqueness-grouped-nested` pattern with slots
  `(var_a, var_b, outer_keys, expand)` where `outer_keys` is a
  list (default `[PARAMCD]`, extensible to `[PARAMCD, BASETYPE]`
  for the subset that pins on BASETYPE as well).  *[recommended]*
- (b) Hand-author one pattern per outer-key shape (PARAMCD only,
  PARAMCD+BASETYPE, PARAMCD+USUBJID, ...).

**User answer:** _(pending)_

---

## Q11 -- suffix-pattern value checks (~20 rules)

**Cluster:**
- `*FL` (Y/N/null only): ADaM-5, 33, 34 and relatives.
- `*FN` (1/0/null): ADaM-26..32, 35, 36.
- `*DTF` (DATEFL CT): ADaM-39.
- `*TMF` (TIMEFL CT): ADaM-40.
- `*DT` / `*TM` / `*DTM` must be numeric: ADaM-58, 59, 60, 716.

Shape: for every column whose name matches a suffix wildcard,
apply a per-row value check (allowed-set) OR a type check
(class is numeric/POSIXct).

**Existing engine hooks:** `.expand_indexed`'s `stem` placeholder
matches "everything before the suffix" (regex `[A-Z][A-Z0-9]+`).
Value-checks plug into existing `is_contained_by`. Type-check
needs a tiny op.

**Options:**
- (a) Two pattern families -- `value-by-suffix-in-set` (uses
  stem-wildcard expansion over `<stem>FL` / `<stem>FN` and checks
  membership against {Y,N,null} / {0,1,null}) and
  `type-by-suffix-numeric` (new op
  `op_var_by_suffix_not_numeric` reading `class(col)`). Covers all
  20 rules.  *[recommended]*
- (b) One monolithic pattern with a `check_type` switch.

**User answer:** _(pending)_

---

## Q12 -- baseline-consistency compound rules (11 rules)

**Cluster:** ADaM-181, 182, 183, 354, 698, 699, 703, 744, 745,
789, 790. Shape:
*"BASETYPE is {not present | populated}, BASE/BTOXGR/BNRIND/ByIND
is populated, and BASE (etc.) is not equal to AVAL/ATOXGR/ANRIND
where ABLFL is equal to Y for a given value of PARAMCD for a
subject"*.

Semantics: within a subject's (PARAMCD [, BASETYPE]) group, find
the record with `ABLFL = 'Y'` and assert `BASE == AVAL` (or
sibling pair). Composite-key lookup with a selector row.

**Options:**
- (a) New op `op_base_not_equal_abl_row(base_var, analysis_var,
  group_keys, abl_col = 'ABLFL', abl_value = 'Y')` that does the
  per-group selector-row lookup. Pattern
  `baseline-equals-abl-row` converts all 11. Reusable for future
  baseline checks.  *[recommended]*
- (b) Express via a combinator chain using
  `op_is_not_unique_relationship` plus a custom r_expression per
  rule -- messier, rule-specific.

**User answer:** _(pending)_

---

## Q13 -- FDA Substance Registration System lookups (6 rules)

**Cluster:** CG0442, CG0443, CG0445, CG0446, CG0450, CG0451.
Shape: *"TSVAL is a valid preferred term from FDA Substance
Registration System (SRS)"* and *"TSVALCD is a valid unique
ingredient identifier from ... SRS"*.

The SRS (UNII) terminology is distinct from CDISC CT; not in
NCI EVS. FDA publishes it as a downloadable table
(https://precision.fda.gov/uniisearch or
https://www.fda.gov/industry/fda-resources-data-standards/).

**Options:**
- (a) Out of scope for the near-term bundle. Leave these 6 as
  narrative, tagged `blocker: ext-registry-srs`. Add SRS/UNII
  downloader in a follow-on once the FDA distribution URL is
  confirmed. Small enough to defer without losing coverage.  *[recommended]*
- (b) Piggyback on the CT downloader -- add an FDA SRS fetcher
  that lands `inst/rules/ct/srs-unii.rds` or a cache entry and
  wire a new op `op_value_in_srs_table`. Delivers the 6 rules
  but balloons scope.

**User answer:** _(pending)_

---

## Q14 -- long-tail small clusters (2-4 rules each, ~60 rules total)

**Residual:**
- *"At most one record per subject per epoch"* (3): CG0398,
  CG0536, CG0537 -- composite-key uniqueness with PARAM=null /
  DSSCAT handling.
- *"No more than N record per subject has VAR = LIT"* (2):
  CG0538, CG0539.
- *"On a given record, VAR is populated and VAR is present and
  not populated"* (2): ADaM-664, 669 -- cross-column nullability
  on same row.
- *"On a given record, more than one value of VAR for VAR"* (4):
  ADaM-891..894 -- same as Q10 but per-record (degenerate
  grouping).
- *"VAR is not equal to y or null"* (6): ADaM-176, 269, 270,
  271, 363, 619 -- trivially maps onto `value-conditional-equal-literal`
  from Q4.
- *"VAR is integer and > NUM"* (3): CG0284, CG0440, CG0457 -- TS
  domain numeric-range assertion.
- Plus ~30 singletons.

**Options:**
- (a) Handle them as **sub-questions of prior Q's when the shape
  already has an op/pattern** (e.g. Q4 covers "not equal to Y or
  null", Q10 covers "on a given record more than one value").
  For the genuinely unique shapes (epoch-uniqueness,
  max-N-per-subject, nullability-cross-column), author
  one-pattern-per-shape here. ~5 more small patterns, each with
  1-4 rules.  *[recommended]*
- (b) Skip the tail entirely -- coverage caps at ~1050/1814
  (58%). The tail rules are low-frequency in practice.

**User answer:** _(pending)_

---

## Backlog (after Q14)

Once Q4-Q14 are answered and converted, remaining narrative
rules (~50-80) will be true one-offs requiring bespoke translation
or CDISC-guidance clarification. Target: predicate coverage
80%+ (~1450/1814) after this interview cycle. Anything beyond
needs either external CT / registry bundles or new engine
primitives scoped individually.

