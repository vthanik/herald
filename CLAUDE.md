# herald

pure-R CDISC conformance validator. FDA/PMDA/EMA submissions.
no JVM. alternative to Pinnacle 21. pre-CRAN: break anything
anytime. build right, not compat. local-only: no GitHub remote
is authoritative.

## after every change

```bash
Rscript -e 'devtools::document()'
Rscript -e 'devtools::test()'
Rscript -e 'devtools::check(args = "--no-manual")'
```

0 fail / 0 warn / 0 error. fix before commit.

## layer stack

```
6  write_report_html() / xlsx / json     reporting
5  validate(files = ..., rules = ...)     conformance engine
4  rule corpus (YAML -> rules.rds)        rule catalog
3  Dictionary Provider Protocol           CT / SRS / MedDRA / user
2  apply_spec(datasets, spec)             pre-validation attr stamp
1  as_herald_spec() / ds_spec + var_spec  specification object
0  read_xpt / read_json / read_parquet    dataset ingest
```

## public api (by layer)

- **L0 ingest:** `read_xpt`, `write_xpt`, `read_json`, `write_json`,
  `read_parquet`, `write_parquet`, `xpt_to_json`, `json_to_xpt`.
- **L1 spec:** `as_herald_spec`, `is_herald_spec`.
- **L2 pre-step:** `apply_spec`.
- **L3 dict providers:** `load_ct`, `ct_info`, `ct_provider`,
  `srs_provider`, `meddra_provider`, `whodrug_provider`,
  `loinc_provider`, `snomed_provider`, `custom_provider`,
  `register_dictionary`, `unregister_dictionary`,
  `list_dictionaries`, `new_dict_provider`.
- **L3 downloaders:** `available_ct_releases`, `download_ct`,
  `download_srs`.
- **L5 engine:** `validate`.
- **L6 report:** `write_report_html`, `write_report_xlsx`,
  `write_report_json`, `report`.

## R/ module taxonomy

```
herald-*    foundation      (conditions, ops registry, utils, package)
xpt-*       xpt i/o         (read, write, header, ieee, encoding)
json-*      dataset-json    (read, write, round-trip)
parquet-*   parquet         (read, write)
spec-*      spec object     (schema + accessors)
apply-*     spec pre-step   (attr stamping)
ct-*        ct machinery    (load, cache, fetch)
dict-*      dictionary providers  (ct / srs / ext)
ops-*       rule-engine leaves    (set, compare, existence, temporal, cross, string)
rules-*     engine core     (validate, walk, findings, scope, crossrefs)
index-*     indexed wildcard expansion
sub-*       submission      (class, discover, manifest)
report-*    output          (html, xlsx, json, utils)
class-*     class-detection heuristics
val-*       result object
```

## rule id taxonomy

```
ADaM-N         ADaM-IG conformance rule (1..~900)
CGNNNN         CDISC Conformance Guide / SDTM-IG (CG0001..CG06xx)
HRL-*-NNN      herald-authored gap-fill / hard-coded spec checks
```

authored YAMLs live under `tools/handauthored/cdisc/<standard>/`.
compiled catalog: `inst/rules/rules.rds`.

## ops contract (non-negotiable)

every op in `R/ops-*.R`:

```r
op_<name> <- function(data, ctx, ...) {
  # returns logical(nrow(data)); TRUE = fires, FALSE = pass,
  # NA = advisory.
}
.register_op("<name>", op_<name>, meta = list(
  kind          = "cross",    # set|compare|existence|temporal|cross|string
  summary       = "...",
  arg_schema    = list(...),
  cost_hint     = "O(n)",     # O(1)|O(n)|O(n log n)|O(n*m)
  column_arg    = "name",
  returns_na_ok = TRUE
))
```

cross-dataset ops resolve via `.ref_ds(ctx, <name>)` -- absent
datasets auto-record to `ctx$missing_refs$datasets` and surface
in `result$skipped_refs` with an actionable hint.

## errors

always `herald_error(msg, class = "herald_error_<kind>", call)`
from `R/herald-conditions.R`. valid kinds: `input`, `runtime`,
`file`, `spec`, `rule`, `validation`. never bare `stop()` /
`rlang::abort()`. message format:

```r
herald_error(c(
  "Bad {.arg {arg}}.",
  "x" = "You supplied {.obj_type_friendly {x}}.",
  "i" = "Use {.fn as_herald_spec} to build one."
), class = "herald_error_input", call = call)
```

