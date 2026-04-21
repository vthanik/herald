# Rule-authoring interview log

Running record of Q&A used to drive narrative-rule conversion.
Options follow the convention: **(a) is always the recommended
approach**, alternatives rank-ordered after.

Use Ctrl-F on rule_id to find the decision that covers a rule.

## Coverage commitment (set at Q20)

| state | max share | current (696 / 1814) | post-cycle target |
|---|---:|---:|---:|
| `predicate` | -- | 38.4% | **>= 95%** |
| `narrative` | 0 | 61.6% | 0 |
| `blocker:<reason>` | < 5% | 0 | <= 90 rules |
| `drop:` / `deprecated:` | -- | 0 | only when CDISC retires a rule |

Every Q4-Q20 decision is executed with this target in mind.
Prior deferrals (Q9 study metadata, Q13 FDA SRS, Q11 CT
confirmation, Q2 LB continuous-measurement, Q14 singletons) are
all wired to concrete implementation paths -- no "park
indefinitely" allowed. See Q20 for the stretch plan.

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

**User answer:** (a).

**Decisions locked:**
- Two patterns: `value-conditional-equal-literal`,
  `value-conditional-in-literal-set`.
- Both reuse existing ops (`equal_to`, `is_contained_by`) under
  an `all: [when: ..., assert: ...]` combinator.
- Condition leaves share the Q1 primitive library (to be built
  alongside the Q1 CT/conditional-null work).
- Slots: `(var, literal | literal_list, when_clause)`.

**Delivered:** _(pending -- deferred to user implementation)_

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

**User answer:** (a).

**Decisions locked:**
- Pattern `adsl-dm-consistency`; no new op (reuses
  `op_differs_by_key`).
- Slots: `(var, ref_dataset=DM, ref_column=var, key=USUBJID)`.
- 8 .ids rows: AGE, AGEU, SEX, RACE, SUBJID, SITEID, ARM, ACTARM.
- Scope = ADSL (each rule YAML already declares this).
- CDISC rule-ID granularity preserved -- one finding per
  mismatching variable (matches P21).

**Delivered:** _(pending -- deferred to user implementation)_

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

**User answer:** (a).

