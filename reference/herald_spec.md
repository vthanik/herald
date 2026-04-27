# Construct a rich herald_spec with all submission slots

**\[experimental\]**

Assembles a `herald_spec` that carries all Define-XML 2.1 slots:
`ds_spec`, `var_spec`, `study`, `value_spec`, `codelist`, `methods`,
`comments`, `documents`, `arm_displays`, and `arm_results`. Use this
constructor when you need round-trip fidelity through
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md);
reach for the simpler
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md)
when only datasets and variables matter.

## Usage

``` r
herald_spec(
  ds_spec,
  var_spec = data.frame(dataset = character(), variable = character(), stringsAsFactors =
    FALSE),
  study = data.frame(attribute = character(), value = character(), stringsAsFactors =
    FALSE),
  value_spec = NULL,
  codelist = NULL,
  methods = NULL,
  comments = NULL,
  documents = NULL,
  arm_displays = NULL,
  arm_results = NULL
)
```

## Arguments

- ds_spec:

  Data frame with column `dataset`.

- var_spec:

  Data frame with columns `dataset` and `variable`.

- study:

  Optional data.frame with columns `attribute` and `value` (rows:
  StudyName, StudyDescription, ProtocolName).

- value_spec:

  Optional data.frame for value-level metadata.

- codelist:

  Optional data.frame with codelist rows.

- methods:

  Optional data.frame with method definitions.

- comments:

  Optional data.frame with comment definitions.

- documents:

  Optional data.frame with document leaf definitions.

- arm_displays:

  Optional data.frame with ARM display definitions.

- arm_results:

  Optional data.frame with ARM result definitions.

## Value

A list with class `c("herald_spec", "list")`.

## Input dispatch

Each slot accepts a data frame in the layout produced by the matching
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md)
field, so a Define-XML round-trip is just:

    d <- read_define_xml("define.xml")
    s <- herald_spec(
      ds_spec      = d$ds_spec,      var_spec     = d$var_spec,
      study        = d$study,        codelist     = d$codelist,
      methods      = d$methods,      comments     = d$comments,
      documents    = d$documents,    arm_displays = d$arm_displays,
      arm_results  = d$arm_results
    )

Slots not supplied default to either an empty data frame (`var_spec`,
`study`) or `NULL` (everything else).
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md)
emits an element only when the corresponding slot is non-empty.

## See also

[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md)
for the simpler two-arg constructor.

Other spec:
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md),
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md),
[`is_herald_spec()`](https://vthanik.github.io/herald/reference/is_herald_spec.md),
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md),
[`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md),
[`write_define_html()`](https://vthanik.github.io/herald/reference/write_define_html.md),
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md)

## Examples

``` r
dm   <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
adsl <- readRDS(system.file("extdata", "adsl.rds", package = "herald"))

# ---- Minimal: ds_spec only (var_spec defaults to empty data frame) ----
s1 <- herald_spec(
  ds_spec = data.frame(dataset = "DM", label = "Demographics",
                       stringsAsFactors = FALSE)
)
is_herald_spec(s1)
#> [1] TRUE
nrow(s1$var_spec)   # 0 -- empty but present
#> [1] 0

# ---- With ds_spec and var_spec ---------------------------------------
s2 <- herald_spec(
  ds_spec  = data.frame(dataset = "DM", label = "Demographics",
                        stringsAsFactors = FALSE),
  var_spec = data.frame(dataset = "DM", variable = names(dm),
                        stringsAsFactors = FALSE)
)
nrow(s2$var_spec)
#> [1] 25

# ---- With study metadata slot (used by write_define_xml) -------------
s3 <- herald_spec(
  ds_spec = data.frame(dataset = "ADSL", stringsAsFactors = FALSE),
  study   = data.frame(
    attribute = c("StudyName", "ProtocolName"),
    value     = c("PILOT01", "PROTOCOL-A"),
    stringsAsFactors = FALSE
  )
)
s3$study
#>      attribute      value
#> 1    StudyName    PILOT01
#> 2 ProtocolName PROTOCOL-A

# ---- Rich spec with codelist slot ------------------------------------
s4 <- herald_spec(
  ds_spec  = data.frame(dataset = "DM", stringsAsFactors = FALSE),
  var_spec = data.frame(dataset = "DM", variable = names(dm),
                        stringsAsFactors = FALSE),
  codelist = data.frame(
    codelist_id = "CL.SEX",
    codelist_label = "Sex",
    value = c("M", "F"),
    decoded_value = c("Male", "Female"),
    stringsAsFactors = FALSE
  )
)
nrow(s4$codelist)
#> [1] 2
```
