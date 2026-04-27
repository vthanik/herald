# Operator catalog

The herald validation engine dispatches each rule to a registered
**operator** (an "op") – a vectorised predicate with signature
`op(data, ctx, ...) -> logical(nrow(data))`. The full sortable catalog
of built-in operators, their kinds (set, compare, existence, temporal,
cross, string, spec), arg schemas, cost hints, and source files is
rendered in `vignette("op-catalog", package = "herald")`.

## Details

Operators are not user-callable functions. They are referenced from rule
YAML files via their registered name and resolved at validation time.
Use the catalog vignette to plan custom rules, audit coverage, or extend
the engine with a new operator family.

## See also

`vignette("op-catalog", package = "herald")` for the rendered catalog.
[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
for running rules backed by these operators.
