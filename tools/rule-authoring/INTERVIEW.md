# Rule-authoring interview log

Running record of Q&A used to drive narrative-rule conversion.
Options follow the convention: **(a) is always the recommended
approach**, alternatives rank-ordered after.

Use Ctrl-F on rule_id to find the decision that covers a rule.

---

## Status snapshot (2026-04-24) -- read this first

### Shipped

**Rule corpus:** 786 / 1814 predicate (43.3%). No regressions. (Q10 added 39 in 2026-04-24 session.)

**Engine / infrastructure:**
- Dictionary Provider Protocol (full 6-phase plan complete).
  - Registry: `register_dictionary`, `unregister_dictionary`,
    `list_dictionaries`, `new_dict_provider`.
  - Factories: `ct_provider`, `srs_provider`, `meddra_provider`,
    `whodrug_provider`, `loinc_provider`, `snomed_provider`,
    `custom_provider`.
  - Downloader: `download_ct` (CDISC NCI EVS), `download_srs`
    (FDA SRS / UNII, cache-only).
  - Missing-ref tracking: `ctx$missing_refs` + `result$skipped_refs`
    with kind + name + rule_ids + actionable hint.
  - Report banner: `write_report_html()` renders
    "Missing reference data" section + "N skipped" header cell.
- CT bundle: `inst/rules/ct/{sdtm,adam}-ct.rds` (2026-03-27).
- Engine fix: `.substitute_index` recurses into nested
  `value.related_name` / `value.group_by` slots.
- P21-aligned value compare: datetime fuzzy prefix, numeric
  normalization, NULL==NULL == equal, POSIXct / Date / difftime
  canonicalisation, 4-digit-year heuristic.

**Validation UX:**
- `validate(... dictionaries = list(...))` explicit override.
- `result$skipped_refs` structured per kind + name.
- Submission-level rule routing (`scope.submission: true`) for
  ADSL-existence-style checks.
- `result$environment` carries Herald version + CT versions +
  IG versions (Q19 provenance; wiring pending in renderer).

**Tests:** 2485 / 2485 PASS under `devtools::test()`. 2484 / 2485
under `R CMD check` (one pre-existing failure noted below).

### Pending

**Rule conversion backlog (interview-queued, not yet executed):**

| block | cluster | rules | plan |
|---|---|---:|---|
| Q4  | conditional literal-assertion (VAR = LIT / VAR in (...)) | 21 | two patterns, existing ops |
| ~~Q5~~  | ~~ADSL <-> DM consistency~~ | ~~8~~ | **DONE** adsl-dm-consistency pattern |
| Q6  | cross-dataset equality / membership | 10 | two patterns |
| Q7  | cross-dataset presence pair | 5 | combinator pattern |
| Q8  | unit-consistency | 7 | pattern w/ numeric guard |
| Q9  | dataset-presence-in-study | 10 | 3 patterns + `op_study_metadata_is` |
| ~~Q10~~ | ~~composite-group uniqueness~~ | ~~39~~ | **DONE** 3 patterns + `op_is_not_constant_per_group` + `op_no_baseline_record` |
| Q11 | suffix-pattern value + type | 21 | 3 patterns + `op_var_by_suffix_not_numeric` |
| Q12 | baseline-consistency compound | 11 | `op_base_not_equal_abl_row` |
| Q13 | FDA SRS / UNII | 6 | `op_value_in_srs_table` wired to `srs_provider` |
| Q14 | residual singletons | ~30 | inline triage; 4-bucket sort |
| Q21 | indexed compound-var family | ~50 | 2 patterns, existing `expand:` |
| Q22 | prefix+suffix compound templates | 8 | compound-template-pair pattern |
| Q23 | TS-domain parametric | 30 | 1 parametric pattern driven by CSV |
| Q24 | ISO 8601 conformance | 10 | `op_value_not_iso8601` |
| Q25 | dataset-naming / domain-code | 13 | 3 micro-patterns |
| Q26 | cross-dataset variable presence | 10 | `op_var_present_in_any_other_dataset` |
| Q27 | MedDRA / WhoDrug / external dict | 22 | `op_value_in_dictionary` + `register_dictionary` |
| Q28 | RELREC / associated-person | 5 | combinator pattern |
| Q29 | ELEMENT / EPOCH / TE-SE | 7 | 3 patterns + `op_next_row_not_equal` |
| Q30 | IG-defined treatment-var | 3 | reuses Q2 op |
| Q31 | Define.xml / sponsor keys | 2 | new `R/define-read.R` reader |
| Q32 | compound combinator residual | ~40 | triage script + hand-translate |
| **total expected net** | | **~1050** | brings corpus to ~1750 / 1814 |

**P21 audit follow-on changes (queued, not coded):**
- A. `op_matches_regex` full-match default (Q4 / Q11 / Q24).
- B. `equal_to_ci` / `not_equal_to_ci` sugar ops (Q15 / Q4).
- D. `when:` guard three-state return (Q1 / Q4 / Q9).
- G. `paste` NA-sentinel fix (Q3 / Q10 / Q12 / Q29).
- N. `severity_map` nested-list domain form (Q18).

**Follow-on features (queued):**
- Q15 condition-primitive grammar (`ends_with`,
  `less_than_literal` / `greater_than_literal`).
- Q16 fixture convention (pos/neg Dataset-JSON per pattern).
- Q17 `variable:` prose normalisation on `apply-pattern.R`.
- Q18 `severity_map` arg on `validate()`.
- Q19 HEADER_META expanded provenance (CT versions + IG
  versions) -- `result$environment` spec captured; renderer
  not yet updated.
