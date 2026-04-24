---
paths:
  - "R/**/*.R"
---

# R/ source rules

## Operator pattern (R/ops-*.R)

Every new op:

1. Signature: `op_<name>(data, ctx, ...) -> logical(nrow(data))`.
   TRUE = fires, FALSE = pass, NA = advisory. Vector length must
   always equal `nrow(data)` except when the dataset is empty
   (return `logical(0)`).
2. Register via `.register_op("<name>", op_<name>, meta =
   list(kind, summary, arg_schema, cost_hint, column_arg,
   returns_na_ok))` at the bottom of the op definition.
   - `kind` ∈ `{"set","compare","existence","temporal","cross","string"}`.
   - `arg_schema` entries declare `type` ∈ `{"string","integer",
     "boolean","array","object","any"}` + `required` or `default`.
3. Cross-dataset ops resolve the reference via
   `.ref_ds(ctx, ref_name)`. Absent reference auto-records to
   `ctx$missing_refs$datasets` and surfaces in
   `result$skipped_refs`. Do not wrap this behaviour.

## Errors

Use `herald_error(msg, class = "herald_error_<kind>", call)` from
`R/herald-conditions.R`. Kinds: `input`, `runtime`, `file`,
`spec`, `rule`, `validation`. Never bare `stop()` /
`rlang::abort()`.

Message format (cli-friendly):

```r
herald_error(c(
  "Bad {.arg {arg}}.",
  "x" = "You supplied {.obj_type_friendly {x}}.",
  "i" = "Use {.fn as_herald_spec} to build one."
), class = "herald_error_input", call = call)
```

## Input validation

Use the `check_*` helpers (`R/herald-conditions.R:158+`):
`check_scalar_chr`, `check_scalar_int`, `check_data_frame`,
`check_herald_spec`, `check_file_exists`. Always pass
`call = rlang::caller_env()`.

## Housekeeping

- Dot-prefix all non-exported helpers.
- `@noRd` on every non-exported function's roxygen block.
- Shared helpers go in `R/herald-utils.R`, op infra in
  `R/herald-ops.R`, condition / check helpers in
  `R/herald-conditions.R`.
- No `library(...)` inside R/. Use `pkg::fn`; add a new dep via
  `usethis::use_package()` only after user sign-off.
- No `setwd()`. Use explicit paths or `system.file()`.
- `%||%` is imported from rlang. Do not re-define.
- ASCII-only in comments. `--` not em-dash.
- Run `devtools::document()` after any `@export` or signature
  change so NAMESPACE + `man/*.Rd` stay in sync. Never hand-edit
  `man/*.Rd` or `NAMESPACE`.
