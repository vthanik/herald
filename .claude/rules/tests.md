---
paths:
  - "tests/testthat/**/*.R"
---

# Test rules

## Layout

- One `test-<source>.R` per file in `R/` that exports behaviour.
- No `helper-*.R` / `setup-*.R`. Inline dot-prefixed helpers
  inside the test file if factored code is needed.
- testthat edition 3 (see `DESCRIPTION: Config/testthat/edition`).

## Fixtures

- Prefer small inline `data.frame()` literals over RDS.
- Use RDS only when the test needs real CDISC structure (see
  bundled CT at `inst/rules/ct/*.rds`).
- For I/O tests always `withr::defer(unlink(tmp_path))` after
  creating a tempfile.

## Assertions

- Expectation-based only (`expect_equal`, `expect_s3_class`,
  `expect_true`, `expect_error`, `expect_type`).
- No mocks. Hermetic.
- Snapshots are required for error messages and complex output:
  - Use `expect_snapshot(error = TRUE)` for error tests (captures
    full message text).
  - Use `expect_snapshot()` for warning/message tests and complex
    printed output.
- Error tests must ALSO pin the class alongside the snapshot:
  `expect_error(..., class = "herald_error_input")`. Both are
  required -- class pins the type; snapshot pins the message.
- Rule-engine tests use `validate(files = list(...), rules =
  "<id>", quiet = TRUE)` and assert on `result$findings`.

## Internals

Reach private functions via `herald:::.fn` -- unqualified works
under `devtools::test()` (load_all) but fails under
installed-package testing / R CMD check. Always qualify.

## Running locally

```bash
Rscript -e 'devtools::test()'
Rscript -e 'devtools::test(filter = "ct-load")'
Rscript -e 'devtools::test(filter = "dict-providers")'
```

Log + grep on failures:

```bash
Rscript -e 'devtools::test()' > /tmp/t.log 2>&1
grep -E "FAIL [0-9]|PASS [0-9]" /tmp/t.log | tail -3
grep -nB1 -A15 "Failure|Error" /tmp/t.log | head -60
```