**Decisions locked:**
- Two patterns sharing existing cross-ops:
  - `value-equals-cross-dataset-col` -- uses `op_differs_by_key`
    (fires on inequality). Slots `(var, ref_dataset, ref_column,
    key)`; `key` accepts a list for multi-key joins.
  - `value-in-cross-dataset-col` -- uses `op_missing_in_ref`
    (fires when the ref column's value set doesn't contain this
    row's value).
- Multi-key joins (CG0032 STUDYID+VISITNUM, CG0218 USUBJID+ETCD)
  handled via list-valued `key` slot.
- Null-on-ref-side path (CG0069 DSSTDTC vs DM.DTHDTC) returns
  NA -> advisory in `op_differs_by_key`; matches P21.

**Delivered:** _(pending -- deferred to user implementation)_

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

**User answer:** (a).

**Decisions locked:**
- Pattern `cross-dataset-presence-pair` via combinator
  `all: [exists(<ref_ds>.<var>), not_exists(<var>)]`.
- Slots: `(ref_ds, var)`.
- Metadata-level (dataset-wide, not per-row).
- 5 .ids rows: ADaM-641..645 against AE source.
- No new op.

**Delivered:** _(pending -- deferred to user implementation)_

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

**P21 audit (revised):** P21 doesn't encode CG0186-0190 / CG0399 /
CG0466 directly ("expressed using" -> 0 hits), but it encodes the
same intent on the RESULT columns via SD0026 (`--ORRESU` required
when `--ORRES` populated) and SD0029 (`--STRESU` / `--STRESC`).
Both add a `value looks numeric` regex guard and a test-type
exemption list (Ratio, Antibody, Count, PH, SPGRAV, R2, R2ADJ,
STAT='NOT DONE'). Adjacent: SD0007 (--STRESU unique per test
group), SD1353 (ORRES == STRESC when units match).

**User answer:** (a-refined).

**Decisions locked:**
- Pattern `unit-variable-required-when-var-populated`.
- check_tree combines three leaves:
  ```
  all:
    - operator: non_empty      name: <var>
    - operator: matches_regex  name: <var>
      value: "^[-+]?[0-9]*\\.?[0-9]+$"
    - operator: empty          name: <unit_var>
  ```
- Numeric-only guard mirrors P21's SD0026/SD0029 `@re` filter so
  character-result cases (LBSTNRC value "0.8 - 1.2 mg/dL") are
  handled without false positives.
- 7 .ids rows: CG0186..CG0190 (LB range pairs), CG0399 (--ULOQ /
  --STRESU), CG0466 (--LLOQ / --STRESU). `--VAR` wildcards already
  resolve via `.resolve_wildcard`.
- Test-type exemption list (Ratio / Antibody / Count / PH / ...)
  NOT applied for this batch -- the LB range + LOQ fields are
  always numeric by definition. When we later author CG0425
  (`--ORRESU` / `--ORRES`), extend to the full P21 guard list.

**Delivered:** _(pending -- deferred to user implementation)_

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

**User answer:** (a).

**Decisions locked:**
- Split the 10 rules by sub-shape:
  - **Unconditional** (CG0368 DM required, CG0501 / CG0502 TM
    required, CG0646 SJ must not be present) -- two patterns:
    `submission-dataset-required` (`op_not_exists` +
    `scope.submission: true`) and `submission-dataset-absent`
    (`op_exists` + `scope.submission: true`). Reuses the
    ADaM-1 routing already landed.
  - **Meta-existence** (CG0373 `SUPP--`.RDOMAIN, CG0374
    RELREC.RDOMAIN) -- new op `op_ref_column_domains_exist(
    reference_dataset, reference_column)` that iterates distinct
    values of `<ref>.<col>` and fires if any named domain is
    absent from the submission. Pattern
    `submission-domains-from-ref-column`.
  - **Conditional required** (CG0191 MB "if microbiology
    collected", CG0318 PC "if PK collected") -- remain narrative;
    tag `blocker: requires-study-metadata` in progress.csv.
    Revisit once a study-metadata schema lands.
- Converts 5 or 6 of 10 this pass; remaining 4-5 tagged.

**Delivered:** _(pending -- deferred to user implementation)_

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

**User answer:** (a).

**Decisions locked:**
- Split the 39 rules across three tracks:
  - **`uniqueness-grouped-nested` pattern** (~15 rules) -- extends
    Q3's `paired-var-consistency-param` with a configurable
    `outer_keys` slot. Default `[PARAMCD]`; supports
    `[PARAMCD, BASETYPE]` and `[PARAMCD, USUBJID]` as alternate
    composite keys. Uses existing
    `op_is_not_unique_relationship` with list-valued `group_by`.
    Covers: ADaM-221..226 + siblings for AVALCATy/AVAL,
    BASECATy/BASE, CHGCATy/CHG, PCHGCATy/PCHG within PARAMCD.
  - **`value-constant-per-group` pattern** (~13 rules) -- new
    small op `op_is_not_constant_per_group(name, group_by)` that
    fires rows whose outer group has >1 distinct value of
    `name`. Covers the single-var cardinality cases
    (ADaM-151 CRITy per PARAMCD, and siblings).
  - **Baseline-consistency rules** (~8 rules, e.g. ADaM-127, 128,
    131) deferred to Q12 -- they need the ABLFL selector-row
    semantic, which is a distinct engine concept.
- Findings carry the concrete outer_keys values in the message
  (e.g. "within PARAMCD=HR, AVALCAT1 has multiple values for
  AVAL=70") for reviewer clarity.

**Delivered:** _(pending -- deferred to user implementation)_

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

**User answer:** (a).

**Decisions locked:**
- Three patterns + one new op + reuse of the Q2 CT op:
  - **`suffix-var-value-in-set`** -- expands `<stem><suffix>` via
    the existing `stem` placeholder; per-row
    `is_contained_by(col, <allowed>)`. Covers ADaM-5 (`*FL` in
    {Y,N,null}), ADaM-33 (`*RFL` in {Y,null}), ADaM-34 (`*PFL`
    in {Y,null}), ADaM-35 (`*RFN` in {1,null}), ADaM-36 (`*PFN`
    in {1,null}). 5 rules.
  - **`suffix-var-value-in-codelist`** -- same expansion feeding
    the Q2 `op_value_in_codelist` for ADaM-39 (`*DTF` vs DATEFL
    codelist) and ADaM-40 (`*TMF` vs TIMEFL codelist). 2 rules.
    **Confirmed unblocked:** DATEFL (Date Imputation Flag) and
    TIMEFL (Time Imputation Flag) both ship in the bundled ADaM
    CT (adam-ct.rds). Convert in the same pass as the other
    Q11 suffix patterns.
  - **`suffix-var-is-numeric`** -- new op
    `op_var_by_suffix_not_numeric(suffix, exclude_prefix)` reading
    `!is.numeric(col)`. Handles ADaM-716's "excluding SDTM
    variables with a suffix of ELTM" via `exclude_prefix`.
    Covers ADaM-58 (`*DT`), 59 (`*TM`), 60 (`*DTM`), 716 (`*TM`
    excluding ELTM). 4 rules.
  - **`suffix-pair-value-in-set`** -- new helper + pattern for
    ADaM-6's "both suffixes on same stem" shape (FL present ->
    FN in {0,1,null}). 1 rule.
- **Individual FN rules** (ADaM-26..32) -- NOT part of this
  cluster's conversion. They name concrete variables (COMPLFN,
  FASFN, ...) and map to the existing `value-flag-yn` pattern
  from Q2 with allowed set `[1, 0]` rather than the stem wildcard.
  7 rules via the existing pattern.
- Total coverage for Q11: 21 rules in this pass (14 via new
  suffix patterns, incl. ADaM-39 / ADaM-40 now that DATEFL and
  TIMEFL are confirmed in the bundled CT, + 7 via existing
  `value-flag-yn`).

**Delivered:** _(pending -- deferred to user implementation)_

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

**User answer:** (a).

**Decisions locked:**
- New op `op_base_not_equal_abl_row(b_var, a_var, group_keys,
  abl_col = 'ABLFL', abl_value = 'Y', basetype_gate)`:
  - For each row's group (defined by `group_keys`), find the
    anchor row where `<abl_col> == <abl_value>`.
  - Fire when the row's `b_var` is populated AND
    `b_var != anchor[a_var]` using the P21-aligned
    `.cdisc_value_equal` (numeric + datetime fuzzy, POSIXct
    canonicalisation, NULL==NULL).
  - `basetype_gate` encodes the BASETYPE presence condition:
    `"absent"` -> rule runs only when BASETYPE is not a column in
    the dataset (metadata gate);
    `"populated"` -> rule runs row-by-row only when BASETYPE is
    populated on that row;
    `"any"` -> no gate.
- Pattern `baseline-equals-abl-row` with slots `(b_var, a_var,
  group_keys, basetype_gate)`.
- 11 .ids rows split by gate:
  - `basetype_gate=absent` (7 rules): ADaM-181, 182, 183, 354,
    698, 699, 703.
  - `basetype_gate=populated` (4 rules): ADaM-744, 745, 789, 790
    (with `BASETYPE` added to `group_keys`).
- Index-expanded variants (ADaM-354, 703, 790 with `ByIND`/`AyIND`
  + `y` placeholder) use the existing `expand: y` machinery.
- Findings include the anchor row's (PARAMCD, USUBJID[, BASETYPE])
  in the message for reviewer clarity.

**Delivered:** _(pending -- deferred to user implementation)_

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

**User answer:** (a).

**Decisions locked:**
- Not bundled. Do NOT ship UNII inside the package (would blow
  the 5 MB CRAN cap; UNII is ~15-20 MB RDS).
- 6 rules (CG0442, CG0443, CG0445, CG0446, CG0450, CG0451) stay
  narrative with a `blocker: ext-registry-srs` tag in
  progress.csv.
- Follow-on work (separate pass, not in the Q4-Q14 cycle):
  - New file `R/srs-fetch.R` reusing Q2's downloader
    architecture: `download_srs(version, dest = user_cache)`
    fetches from the FDA public bulk download, parses into a
    tidy (unii, preferred_name, synonyms) table, writes RDS to
    `tools::R_user_dir("herald","cache")`.
  - New op `op_value_in_srs_table(name, field = "preferred_name"
    | "unii")` lazy-loads from cache via `ctx$srs`, returns NA
    when the cache is empty (so the rule advises rather than
    fires in offline / un-downloaded environments).
  - After op + downloader land, convert the 6 rules via a new
    pattern `value-in-srs-registry` with slots `(var, field)`.
- Source of truth (record now to save lookup later):
  - https://fis.fda.gov/extensions/FDA_SRS_UNII/FDA_SRS_UNII.html
  - https://precision.fda.gov/uniisearch/ (search UI)

**Delivered:** _(pending -- deferred to user implementation)_

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

**User answer:** (a).

**Decisions locked:**
- Triage, don't pre-author. Three tracks:

  1. **Absorb 13+ rules into already-decided patterns** (no new
     work beyond adding .ids rows when the prior-Q conversions
     run):
     - 6 rules (ADaM-176, 269-271, 363, 619 "VAR is not equal to
       Y or null") -> Q4 `value-conditional-in-literal-set` with
       allowed `[Y, null]`.
     - 4 rules (ADaM-891-894 "on a given record, more than one
       value of VAR for VAR") -> Q3 `uniqueness-grouped` with
       `[USUBJID]` as the group key.
     - 3 rules (CG0284, CG0440, CG0457 "TSVAL is integer and
       > 0") -> Q4 `value-conditional-equal-literal` with
       assertion leaf using the existing `is_greater_than` /
       `is_integer` comparison ops.

  2. **Two new tiny ops + one new pattern** (covers 5 rules):
     - 3 rules (CG0398, CG0536, CG0537 "at most one record per
       subject per epoch") -> existing `is_not_unique_set` with
       composite key `[USUBJID, EPOCH]` (or adding DSSCAT for
       CG0536). No new op; just `.ids` rows.
     - 2 rules (CG0538, CG0539 "no more than 1 record per subject
       has DSSCAT = LIT") -> new op
       `op_max_n_records_per_group_matching(name, value,
       group_keys, max_n)` + pattern
       `max-n-records-per-group`.
     - 2 rules (ADaM-664, 669 "VAR is populated and VAR is present
       and not populated") -> existing combinator
       `all: [non_empty(v1), exists(v2), empty(v2)]`. Just
       pattern + `.ids`; no new op.

  3. **Residual ~30 singletons** (1-2 rules each, bespoke prose):
     - **Revised: triage NOW, not later.** Run
       `tools/rule-authoring/triage-residual.R` during the
       Q4-Q14 authoring cycle (not after) -- the same context
       that's converting Q4-Q14 will spot singletons that share
       shape with patterns already being authored. Every
       singleton lands in one of three buckets:
         (1) absorbs into a Q4-Q14 pattern's .ids -- no new work.
         (2) cheap enough to author its own pattern now
             (1-2 rules, existing ops) -- convert inline.
         (3) genuinely needs new engine work -- tag
             `blocker: needs-op-<short_name>` and move on.
     - Expect most singletons to fall in buckets (1) or (2);
       only (3) stays narrative.

- Net target after Q4-Q14 executions: predicate coverage ~80%
  (~1450/1814). Remaining ~20% is the true long tail + the
  FDA-SRS six (Q13) + conditional dataset-required rules (Q9).

**Delivered:** _(pending -- deferred to user implementation)_

---

## Backlog (after Q14)

Once Q4-Q14 are answered and converted, remaining narrative
rules (~50-80) will be true one-offs requiring bespoke translation
or CDISC-guidance clarification. Target: predicate coverage
80%+ (~1450/1814) after this interview cycle. Anything beyond
needs either external CT / registry bundles or new engine
primitives scoped individually.

---

# Cross-cutting bundle (Q15-Q20)

Implementation-layer decisions that surface while executing the
Q4-Q14 backlog. Each is a decoupled design choice that should be
settled before authoring kicks off.

---

## Q15 -- condition-primitive grammar

**Context:** Q1 / Q4 / Q9 all lean on a "reusable condition
library" for per-rule English `when:` clauses (e.g. `ACTARM in
('Screen Failure', ...)`, `ARMNRS ^= null`, `IDVAR populated with
a --SEQ value`, `Milestone = end of treatment`). The library
doesn't exist yet. We need to fix its surface area so patterns
across Q1/Q4/Q9 consume a stable vocabulary.

**Proposed grammar (leaves for `when:` combinator slots):**

- `equal_to(name, value)` / `not_equal_to(name, value)` -- exist.
- `is_contained_by(name, value_list)` /
  `is_not_contained_by(name, value_list)` -- exist.
- `non_empty(name)` / `empty(name)` -- exist.
- `matches_regex(name, pattern)` -- exist.
- `ends_with(name, suffix)` -- new tiny op (sugar for regex).
- `less_than(name, value)` / `greater_than(name, value)` -- exist
  via `op_less_than_by_key` / `op_greater_than_by_key`; add
  literal-value variants that accept a scalar `value` instead of
  a cross-dataset column.
- `is_populated_with_suffix_value(name, suffix)` -- new op for
  the "IDVAR populated with a --SEQ value" (CG0419) shape.
- `milestone_is(name)` -- drop. "Milestone associated with X is
  end of treatment" is a tautology in CDISC authoring; the rule
  scope already anchors to the variable whose milestone that is.
  The clause stays documentary only.

**Options:**
- (a) Ship the grammar above as-is: 6 reusable leaves (all but
  one already exist), 1 new small op
  (`is_populated_with_suffix_value`), milestone-tautology
  dropped. Patterns Q1/Q4/Q9 pick leaves off the list by name;
  no new combinator needed -- existing `all:` / `any:` / `not:`
  suffice.  *[recommended]*
- (b) Build a dedicated `when:` combinator with a domain-
  specific micro-language (`when: "ARMNRS != null and ACTARM in
  [...]"`) parsed at compile time. Cleaner YAML, but adds a
  parser, a spec, and a test surface we can skip.
- (c) Defer the grammar; hand-translate each `when:` per rule
  using existing `all: [leaf1, leaf2]` in raw YAML. No library.

**User answer:** (a).

**Decisions locked:**
- Grammar freezes on the 9-leaf vocabulary above. Existing
  combinators (`all:` / `any:` / `not:`) already handle
  composition; no new `when:` macro.
- New ops to author (small):
  - `op_ends_with(name, suffix)` -- sugar over
    `matches_regex(name, paste0(suffix, "$"))` for readability.
  - `op_less_than_literal(name, value)` /
    `op_greater_than_literal(name, value)` -- literal-value
    variants of the existing `_by_key` comparators.
- Prose tautologies dropped on conversion (milestone
  associations, scope-implied clauses).
- Prose semantic classifiers ("LBORRES is continuous
  measurement") fall back to the `r_expression` escape hatch on
  a per-rule basis; they don't grow the standard vocabulary.
- Document the grammar in `tools/rule-authoring/CONVENTIONS.md`
  as the authoritative leaf list so future patterns can't
  invent ad-hoc leaf names.

**Delivered:** _(pending -- deferred to user implementation)_

---

## Q16 -- pattern fixture + test strategy

**Context:** Every new pattern added by Q4-Q14 needs a fixture
that proves positive-fires and negative-passes. `smoke-check.R`
already runs but the fixture format is inconsistent -- some
patterns ship `fixtures/<pattern>/{pos,neg}.json`, others
inline synthetic data in the smoke script, others have no
fixtures at all. Unblocks a consistent test surface.

**Options:**
- (a) Standard two-file fixture per pattern at
  `tools/rule-authoring/fixtures/<pattern>/{pos.json, neg.json}`
  using the Dataset-JSON v1.1 format (already supported by
  `read_json()`). Smoke-check runs `validate()` against each;
  positive must fire all target rule_ids, negative must produce
  zero fired findings for them. Every Q4-Q14 pattern ships with
  both files. `smoke-check.R` hard-fails missing fixtures.  *[recommended]*
- (b) Fixtures only for patterns with >3 rules; smaller patterns
  rely on unit tests of their op. Less overhead, weaker
  whole-pipeline confidence.
- (c) Inline synthetic fixtures in `smoke-check.R` (status quo).
  Fast to author, hard to reproduce.

**User answer:** (a).

**Decisions locked:**
- Every pattern ships two Dataset-JSON v1.1 fixtures at
  `tools/rule-authoring/fixtures/<pattern>/{pos.json, neg.json}`.
- Reuse of `read_json()` -- no new ingester; fixtures are
  valid CDISC Dataset-JSON and can be viewed in any compliant
  tool.
- `smoke-check.R` contract per pattern:
  1. Load pos fixture -> `validate(files = ..., rules = <.ids>)`.
     Assert each rule_id in the pattern's `.ids` fires at least
     once.
  2. Load neg fixture -> same call. Assert zero fired findings
     for those rule_ids.
  3. Missing fixtures are a hard-fail, not a warn.
  4. Print a per-pattern pass/fail matrix at the end.
- New patterns from Q4-Q14 must include both fixtures in the
  same PR. Reviewers gate on `smoke-check.R` green.
- Existing patterns that lack fixtures get backfilled
  opportunistically -- not a blocker for new conversions.
- Fixtures serve double duty as documentation: the pos fixture
  shows "data that triggers the rule"; neg shows "data that
  passes". Reviewers open them directly.

**Delivered:** _(pending -- deferred to user implementation)_

---

## Q17 -- `variable:` prose field normalisation

**Context:** Most narrative rule YAMLs carry a `variable:` field
that's free-form prose, e.g.
`variable: "AVALCATy where y is an integer [1-9, not zero-padded]"`.
After conversion, the `check:` block names the concrete / expanded
variable; the prose `variable:` field becomes redundant or
misleading (engine ignores it entirely today).

**Options:**
- (a) On conversion, rewrite `variable:` to the bare template
  symbol (e.g. `AVALCATy`) -- the clean name that appears in the
  check_tree. Drop the prose. Report rendering uses the
  check_tree's leaf `name` at runtime for finding attribution, so
  `variable:` becomes a human-readable index-card field only.  *[recommended]*
- (b) Delete `variable:` entirely from every converted YAML.
  Minus-1 column but future tooling (discover-patterns,
  pattern-audit) relies on it for skeleton keying.
- (c) Keep the prose untouched. Rule maintainers carry the
  ambiguity forward.

**User answer:** (a).

**Decisions locked:**
- On conversion (`apply-pattern.R`), rewrite `variable:` to the
  bare template symbol extracted from the check_tree's primary
  leaf name. Examples:
  - `"AVALCATy where y is an integer [1-9, not zero-padded]"`
    -> `AVALCATy`
  - `"A variable with a suffix of FL"` -> `VAR` (placeholder
    token meaning "template / wildcard", when no single leaf
    name exists).
  - Concrete names (`PARAM`, `ARMCD`) pass through unchanged.
- Extraction rule: take the first leaf with a `name:` slot,
  uppercase-only the template symbol (strip surrounding prose,
  drop "where ..." clauses).
- `apply-pattern.R` grows a small `.normalise_variable()`
  helper. Runs idempotently -- re-running on a YAML already at
  `predicate` is a no-op.
- `discover-patterns.R` and report-rendering read the
  normalised field; no code change needed downstream.
- Backfill sweep for pre-converted YAMLs happens once, as a
  one-off `data-raw/normalise-variables.R` script. Not part of
  routine authoring.

**Delivered:** _(pending -- deferred to user implementation)_

---

## Q18 -- severity override mechanism

**Context:** CDISC tags each rule with a severity (Medium /
High / ...). P21 sometimes publishes a stricter severity for the
same rule. Sponsors frequently want a project-local elevation
("treat all Medium as Reject for our Q3 submission"). Today
severity is hardcoded in the rule YAML's `outcome.severity`.

**Options:**
- (a) Runtime override via a `severity_map` argument on
  `validate(severity_map = c("Medium" = "High", "CG0085" =
  "Reject"))`. Map is `<rule_id or severity_category> ->
  <new_severity>`. Applied in `emit_findings` before writing the
  row. Rule YAML stays authoritative default; no edits needed
  to escalate.  *[recommended]*
- (b) Sponsor-side config file `herald.yaml` with a
  `severity_overrides:` block auto-loaded from the submission
  root. More ergonomic for repeated runs, but adds a file-
  discovery surface to explain.
- (c) Hard-code severity; force users to fork the rule YAMLs for
  their project. Not recommended.

**User answer:** (a).

**Decisions locked:**
- Add `severity_map` argument to `validate()`. Default `NULL`
  (no override). When supplied, a named character vector where:
  - Names are matched as literal rule_id first (exact match).
  - If no rule_id match, matched as a regex against rule_id
    (`"AD01.*"`).
  - If still no match, matched as a severity category (`Medium`,
    `High`, ...).
  - First successful match wins; no cascading.
  - Values are the new severity string (free-form -- common
    values: `Low`, `Medium`, `High`, `Reject`, but not a closed
    set).
- Applied in `emit_findings()` (and `emit_submission_finding()`)
  BEFORE the row is built. Never mutates the rule catalog in
  memory; map application is per-run.
- Findings report notes when an override was applied -- add a
  small `severity_override` column to the findings tibble
  carrying the original severity so reviewers see both.
- Documented in the `validate()` manpage with a worked example
  covering all three match modes.

**Delivered:** _(pending -- deferred to user implementation)_

---

## Q19 -- report rendering wiring

**Context:** `inst/report/template.html` is shipped (archival
format, P21-style, 900px print width, tab switcher) but there's
no renderer that takes a `herald_result` and fills the six
`{{...}}` placeholders. Reviewers today can only see the
findings tibble.

**Options:**
- (a) Ship a single thin renderer `render_html_report(result,
  file)` in `R/report-html.R` that:
  1. Reads `inst/report/template.html`.
  2. Renders the four tab tables from `result$findings` /
     `result$rule_catalog` / `result$dataset_meta`.
  3. Writes the output file. No new deps (pure `sprintf` /
     `gsub` substitution -- no `glue`, no `rmarkdown`).
  Do this now so every Q4-Q14 conversion landing gets a usable
  reviewer output.  *[recommended]*
- (b) Defer rendering; focus the cycle on rule conversions,
  let the report land in a follow-on. Shippable tool but ugly
  reviewer UX in the interim.
- (c) Rewrite the template with rmarkdown. Heavier dep surface,
  worse archive reproducibility. Not recommended.

**User answer:** (a) with expanded HEADER_META scope.

**Decisions locked:**

- Ship `render_html_report(result, file)` in `R/report-html.R`
  using plain `sub()` / `gsub()` substitution. No new deps.

- **HEADER_META covers full provenance** (not just the initial
  5 cells). Four logical groups, 10-12 cells total:

  1. **Identity** (3 cells)
     - Herald version (package semver + commit if available)
     - Generated (ISO 8601 timestamp, UTC)
     - Datasets checked (integer count)

  2. **Findings summary** (2 cells)
     - Fired (integer)
     - Advisory (integer)

  3. **Controlled Terminology provenance** (2 cells)
     - SDTM CT version (e.g. `2026-03-27`) -- pulled from
       `attr(load_ct("sdtm"), "version")` at validate() time.
     - ADaM CT version -- same for `"adam"`.
     - Source attribution: `NCI EVS` if bundled, `cache` if
       user-downloaded override active.

  4. **Conformance standards** (3-5 cells, one per standard that
     contributed firing rules)
     - SDTM-IG versions used (e.g. `3.2, 3.3, 3.4` joined, drawn
       from `standard_versions` across the filtered rule
       catalog).
     - ADaM-IG versions used.
     - SEND-IG versions if any SEND rules fired.
     - FDA / PMDA profile flags if a severity_map from those
       profiles is active.

- **Engine wiring:** extend `validate()` so the returned
  `herald_result` carries a `result$environment` slot:
  ```
  result$environment <- list(
    herald_version    = as.character(utils::packageVersion("herald")),
    generated_at      = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz="UTC"),
    ct_sdtm_version   = attr(ctx$ct$sdtm, "version") %||% NA,
    ct_adam_version   = attr(ctx$ct$adam, "version") %||% NA,
    ct_sdtm_source    = attr(ctx$ct$sdtm, "source_url") %||% "bundled",
    ct_adam_source    = attr(ctx$ct$adam, "source_url") %||% "bundled",
    standards         = .collect_standards(catalog_used),
    severity_profile  = .describe_severity_map(severity_map)
  )
  ```
  `.collect_standards()` returns a tibble
  `(standard, versions, rules_fired, rules_total)` drawn from
  the rules actually applied in the run.

- `render_html_report()` reads from `result$environment`; does
  not call `load_ct()` or touch the CT cache directly.

- Template CSS: the existing `.meta-grid` already uses
  `grid-template-columns: repeat(5, 1fr)` and wraps naturally
  for >5 cells, giving a 5x2 layout. No template edit needed
  beyond the placeholder expansion; if the standards group has
  a variable-size tail, emit each as its own `.meta-cell`.

- Default title for the report when not supplied: format of
  `"Conformance Report -- <N> datasets -- <timestamp>"`.

**Delivered:** _(pending -- deferred to user implementation)_

---

## Q20 -- residual-singletons triage criteria

**Context:** Q14 option (a) said "stand up a triage script for
the ~30 residual singletons; convert only when they surface in
real submissions." We need a concrete criterion for what "drop
from the target corpus" looks like vs "keep narrative indefinitely".

**Options:**
- (a) Three-state tagging in `progress.csv`:
  - `narrative` -- default, unconverted.
  - `blocker: <reason>` -- deliberately parked pending external
    work (study metadata, UNII, CT availability).
  - `drop: <reason>` -- the rule's prose is ambiguous,
    obsolete, or outside CDISC's intent; will never be
    converted. Requires the reason cited.
  - `deprecated: <reason>` -- the rule was superseded by a
    newer CDISC rule.
  Triage script fills the column after human review; findings
  report never shows `drop` / `deprecated` entries.  *[recommended]*
- (b) Binary narrative / predicate only; singletons stay
  narrative indefinitely. Simpler schema but loses the
  distinction between "can't convert yet" and "will never
  convert".
- (c) Auto-drop anything narrative after 12 months without
  conversion. Too aggressive; risks discarding genuine rules.

**User answer:** (a) with a **>95% predicate target**.

**Decisions locked:**

- Keep the four-state taxonomy (`narrative` / `predicate` /
  `blocker:<reason>` / `drop:<reason>` / `deprecated:<reason>`)
  but raise the predicate coverage bar to **>95%**
  (1724+ / 1814). Blocker allowance capped at <5%.

- **No "park indefinitely".** Every prior deferral in the
  Q4-Q14 cycle is re-opened with a concrete delivery path:

  | prior block | rules | stretch plan |
  |---|---|---|
  | Q9 conditional dataset-required (requires-study-metadata) | ~5 | Add a `study_metadata` arg to `validate()` that accepts a small YAML or list (study type, data domains collected, PK program flag). Rule condition leaves consume it via a new `op_study_metadata_is(key, value)`. Converts CG0191 (MB), CG0318 (PC), and siblings. |
  | Q13 FDA SRS / UNII (ext-registry-srs) | 6 | Ship `download_srs()` + `op_value_in_srs_table()` in the same cycle, not a follow-on. Cache-only (no bundle); rule runs advisory when cache empty with a hint. |
  | Q11 DATEFL / TIMEFL CT | 2 | Already unblocked (codelists present in adam-ct.rds); convert now. |
  | Q2 LBORRES "continuous measurement" | 5 | New op `op_test_category_is_continuous(name, ref_dataset)` reading LB domain CT categorisation (LBTESTCD -> classification). If NCI EVS doesn't ship the classification, curate a small deterministic mapping (~50 LB test codes) inline and ship in `inst/extdata/lb-category.rds`. |
  | Q14 residual singletons | ~30 | Triaged inline during Q4-Q14. Target: convert >25 of 30 via existing or 3-5 new small ops. Only genuinely unparseable prose (< 5 rules) allowed to stay `blocker:prose-ambiguous`. |

- **`drop:` and `deprecated:` are reserved for CDISC-side
  decisions only:**
  - `deprecated:` -- CDISC replaced this rule with a newer one
    in a later IG version. Engine skips it when that version is
    selected.
  - `drop:` -- CDISC explicitly retired the rule; no replacement.
    Requires citation to the retirement note in the YAML.

- **Hard coverage commitment:**
  - narrative   : 0 rules after the full Q4-Q14 + stretch cycle.
  - predicate   : >= 1724 (>=95%).
  - blocker:*   : <= 90 (< 5%), each with a scheduled
    delivery milestone, not indefinite.
  - drop/deprecated : only where CDISC guidance supports it.

- **Delivery cadence:** Q4-Q14 patterns land first (target 1450
  predicate). Stretch work (SRS downloader, study_metadata arg,
  LB category map, singleton sweep) lands in the next cycle to
  close the last 15%.

**Delivered:** _(pending -- deferred to user implementation)_

---