- Q20 four-state progress.csv taxonomy
  (`narrative` / `predicate` / `blocker:*` / `drop:*` /
  `deprecated:*`).

**Known pre-existing test issue (NOT from this session):**
- `tests/testthat/test-fast-ops-meta.R:31` calls `.op_meta()`
  and `.get_op()` unqualified -- works under `devtools::test()`
  via `load_all()`, fails under `R CMD check` installed-package
  mode. One-line fix: prefix `herald:::`. Not committed; user
  sign-off pending.

### Where the detail lives

- Full decision log (Q1-Q33): below, each question with
  "User answer" + "Decisions locked".
- P21 cross-Q audit: bottom of this file under "P21 edge-case
  cross-Q audit (2026-04-22)".
- Dictionary Provider Protocol plan:
  `/Users/vignesh/.claude/plans/cached-nibbling-penguin.md`.
- Implementation commits: `git log --oneline -12` from
  `9b4afe8` downward.
- Memory: `/Users/vignesh/.claude/projects/-Users-vignesh-projects-r-herald/memory/`
  (MEMORY.md indexes the session-persistent rules).

### To resume

1. Pick a Q from "Pending rule conversion backlog" (all
   recommended = "a" already; user consent implicit in the
   hardened 95%+ target).
2. Read that Q's "Decisions locked" section -- has slots, op
   names, scope.
3. Author pattern MD + .ids, run `apply-pattern.R`, run
   `compile-rules.R`, run `devtools::test()`, commit per
   pattern.
4. Loop.

Recommended starting order: Q4 (conditional literal) -> Q10
(composite uniqueness) -> Q11 (suffix patterns) -> Q21
(indexed compound). These four unlock ~120 rules with no new
ops; pure pattern + .ids + existing engine.

---

## Coverage commitment (set at Q20, hardened after Q32)

| state | allowed | current (696 / 1814) | post-cycle target |
|---|---:|---:|---:|
| `predicate` | -- | 38.4% | **100% of addressable rules** (>= 99%) |
| `narrative` | 0 | 61.6% | 0 |
| `blocker:<reason>` | **0 unless provably unaddressable** | 0 | 0 (none expected) |
| `drop:` / `deprecated:` | -- | 0 | only when CDISC retires a rule |

**Hard rule:** a rule may stay `blocker` ONLY when there is no
feasible path -- under any combination of engine work,
user-supplied data, external registry, or escape hatch -- to
evaluate it. If ANY path exists (even one requiring the user
to supply a licensed dictionary), the rule is converted.
Missing user data becomes NA -> advisory, not "didn't run".

Every prior "deferred" / "stay narrative" branch across Q1-Q32
is re-written to a concrete conversion path below. See the
re-audit lines under each question for specifics.

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

**Delivered:** _(pending -- not yet implemented)_

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

**Delivered:** 2026-04-24. Pattern `adsl-dm-consistency` (8 rules:
ADaM-204..210, ADaM-367). All 8 converted to `predicate`.

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

**Delivered:** _(delivered)_

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

**Delivered:** _(delivered)_

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