input validation via `check_scalar_chr`, `check_scalar_int`,
`check_data_frame`, `check_herald_spec`, `check_file_exists`.
always pass `call = rlang::caller_env()`.

## code conventions

- no `|>` / `%>%`. explicit function composition.
- verb-first snake_case for exports; dot-prefix for internals.
- `%||%` from rlang (180 uses). do not re-define.
- ASCII only in R comments. `--` not em-dash.
- roxygen `#'`, markdown = TRUE, `@noRd` on internals.
- shared helpers in `R/herald-utils.R`, op infra in
  `R/herald-ops.R`, conditions in `R/herald-conditions.R`.
- no `library()` in R/. no `setwd()`. no hardcoded paths.

## testing

- testthat edition 3. one `test-<source>.R` per R/ file.
- inline `data.frame()` fixtures; RDS only for real CDISC data.
- `withr::defer(unlink(...))` for temp files.
- no snapshots. no mocks. hermetic.
- error tests pin the class: `expect_error(..., class = "herald_error_input")`.
- reach internals via `herald:::.fn` so tests survive R CMD check.
- no `helper-*.R` / `setup-*.R`.

log + grep the output on failures:

```bash
Rscript -e 'devtools::test()' > /tmp/t.log 2>&1
grep -E "FAIL [0-9]|PASS [0-9]" /tmp/t.log | tail -3
grep -nB1 -A15 "Failure|Error" /tmp/t.log | head -60
```

## git hygiene

- local-only. never `git push` without explicit approval per
  session.
- never commit: `CLAUDE.local.md`, `.claude/settings.local.json`,
  `.local/**`, `.Rproj.user/`, `renv/library/` (if it lands).
- never hand-edit `man/*.Rd`, `NAMESPACE`, `inst/rules/rules.rds`,
  `inst/rules/rules.jsonl`, `inst/rules/MANIFEST.json` -- these
  are generated by `devtools::document()` or
  `tools/compile-rules.R`.
- no `Co-Authored-By` trailers.
- conventional commit subjects under 70 chars. body lines under
  80. reference rule ids / Q numbers where relevant.
- non-package files belong in `.local/`, never root.

## pre-existing issues

`devtools::check()` surfacing a warn / err / note NOT caused by
the current change: flag it, ask before fixing. autonomy covers
the change in hand -- not scope creep.

known: `tests/testthat/test-fast-ops-meta.R:31` uses unqualified
`.op_meta()` / `.get_op()`. works under `devtools::test()` via
load_all; fails under R CMD check installed-package mode.
one-line fix pending user sign-off.

## interview + plan refs

- rule-conversion backlog: `tools/rule-authoring/INTERVIEW.md`
  (Q1-Q33 answered, Q4-Q32 queued). status snapshot at top.
- implementation plan:
  `/Users/vignesh/.claude/plans/cached-nibbling-penguin.md`.
- memory: `/Users/vignesh/.claude/projects/-Users-vignesh-projects-r-herald/memory/`
  (MEMORY.md indexes the session-persistent rules).

## long-running commands

`devtools::test()` and `devtools::check()` in background when
output is not immediately needed -- use `run_in_background: true`
on Bash calls, or delegate to the `.claude/agents/checker.md`
subagent (worktree-isolated).

## model routing

| task | model |
|---|---|
| single-file fix / test add / doc tweak / `.ids` authoring | Sonnet |
| pattern authoring + apply + compile + commit (one cluster) | Sonnet |
| Dictionary Provider phase / new op family / engine change | Sonnet or Opus (architectural) |
| cross-cutting refactor engine + rules + report + tests | Opus |
| interview design / multi-source research (herald-v0 + P21) | Opus + Explore agents |

## subagents available

- `test-runner` -- devtools::test(), green/red only.
- `checker` -- devtools::check() in a worktree.
- `rule-author` -- narrative -> predicate conversion per one
  INTERVIEW.md Q.

scoped rules live at `.claude/rules/r-code.md` (R/**/*.R) and
`.claude/rules/tests.md` (tests/testthat/**/*.R).

## skills

none yet. on-demand skills (e.g. heraldrules-style) can land at
`~/.claude/skills/` when a reusable workflow crystallises. do
not auto-invoke; user must type `/skill-name` or say "use the
X skill".
