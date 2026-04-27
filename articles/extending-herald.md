# Extending herald

`herald` is built around two extension points that let you add domain
logic without forking the package: **operators** (the building blocks of
rules) and **dictionary providers** (controlled-terminology membership
checks). This article walks through both.

## When to extend

| Need                                           | Extend                                                                           |
|------------------------------------------------|----------------------------------------------------------------------------------|
| Add a sponsor-specific check no rule expresses | New operator + rule                                                              |
| Plug in MedDRA, WHODrug, sponsor codelist      | New dictionary provider                                                          |
| Wire a different report format                 | Custom [`report()`](https://vthanik.github.io/herald/reference/report.md) method |
| Override severity policy                       | Use `severity_map=` (no extension needed)                                        |

The two extensions below cover the common cases. Custom report formats
are a smaller wrapper around the existing writers and are not covered
here.

## Part 1 – Custom dictionary providers

A dictionary provider answers one question: *does this value exist in
this codelist or registry?* CDISC CT, FDA SRS, MedDRA, WHODrug, LOINC,
SNOMED, and any sponsor-private codelist all surface through the same
protocol so rule operators do not need to know the source format.

### The protocol

Every provider object (class `herald_dict_provider`) carries:

- `name`, `version`, `source`, `license` – metadata fields.
- `size_rows` – number of rows in the underlying table.
- `fields` – the column / field names you can query.
- `contains(value, field, ignore_case)` – a function returning a logical
  vector parallel to `value`. **Required.**
- `info()` – a closure that returns the metadata above.
- `lookup(value, field)` – optional. Returns matching rows for richer
  rule diagnostics.

Use
[`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md)
to construct one. It validates the contract and sets the S3 class.

### Recipe: a tiny membership-only provider

If your codelist is just a vector of accepted values, this is the
minimum boilerplate.

``` r
allowed_units <- c("KG", "LB", "G", "MG")

unit_provider <- new_dict_provider(
  name      = "study-units",
  version   = "2026-04",
  source    = "sponsor",
  fields    = "code",
  size_rows = length(allowed_units),
  contains  = function(value, field = "code", ignore_case = FALSE) {
    if (isTRUE(ignore_case)) {
      toupper(value) %in% toupper(allowed_units)
    } else {
      value %in% allowed_units
    }
  }
)

unit_provider$contains(c("KG", "kg", "stones"))
#> [1]  TRUE FALSE FALSE
unit_provider$contains(c("KG", "kg", "stones"), ignore_case = TRUE)
#> [1]  TRUE  TRUE FALSE
unit_provider
#> <herald_dict_provider>
#>   name     : study-units
#>   version  : 2026-04
#>   source   : sponsor
#>   license  : unknown
#>   size     : 4 rows
#>   fields   : code
```

### Recipe: a tibble-backed provider with `lookup()`

Most sponsor codelists are richer than a flat vector. Pass a
`data.frame` to
[`custom_provider()`](https://vthanik.github.io/herald/reference/custom_provider.md)
for the common case (it returns a full `herald_dict_provider`), or
hand-build with
[`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md)
to add a `lookup()` function.

``` r
sites <- data.frame(
  code = c("S01", "S02", "S03"),
  name = c("Boston General", "Madrid Clinic", "Tokyo Medical"),
  stringsAsFactors = FALSE
)

site_provider <- new_dict_provider(
  name      = "site-codes",
  version   = "study-A-2026",
  source    = "sponsor",
  fields    = c("code", "name"),
  size_rows = nrow(sites),
  contains  = function(value, field = "code", ignore_case = FALSE) {
    col <- sites[[field]]
    if (isTRUE(ignore_case)) {
      toupper(value) %in% toupper(col)
    } else {
      value %in% col
    }
  },
  lookup = function(value, field = "code") {
    sites[sites[[field]] %in% value, , drop = FALSE]
  }
)

site_provider$contains(c("S01", "S99"))
#> [1]  TRUE FALSE
site_provider$lookup("S02")
#>   code          name
#> 2  S02 Madrid Clinic
```

### Registering the provider

[`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md)
puts a provider in the session registry so every later
[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
call sees it. Or pass it inline via `validate(dictionaries = list(...))`
for a fully self-contained run.

``` r
register_dictionary("site-codes", site_provider)
list_dictionaries()
#> # A tibble: 1 × 5
#>   name       version      source  license size_rows
#>   <chr>      <chr>        <chr>   <chr>       <int>
#> 1 site-codes study-A-2026 sponsor unknown         3

# Self-contained: pass the providers directly to validate()
r <- validate(
  files = list(DM = dm),
  rules = character(0),
  dictionaries = list("site-codes" = site_provider),
  quiet = TRUE
)

unregister_dictionary("site-codes")
```

### Resolution precedence

When a rule asks for a dictionary by name, herald looks (in order):

1.  The `dictionaries=` argument of
    [`validate()`](https://vthanik.github.io/herald/reference/validate.md)
    (explicit override).
2.  The session registry (set by
    [`register_dictionary()`](https://vthanik.github.io/herald/reference/register_dictionary.md)).
3.  Cache-discoverable providers (e.g. SRS via
    [`download_srs()`](https://vthanik.github.io/herald/reference/download_srs.md)).
4.  The bundled CDISC CT (always available via
    [`ct_provider()`](https://vthanik.github.io/herald/reference/ct_provider.md)).
5.  If still missing, the rule is skipped and the miss is recorded in
    `result$skipped_refs` with a hint to register it.

### Provider checklist

| Field       | Required | Notes                                                                                                                                                |
|-------------|----------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| `name`      | yes      | Short canonical key, e.g. `"meddra"`.                                                                                                                |
| `contains`  | yes      | Returns logical vector parallel to value.                                                                                                            |
| `version`   | strongly | Locks reproducibility. Default `NA_character_`.                                                                                                      |
| `fields`    | strongly | Fields the rule may pass via `field =`.                                                                                                              |
| `size_rows` | optional | Used by [`print()`](https://rdrr.io/r/base/print.html) and [`list_dictionaries()`](https://vthanik.github.io/herald/reference/list_dictionaries.md). |
| `lookup`    | optional | Returns one row per match for diagnostics.                                                                                                           |
| `info()`    | auto     | Built by [`new_dict_provider()`](https://vthanik.github.io/herald/reference/new_dict_provider.md) from the above.                                    |

## Part 2 – Custom operators

An *operator* is a small function that returns a logical vector saying
which rows of a dataset fail a check. Rules in the YAML catalog
reference operators by name and supply arguments. Examples of built-in
operators include `iso8601`, `unique_key`, `subset_of`, and
`regex_match`.

### The contract

Every operator is a function with this signature:

``` r
op_<name> <- function(data, ctx, ...) {
  # data : the data frame currently under check
  # ctx  : run context (datasets, dict, missing_refs, ...)
  # ...  : rule-supplied arguments (column names, regex, etc.)
  #
  # return: logical vector of length nrow(data)
  #   TRUE  -- record fires (rule fails on this row)
  #   FALSE -- record passes
  #   NA    -- indeterminate / advisory
}
```

Length contract: the returned vector **must** be `nrow(data)` long
unless `data` is empty (return `logical(0)`).

### A worked example: a “must-be-positive” operator

The pattern below is what any new op file in `R/ops-*.R` looks like. The
actual registration uses an internal helper invoked at package load; the
function body is the part you write.

``` r
op_positive <- function(data, ctx, column = NULL, ...) {
  if (is.null(column)) {
    return(rep(NA, nrow(data)))
  }
  x <- data[[column]]
  if (is.null(x)) {
    return(rep(NA, nrow(data)))
  }
  # FALSE = passes the check (positive); TRUE = fires (non-positive)
  is.na(x) | !(is.numeric(x) & x > 0)
}
```

Key points:

- Return values: `TRUE = fires`, `FALSE = passes`, `NA = advisory`.
- Always vectorised to `nrow(data)`. No scalar early exits.
- Return `NA` on missing inputs; let the engine route those into the
  advisory / skipped channels.
- Argument names (`column`, etc.) are exactly what the rule YAML passes
  via the operator’s `arg_schema`.

### Cross-dataset operators

Some rules need a second dataset (e.g. “every USUBJID in AE must exist
in DM”). Resolve the reference through the run context:

``` r
op_subject_in_dm <- function(data, ctx, ...) {
  ref <- .ref_ds(ctx, "DM")     # internal helper, returns NULL if missing
  if (is.null(ref)) {
    return(rep(NA, nrow(data))) # engine logs missing ref + skips rule
  }
  !(data$USUBJID %in% ref$USUBJID)
}
```

If the reference dataset is absent, herald automatically records the
miss to `ctx$missing_refs$datasets`. The user sees it in
`result$skipped_refs` with a hint to provide the dataset.

### Registration metadata

Each operator declares metadata used by the engine and by tooling:

| Field           | Meaning                                                                                |
|-----------------|----------------------------------------------------------------------------------------|
| `kind`          | `"set"`, `"compare"`, `"existence"`, `"temporal"`, `"cross"`, `"string"`, or `"spec"`. |
| `summary`       | One-line description shown by tooling.                                                 |
| `arg_schema`    | Type and required-ness of every named argument.                                        |
| `cost_hint`     | `"O(n)"`, `"O(n log n)"`, or `"O(n*m)"`.                                               |
| `column_arg`    | Which arg names the column being scanned (e.g. `"column"`).                            |
| `returns_na_ok` | `TRUE` if `NA` is a meaningful (advisory) return.                                      |

The engine uses `kind` for grouping in summaries and for cost-based
scheduling. `arg_schema` types are one of `"string"`, `"integer"`,
`"boolean"`, `"array"`, `"object"`, or `"any"`.

### Where to put the file

Place new operators in `R/ops-<topic>.R`, one logical group per file
(e.g. `R/ops-string.R`, `R/ops-temporal.R`). Register at the bottom of
the file so the operator is discoverable at package load.

## Where to go next

- `cookbook` – ready-to-run recipes against the bundled pilot data.
- `architecture` (vignette) – the layer stack from I/O to reports.
- `rule-coverage` (vignette) – how the rule corpus is organised.