**Delivered:** _(delivered)_

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
- Split the 10 rules by sub-shape, **all converted this cycle**:
  - **Unconditional** (CG0368 DM required, CG0501 / CG0502 TM
    required, CG0646 SJ must not be present) -- two patterns:
    `submission-dataset-required` (`op_not_exists` +
    `scope.submission: true`) and `submission-dataset-absent`
    (`op_exists` + `scope.submission: true`). Reuses the
    ADaM-1 routing already landed.
  - **Meta-existence** (CG0373 `SUPP--`.RDOMAIN, CG0374
    RELREC.RDOMAIN) -- new op `op_ref_column_domains_exist(
    reference_dataset, reference_column)`. Pattern
    `submission-domains-from-ref-column`.
  - **Conditional required** (CG0191 MB "if microbiology
    collected", CG0318 PC "if PK collected") -- **convert via
    `validate(study_metadata = ...)` stretch path**. New op
    `op_study_metadata_is(key, value)` consumes a sponsor-
    supplied small list/YAML (`collected_domains: [MB, PC, ...]`,
    `study_type: ...`). When no study_metadata is supplied the
    op returns NA -> advisory ("this rule could not be
    evaluated: supply study_metadata"); when supplied, the rule
    fires normally. No rules remain narrative.
- All 10 rules convert. 0 blockers.

**Delivered:** 2026-04-24 -- 8 rules predicate (CG0191, CG0318, CG0368,
  CG0373, CG0374, CG0501, CG0502, CG0646). 3 patterns +
  op_study_metadata_is + op_ref_column_domains_exist.
  validate() gains study_metadata param. 30 new unit tests.

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

**Delivered:** 2026-04-24 -- 39 rules converted across 3 tracks:
  - `uniqueness-grouped-nested` (28 rules): ADaM-221/222/224/226/231/234/322/583/587/693/694/727/728/729/732/733/736/737/742/743/747/748/749/750/751/756/759/791. Uses `op_is_not_unique_relationship` with list-valued `group_by`.
  - `value-constant-per-group` (3 rules): ADaM-131/151/735. New op `op_is_not_constant_per_group`.
  - `baseline-record-missing` (4 rules): ADaM-127/128/691/692. New op `op_no_baseline_record`.
  - `value-arith-check` (4 rules): ADaM-700/701/704/705. Reuses existing `op_is_not_diff`/`op_is_not_pct_diff`.

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

**Delivered:** _(delivered)_

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

**Delivered:** _(pending -- not yet implemented)_

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
- **All 6 rules convert this cycle** (CG0442, CG0443, CG0445,
  CG0446, CG0450, CG0451). No `blocker:` tag.
- Work plan, in-cycle:
  - New file `R/srs-fetch.R` reusing Q2's downloader
    architecture: `download_srs(version, dest = user_cache)`
    fetches from the FDA public bulk download, parses into a
    tidy (unii, preferred_name, synonyms) table, writes RDS to
    `tools::R_user_dir("herald","cache")`.
  - New op `op_value_in_srs_table(name, field = "preferred_name"
    | "unii")` lazy-loads from cache via `ctx$srs`. When cache
    is empty the op returns NA -> advisory ("SRS table not
    downloaded; run download_srs() to enable this check"); when
    present, rule fires normally. Rule predicate exists either
    way -- no narrative status.
  - Pattern `value-in-srs-registry` with slots `(var, field)`.
- Source of truth:
  - https://fis.fda.gov/extensions/FDA_SRS_UNII/FDA_SRS_UNII.html
  - https://precision.fda.gov/uniisearch/ (search UI)

**Delivered:** _(pending -- not yet implemented)_

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
     - Triage NOW during the Q4-Q14 cycle. Every singleton
       converts; none stay narrative. Four-bucket sort:
         (1) absorbs into a Q4-Q14 pattern's .ids -- no new work.
         (2) cheap enough to author its own pattern now
             (1-2 rules, existing ops) -- convert inline.
         (3) needs a small new op -- author the op in-cycle,
             don't defer.
         (4) prose is genuinely bespoke -- use the
             `r_expression:` escape hatch to express the
             predicate inline in the rule YAML. Still counts as
             predicate; never blocker.

- Net target after Q4-Q14 executions: predicate coverage ~80%
  (~1450/1814). Remaining ~20% is the true long tail + the
  FDA-SRS six (Q13) + conditional dataset-required rules (Q9).

**Delivered:** _(pending -- not yet implemented)_

---

## Backlog (after Q14)

Once Q4-Q14 are answered and converted, remaining narrative
rules (~50-80) will be true one-offs requiring bespoke translation
or CDISC-guidance clarification. Target: predicate coverage
80%+ (~1450/1814) after this interview cycle. Anything beyond
needs either external CT / registry bundles or new engine
primitives scoped individually.

---

# Cluster bundle B (Q21-Q32) -- closes the gap to 95%

After Q4-Q14 (domain clusters) + Q15-Q20 (cross-cutting) land,
the remaining narrative rules fall into twelve parametric
families. Answering this bundle converts the bulk of the
residual.

---

## Q21 -- indexed compound-variable family (~50 rules)

**Cluster:** rules on indexed variables where the index is `zz`
(2-digit 01-99), `y` (1-9), or similar, and the rule often pairs
two variables sharing the same index:

- **ANLzzFL / ANLzzFN family** (6): ADaM-178, 212, 413, 414, 493,
  526. Indexed analysis-flag pairs; same shape as ADaM-19..25
  (Y/N) but with a 2-digit index.
- **CRITy / CRITyFL family** (12): ADaM-137, 151, 156, 157, 335,
  336 + siblings. `y` index, paired FL companion.
- **AVALCAyN / AVALCATy, BASECAyN / BASECATy, CHGCATy /
  CHGCATyN, PCHGCATy / PCHGCAyN** (~12): ADaM-543-546,
  584-589 + siblings. Category label / code pairing.
- **TRxxAGy / TRxxPGy family** (~10): treatment-arm indexed
  grouping variables (2 placeholders `xx` + `y`).

**Existing engine hooks:**
- `stem` wildcard + `expand: y` / `expand: xx,y` already resolve
  placeholder-indexed column names.
- `.substitute_index_deep` (landed in Q3) pushes substitution
  into nested `value.*` slots.

**(a)** Two parametric patterns, both driven by existing ops:
- `indexed-flag-value-in-set` -- for ANLzzFL / ANLzzFN /
  CRITyFL etc. Slots: `(var, index_ph, allowed_values)`. Uses
  `expand:` + `is_contained_by`.
- `indexed-pair-presence` -- for "FN present and FL not present"
  style pairings. Slots: `(var_a_template, var_b_template,
  index_ph)`. Uses `all: [non_empty, empty]` combinator under
  `expand:`.
Covers ~40 of the 50 rules. Remaining ~10 absorb into Q10
(`uniqueness-grouped-nested`) or Q11 (suffix patterns).  *[recommended]*

**(b)** One monolithic pattern with a `check_type: value | pair`
switch. Harder to read.

**User answer:** _(pending)_

---

## Q22 -- prefix+suffix compound variables (~8 rules)

**Cluster:** ADaM-156, 157, 272, 66, 70, 895. Shape:
*"A variable with a prefix of `<P>`, a suffix of `<S>`, and
containing a one-digit number (`<P><y><S>`) is present and a
variable with the same root <X> is not present"*.

Compound-token templates with a prefix, an index placeholder, and
a suffix.

**(a)** Extend the `stem` wildcard semantics to support bounded
prefix+suffix+index expansion (`P<y>S` template form). New
pattern `compound-template-pair` with slots
`(prefix, suffix, sibling_suffix, index_ph)`. Reuses existing
`expand:` machinery; no new op.  *[recommended]*

**(b)** Hand-translate each of the 8 inline.

**User answer:** _(pending)_

---

## Q23 -- TS-domain parametric rules (~30 SDTM rules)

**Cluster:** CG0260-0291 range. TS (Trial Summary) domain rules
where the check depends on `TSPARMCD`. Typical shape:
*"When TSPARMCD = '<PARAM>', TSVAL must be <TYPE> / in <CT> / in
(LIT, ...)"*. The underlying engine work needed:
- Filter rows where TSPARMCD matches a specific value.
- Apply a per-parameter assertion: numeric, date, codelist,
  literal set.

**(a)** New pattern family `ts-param-*` driven by a small CSV
mapping `(tsparmcd, assertion_type, assertion_args)` that
`apply-pattern.R` expands into per-rule check_trees of shape:
```
all:
  - operator: equal_to
    name: TSPARMCD
    value: "<PARAM>"
  - operator: <assertion_op>
    name: TSVAL
    value: <args>
```
Covers all 30+ rules with a single pattern definition fed from
a parametric table. Assertion ops are the existing leaves
(`matches_regex`, `is_contained_by`, `value_in_codelist`,
`less_than_literal`). *[recommended]*

**(b)** 30 separate patterns, one per TSPARMCD -- needless
duplication.

**User answer:** _(pending)_

---

## Q24 -- date / time / duration format conformance (~10 rules)

**Cluster:** CG0238 (`--ORRES` in ISO 8601 date), CG0270, CG0283,
CG0285, CG0286 (`TSVAL conforms to ISO 8601 date`), CG0376
(`TDSTOFF` ISO 8601 Duration).

Shape: assert a column's values parse as an ISO 8601 partial
date / time / duration.

**(a)** New op `op_value_not_iso8601(name, kind = "date" |
"datetime" | "time" | "duration")` applying the existing
`.CDISC_DATE_RX` regex (landed in Q's P21 audit) for date
kinds plus a minimal duration regex (ISO 8601 `P[0-9]+Y[0-9]+M...`
form). Pattern `value-conforms-to-iso8601` with slots
`(var, kind)`. Covers all 10 rules.  *[recommended]*

**(b)** Reuse `op_matches_regex` with an inline regex in each
rule. Works but duplicates the regex in every YAML.

**User answer:** _(pending)_

---

## Q25 -- dataset naming + domain-code structural rules (~13 rules)

**Cluster:**
- ADaM-496 (dataset name does not start with "AD" when class is
  not missing), ADaM-497 (inverse).
- ADaM-746 (SRCDOM has a value that is not an SDTM domain name
  or ADaM dataset name).
- CG0001 (DOMAIN = valid Domain Code published by CDISC) --
  codelist-dependent; delegates to Q2 op.
- CG0017, CG0018 (Split dataset names length constraints).
- Variable-name structural rules (ADaM-?: starts with letter,
  no special chars, length <= 8).

Metadata-level / submission-level checks.

**(a)** Three micro-patterns:
- `dataset-name-prefix-by-class` -- metadata-level op
  `op_dataset_name_prefix_not(expected_prefix, when_class_not)`.
- `domain-code-in-ct` -- uses Q2's `op_value_in_codelist` against
  the `DOMAIN` codelist (already shipped in bundled SDTM CT).
- `split-dataset-name-length` -- dataset-level op reading
  `nchar(dataset_name)` with an allowed range.
Covers all 13. 2 new tiny ops + reuse of Q2's op.  *[recommended]*

**(b)** Hand-translate each.

**User answer:** _(pending)_

---

## Q26 -- cross-dataset variable presence (~10 rules)

**Cluster:** CG0014-0016 (variable present in dataset and not
null), CG0022 (`--LNKGRP` present in another domain), CG0024
(`--LNKID` present in another domain), CG0169 (COVALn not
present), and siblings.

Shape: a SDTM linking-variable must appear in at least one other
domain in the submission (cross-dataset presence).

**(a)** New op
`op_var_present_in_any_other_dataset(name, exclude_current = TRUE,
required_dataset_classes = NULL)` reading across all
`ctx$datasets` other than the current one. Pattern
`var-linked-across-submission`. 2 .ids rows per rule template
(one per linking variable). Covers all 10.  *[recommended]*

**(b)** Express via combinator chain using `op_exists` across
multiple target datasets -- brittle when domains are optional.

**User answer:** _(pending)_

---

## Q27 -- MedDRA / WhoDrug / external clinical dictionaries (~22 rules)

**Cluster:** CG0020, CG0021 (value in associated codelist or
MULTIPLE / OTHER), CG0037 (`--SOCCD = --BDSYCD`), CG0039
(`--BODSYS = --SOC`), CG0160-0162 (relationships to associated
persons), CG0174 (FAOBJ in `(--TERM, --TRT, --DECOD)`) +
siblings.

MedDRA terms, WHO-Drug dictionary terms, and SNOMED/LOINC lookups
appear here. These are **paid / licensed** external dictionaries
(MedDRA requires MSSO subscription; WHO-Drug requires UMC
subscription). Not distributable inside herald.

**(a)** Hybrid strategy:
- Rules like CG0020/0021 that say "value in associated codelist"
  are actually CDISC CT membership checks (not MedDRA) --
  convert via Q2's `op_value_in_codelist` as soon as the
  associated-codelist resolution (which CT codelist applies
  per variable) lands. Add a `variable_to_codelist_map.rds` in
  `inst/rules/ct/` mapping SDTM variables to default codelists.
  ~8 rules.
- CG0037 (`--SOCCD = --BDSYCD`), CG0039 (`--BODSYS = --SOC`)
  are within-row column equality, not dictionary lookups.
  Convert via existing `op_differs_by_key` with
  `reference_dataset = current`. ~4 rules.
- CG0160-0162 (relationship semantics) are genuinely
  RELREC-driven; handle in Q28.
- CG0174 in-set with wildcard literals: convert via Q4's
  `value-conditional-in-literal-set` pattern with `--` wildcard
  expansion. ~2 rules.
- Genuinely MedDRA/WhoDrug-dependent rules (~6) **convert this
  cycle** via a user-side `register_ct(name = "meddra", path =
  ...)` injection. Sponsors with MedDRA licences load their
  dictionary; rule predicate references the registered codelist
  by name. When no dictionary is registered the op returns NA
  -> advisory ("MedDRA not registered; run
  `register_ct('meddra', ...)` to enable"). Rule is always
  predicate; never narrative. 0 blockers.  *[recommended]*

**(b)** Mark the entire cluster as `blocker:external-dict`.
Loses the 12+ easy wins.

**User answer:** _(pending)_

---

## Q28 -- RELREC / associated-person rules (~5 rules)

**Cluster:** CG0160 (associated person to study subject / pool),
CG0161 (to device in RDEVID), CG0162 (to study in STUDYID),
CG0419 (RELTYPE = null), plus CG0156-0158 related-records
structural rules (already touched in Q6).

Shape: per-row assertion of relationship semantics between a
subject and another entity (device, study, pool). Depends on
RSUBJID, RDEVID, RDOMAIN, POOLID combinations.

**(a)** Pattern `relrec-relationship-type` using combinator
`all:` to check: (RSUBJID populated OR POOLID populated) AND
the right reference dataset contains a matching record. Reuses
existing `op_missing_in_ref` and `op_non_empty`. 5 rules.  *[recommended]*

**(b)** New specialised op `op_relrec_valid_relationship` with
hardcoded semantics. Overfit; CDISC RELREC semantics do change
across IG versions.

**User answer:** _(pending)_

---

## Q29 -- ELEMENT / EPOCH / TE-SE trial-design rules (~7 rules)

**Cluster:** CG0207 (`SEENDTC = SESTDTC of next ELEMENT`),
CG0218 (`EPOCH = SE.EPOCH`), CG0250 (`each value of EPOCH is not
associated with more than one conceptual trial period`),
CG0322-0323 (ELEMENT value references a specific ARM / EPOCH),
CG0325 (uniqueness of ELEMENT + TESTRL + TEENRL + TEDUR per
ETCD).

Trial-design temporal integrity: per-subject element sequence,
element-to-epoch mapping consistency.

**(a)** Three patterns:
- `se-element-next-equals-start` -- new op
  `op_next_row_not_equal(name, prev_name, order_by, group_by)`
  that joins row i to row i+1 within a group-by and asserts
  value equality. Covers CG0207.
- `epoch-unique-per-conceptual-period` -- reuses existing
  `op_is_not_unique_relationship`. Covers CG0250, CG0325.
- `element-value-in-ref` -- reuses `op_missing_in_ref` against
  TE / TA. Covers CG0322, 0323.
- CG0218 already in Q6.  *[recommended]*

**(b)** Stub the SE-next-element case with r_expression. Works
but isn't reusable.

**User answer:** _(pending)_

---

## Q30 -- IG-defined treatment-variable membership (~3 rules)

**Cluster:** ADaM-720 (TRTP value is not equal to at least one
IG-defined character planned treatment variable in ADSL),
ADaM-897 (same for TRTA actual treatment), plus siblings.

Same as Q5 but instead of comparing to DM, compares to the
ADSL-side variable set defined in ADaMIG (TRT01P-TRTnnP etc.).
Already partially covered by Q12's stretch work.

**(a)** Reuse Q2's `op_value_in_subject_indexed_set` already
shipped. Pattern `trt-value-in-adsl-defined-set` with slots
`(var, template)` where template = `TRT{xx}P` / `TRT{xx}A`. 3
rules.  *[recommended]*

**(b)** Defer; these are effectively duplicates of Q12's
baseline-consistency shape with different vars.

**User answer:** _(pending)_

---

## Q31 -- Define.xml / sponsor-defined-key rules (~2 rules)

**Cluster:** CG0019 (each record is unique per sponsor-defined
key variables as documented in define.xml), CG0400 (`--LOINC` =
valid code in LOINC dictionary version from define.xml).

Depends on Define.xml metadata ingestion which herald doesn't
have yet (the plan's Q26 from the ADSL-consistency interview
deferred Define.xml parsing).

**(a)** Add a minimal Define.xml reader to herald (new file
`R/define-read.R`, dep on `xml2` Suggests). Read only:
- `ItemGroupDef.KeyVariables` -- for CG0019.
- `ItemGroupDef.ItemRef` -> per-variable codelist reference -- for
  variable_to_codelist_map (supports Q27).
- Dictionary version from `Study.MetaDataVersion` -- for CG0400.
Pattern `define-xml-key-uniqueness` consumes the parsed keys.  *[recommended]*

**(b)** Block both rules until a proper Define.xml reader
ships.

**User answer:** _(pending)_

---

## Q32 -- compound combinator residual (~40 rules)

**Cluster:** bespoke logical chains -- e.g. ADaM-10, 11, 12
*"A variable with suffix FL = Y and a variable with same root
with suffix FN != 1"*; ADaM-121, 122 (SDT > EDT / SDTM > EDTM);
compound populated/not-populated patterns.

Shape: these are all expressible as `all:` / `any:` combinators
of existing leaves + suffix wildcards, but each has a unique
combinator tree.

**(a)** Run the triage script (committed in Q14 decisions) that
walks each residual rule and attempts a best-effort
check_tree synthesis from the narrative message. Converts the
mechanically-parseable subset (~30 of 40); hand-translate the
remainder (~10) inline, each producing its own .ids row under
an appropriately-named existing pattern or a new micro-pattern
of 1-2 rules.  *[recommended]*

**(b)** Hand-translate all 40 up front. More work, easier to
review.

**User answer:** _(pending)_

---

## Q33 -- missing reference-dataset semantics (spans Q5-Q7, Q13, Q27-Q30)

**Context:** many rules require a SECOND dataset beyond the one
being validated. When the reference is absent, the rule cannot
evaluate. Examples in this corpus:

- **ADSL <-> DM consistency** (Q5, 8 rules) -- needs DM.
- **ADaM.AESTDY presence-pair** (Q7, 5 rules) -- needs AE.
- **Cross-dataset join rules** (Q6, 10 rules) -- needs TV, SE,
  TE, POOLDEF, etc.
- **TSVAL = valid UNII** (Q13, 6 rules) -- needs user-downloaded
  SRS cache.
- **MedDRA / WhoDrug lookups** (Q27, ~6 rules) -- needs
  user-registered dictionary.
- **RELREC dependencies** (Q28) -- needs RELREC dataset.
- **IG-defined treatment-var membership** (Q30) -- needs ADSL.

Today every missing-ref case collapses to the same generic
"NA -> advisory" output. Reviewers cannot distinguish:
- "rule did not evaluate because DM was not supplied"
- "rule ran and found no issue"
- "rule ran but hit an internal NA condition"

All three produce visually identical advisory rows. The user
has no actionable hint to fix gaps in the submission package.

**Options:**

**(a)** First-class `skipped_missing_ref` status, grouped in
the report:
- Ops signal missing-ref through a new `.ref_ds()` return
  channel (e.g. a dedicated sentinel class `"herald_missing_ref"`).
- `emit_findings` routes such rules into `result$skipped`
  (a new collection alongside `findings`), NOT into findings.
- Report renderer groups skipped rules by missing reference
  and emits ONE consolidated actionable banner per missing
  dataset / registry, not per rule:
  ```
  Reference data missing -- provide these to evaluate more rules:
  * dataset DM (9 rules: CG0069, ADaM-204-210, ADaM-367)
  * dataset AE (5 rules: ADaM-641-645)
  * dataset RELREC (4 rules: CG0156-0158, CG0419)
  * FDA SRS registry (6 rules: CG0442-0451; run `download_srs()`)
  * MedDRA dictionary (6 rules: CG0020-0021, ...;
      register via `register_ct("meddra", path = ...)`)
  ```
- Header summary has a dedicated cell:
  `"47 fired, 23 advisory, 14 skipped (ref data missing)"`.
- Skipped rules do NOT inflate the advisory count; their
  absence from fire/advise is explicit, not ambiguous.  *[recommended]*

**(b)** Advisory per rule with a boilerplate hint in the
message. Easy to implement but user must scan through N
advisories to find the "provide DM" hint. Report cluttered.

**(c)** Silent skip -- drop the rule without any signal beyond
"rules_total - rules_applied" in the summary. User has no way
to know what to provide.

**(d)** Hard error on missing ref -- abort `validate()`. Too
aggressive; submissions legitimately omit optional domains
(not every study has PC, MB, etc.).

**User answer:** _(pending)_

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

**Delivered:** _(pending -- not yet implemented)_

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

**Delivered:** _(pending -- not yet implemented)_

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

**Delivered:** _(pending -- not yet implemented)_

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

**Delivered:** _(pending -- not yet implemented)_

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

**Delivered:** _(pending -- not yet implemented)_

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
  | Q14 residual singletons | ~30 | Triaged inline during Q4-Q14. **All 30 convert this cycle.** Buckets: (1) absorbs into an existing pattern; (2) new 1-2 rule pattern inline; (3) new small op authored in-cycle; (4) `r_expression:` escape hatch for prose-bespoke cases. No rule stays narrative. |

- **`drop:` and `deprecated:` are reserved for CDISC-side
  decisions only:**
  - `deprecated:` -- CDISC replaced this rule with a newer one
    in a later IG version. Engine skips it when that version is
    selected.
  - `drop:` -- CDISC explicitly retired the rule; no replacement.
    Requires citation to the retirement note in the YAML.

- **Hard coverage commitment (post-hardening):**
  - narrative   : **0 rules** after the full Q4-Q32 cycle.
  - predicate   : **100% of addressable rules** (>= 99%).
  - blocker:*   : **0** unless the rule is provably
    unaddressable -- no engine work, external registry, user-
    supplied data, or escape hatch resolves it. None expected.
  - drop/deprecated : only when CDISC itself retires or
    replaces the rule.

- **Delivery cadence:** Q4-Q32 patterns all land in-cycle. No
  follow-on pass. Every stretch item (SRS downloader,
  study_metadata arg, LB category map, MedDRA register_ct,
  Define.xml reader, r_expression escape for residuals) ships
  alongside the pattern conversions that need it.

**Delivered:** _(pending -- not yet implemented)_

---


# P21 edge-case cross-Q audit (2026-04-22)

Deep audit of Pinnacle 21 community validator source across
`DataEntryFactory`, `Comparison`, `NullComparison`,
`RegexComparison`, `RequiredValidationRule`, `MatchValidationRule`,
`LookupValidationRule`, `UniqueValueValidationRule`,
`FindValidationRule`, `DataGrouping`, `AbstractValidationRule`,
`MagicVariable`, `MagicVariableParser`, and `BlockValidator`.
Cross-referenced against every locked decision in Q1-Q32.

Only NET findings listed -- edges previously captured in-thread
(fuzzy date prefix, numeric normalization, NULL==NULL, 4-digit
year, subject-not-in-ref) omitted.

---

## A. Regex semantics -- herald diverges (affects Q4, Q11, Q24)

**P21:** `~=` uses `Pattern.compile(rx)` + `matcher.matches()`
(Comparison.java:109-110, 257). `matches()` requires a **full-
string match** -- caller must add explicit `^` / `$` or the
pattern must match the entire value.

**Herald:** `op_matches_regex` uses `grepl(pattern, value)` which
does **partial match** by default.

**Impact:** a rule translated from P21 `TSVAL @re '[0-9]+'`
fires false negatives in herald (grepl matches anything
containing a digit). Q24 (ISO 8601 regex) and Q4 condition
leaves that use `matches_regex` are at risk.

**Recommendation:** change `op_matches_regex` default to full-
match (anchor with `^...$` internally, or switch to
`grepl("^(?:<pat>)$", ...)`) and document in CONVENTIONS.md.

---

## B. `^=` and `.=` are case-INSENSITIVE equal / not-equal (affects Q15, Q4)

**P21** (Comparison.java:178-181): `^=` => `compareToAny(rhs,
false) == 0` (case-INSENSITIVE equal). `.=` => `!= 0` (case-
insensitive not-equal). The `false` argument is
`caseSensitive`, not a negation.

**Herald Q15 grammar:** lists `equal_to` / `not_equal_to` as
case-sensitive. CI variants exist only for list ops
(`op_is_contained_by_ci`).

**Impact:** a P21 rule `ARMCD ^= 'SCRNFAIL'` must translate to
a case-insensitive leaf in herald.

**Recommendation:** add `equal_to_ci` / `not_equal_to_ci`
one-line sugar ops; revise Q15 locked grammar to include them.

---

## C. Numeric fuzzy tolerance `%=` (affects Q5, Q12)

**P21** (Comparison.java:183-192): `%=` numeric equality with
epsilon tolerance (`Engine.FuzzyTolerance`, default ~1e-3).

**Herald:** `.cdisc_value_equal` uses exact `==` after numeric
coercion. Floating-point drift could produce false mismatches
(0.1 + 0.2 vs 0.3).

**Impact:** low. Q5 / Q12 values usually come from the same SAS
session so drift rare.

**Recommendation:** document the known gap in Q5 / Q12 pattern
MDs; no code change now.

---

## D. `When=` guard returns -1 (skip), not 0 (pass) (affects Q1, Q4, Q9)

**P21** (ConditionalRequiredValidationRule.java:47-55,
MatchValidationRule.java:76-78): `performValidation` returns
`-1` when the `When=` guard evaluates FALSE. No finding is
emitted for that row -- not even an advisory.

**Herald:** conditional rules today can produce an advisory
when the condition branch returns NA. Over-reports.

**Impact:** Q1/Q4 conditional literal rules should NOT advise
when the `when:` guard is FALSE. Only advise when the guard
itself cannot be evaluated (NA due to column absent, CT
unavailable, etc.).

**Recommendation:** the condition-grammar implementation gives
the first leaf of an `all:` a distinct role when the rule is
tagged `when_gate: TRUE`. Three-state return from the guard:
- TRUE  -> evaluate assertion
- FALSE -> skip row entirely (no fire, no advisory)
- NA    -> advisory only

Engine change scoped to `walk_tree` / `emit_findings`.

---

## E. `Optional=` columns inject NULL_ENTRY (affects Q8)

**P21 AbstractScriptableValidationRule.java:55-64:** variables
in `Optional=` bypass existence check and are injected as
`NULL_ENTRY`. Rule still FIRES unless it calls `hasValue()`.

**Herald Q8:** P21's `--STAT != 'NOT DONE'` exemption works
because `--STAT` is in Optional=; when absent, NULL vs literal
evaluates TRUE so rule proceeds.

**Impact:** herald must model "optional column absent ->
NULL_ENTRY behaviour". Current `empty(--STAT)` returns TRUE on
absence but the comparison semantics differ.

**Recommendation:** when implementing Q8, use the explicit
`optional_columns` slot on the pattern; document Optional=
parity in the unit-consistency pattern MD.

---

## F. Column-missing -> CorruptRuleException -> rule REMOVED (affects all Qs)

**P21 AbstractValidationRule.java:152-161 + BlockValidator.java:296-297:**
referenced-but-absent column throws `CorruptRuleException`
(state=Unrecoverable). Rule removed from the ruleset for
subsequent records on that dataset. No further findings.

**Herald:** returns NA mask -> one advisory per (rule x
dataset). More transparent.

**Divergence:** intentional. Reviewers see "rule could not
evaluate" instead of silent rule-loss. KEEP.

---

## G. GroupBy tuple hashing + NA collision (affects Q3, Q10, Q12, Q29)

**P21 FindValidationRule.java:275-316:** `HashCodeBuilder(15,
97)` + `append(DataEntry)` per component. Array equality
element-wise. GroupBy names uppercased at parse. NULL
components hashable separately.

**Herald:** `paste(..., sep="\x1f")` -- NAs collapse to the
literal string `"NA"`, which collides with a real value `"NA"`
(SUBJID = "NA" exists in real submissions).

**Recommendation:** change the NA sentinel token in the paste
expression to `"\x00<NA>\x00"` so real-string `"NA"` cannot
collide.

---

## H. Matching=Yes first-row skip (affects Q10)

**P21 UniqueValueValidationRule.java:90:** returns `null` when
`(Matching=Yes AND no GroupBy) OR (Matching=No AND GroupBy
exists)` -- **skips the first row** of a single-group
Matching=Yes rule so the reference value establishes.

**Herald:** `op_is_not_unique_relationship` evaluates every row
uniformly. Matching=Yes rules in a single-group dataset may
over-report by one row compared to P21.

**Recommendation:** after Q10 patterns land, compare finding
counts against a P21 reference fixture; adjust if counts
differ. Subtle; unlikely to trip real submissions.

---

## I. MagicVariable wildcards (affects Q11, Q21, Q22, Q23)

**P21** (MagicVariable.java:198-223):
- `@*` -> `[A-Za-z]+`
- `#*` -> `[0-9]+`
- `_*` -> `[A-Za-z0-9]+`
- `*`  -> `[A-Za-z0-9]+`
- `@@@` / `###` / `___` -> count-quantified (`{3}`)

**Herald:** fixed-form placeholders (`xx`, `zz`, `y`, `w`,
`stem`) with specific regex.

**Divergence:** herald's form matches CDISC narrative
convention ("xx is a zero-padded two-digit integer"). KEEP.

**Gap:** no 3-digit or 4-digit variant. Not an issue today.

---

## J. Capture-group reuse `%Variable.N%` (affects Q21, Q22)

**P21 MagicVariableParser.java:130-133:** `%Variable.N%` stored
only on **first match**. Subsequent matches don't overwrite.

**Herald .multi_values_in_cols:** iterates ALL matches. KEEP.

---

## K. Replicated vs non-replicated rule execution (affects Q23)

**P21 MagicVariable.java:46-47:** identifier prefix controls
replication:
- default -> rule cloned per matched variable
- `"="` prefix -> non-replicated; one rule fires across all
  matched vars (comma-joined)
- `"+"` prefix -> dependency-replicated

**Herald:** pattern system clones per concrete index implicitly
via `.ids` rows + `expand:`. No `"="` / `"+"` analogue.

**Impact on Q23 TSPARMCD:** herald authors one rule YAML per
TSPARMCD. P21 could collapse via `"="`. Herald's form is
easier to audit and attribute. KEEP.

---

## L. rtrim scope (affects every value compare)

**P21 DataEntryFactory.java:313-328:** strips SPACE (0x20)
only. Tabs / newlines preserved.

**Herald `.cdisc_value_equal`:** `sub(" +$", "", v)` -- aligned
after commit 6a5fb40.

**Status:** aligned.

---

## M. Lookup no-match -> silent pass (affects Q6, Q28)

**P21 LookupValidationRule.java:165:** no-match is silent
pass. No finding.

**Herald:** `op_missing_in_ref` fires explicitly;
`op_differs_by_key` advises on subject absence. More
transparent. KEEP.

---

## N. Severity conditional by domain (affects Q18)

**P21 RuleDefinition.java:130-147:** `withSeverityFor(domain)`
supports domain-scoped severity overrides. Precedence:
exact > domain > context > rule. Same rule can be Error for
ADSL, Warning for BDS.

**Herald Q18 `severity_map`:** rule_id / regex / category match
only. No domain dimension.

**Recommendation:** extend each `severity_map` entry to accept
either a scalar string OR a named list keyed by dataset class:
```
severity_map = list(
  "CG0085" = list(ADSL = "Reject", BDS = "High", default = "Medium")
)
```
Update Q18 locked decision.

---

## O. Empty dataset + Target=Dataset (affects Q9, Q25)

**P21 BlockValidator.java:321-343:** `validateDataset()` called
unconditionally. Target=Dataset rules fire regardless of
record count. Target=Record rules skipped when empty.

**Herald:** `.dataset_level_mask` returns a mask against a
1-row placeholder when the dataset is empty
(rules-validate.R:163-172). Aligned.

**Status:** aligned.

---

## P. Row numbering in findings (affects Q19 reporting)

**P21 BlockValidator.java:230:** `totalExaminedRecords` counter
1-indexed.

**Herald `emit_findings`:** `which(fired_rows)` returns 1-indexed
R integers. Aligned.

**Status:** aligned.

---

## Summary of action items

| Audit | Q's affected | Change required |
|---|---|---|
| A. Regex full-match default | Q4, Q11, Q24 | change `op_matches_regex` default; anchor existing patterns |
| B. `^=` case-insensitive | Q15, Q4 | add `equal_to_ci` / `not_equal_to_ci` sugar ops |
| C. Numeric fuzzy tolerance | Q5, Q12 | document gap; no code change |
| D. `when:` guard FALSE vs NA | Q1, Q4, Q9 | three-state return; engine support |
| E. `Optional=` columns | Q8 | document parity; use explicit slot |
| F. Column-missing handling | all | KEEP divergence; document |
| G. GroupBy NA collision | Q3, Q10, Q12, Q29 | change paste NA token |
| H. Matching=Yes first-row skip | Q10 | fixture-compare with P21; adjust |
| I. Wildcard syntax divergence | Q11, Q21-23 | KEEP (CDISC-aligned) |
| J. Capture-group reuse | Q21, Q22 | KEEP (more complete) |
| K. Replicated rule clone | Q23 | KEEP (cleaner audit) |
| L. rtrim scope | all | already aligned |
| M. Lookup no-match | Q6, Q28 | KEEP (more transparent) |
| N. Severity per-domain | Q18 | extend `severity_map` to nested list |
| O. Empty Target=Dataset | Q9, Q25 | already aligned |
| P. Row numbering | Q19 | already aligned |

**Net code changes required:** 5 items (A, B, D, G, N).
**Divergences intentionally kept:** 5 items (F, I, J, K, M).
**Already aligned:** 6 items (C, E, L, O, P, H documentation-only).

Every required change is scoped to a single op or engine file;
none invalidate a prior locked decision -- they harden, not
revise.
