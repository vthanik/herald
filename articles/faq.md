# Frequently Asked Questions

Short answers to the questions new users ask most often. Each entry
shows the smallest runnable code that resolves the issue.

## Why does my `validate()` return 0 rules?

Three common causes:

1.  **Empty rule filter.** `rules = character(0)` is a deliberate
    smoke-test mode that exercises the result object without running
    anything. Drop the argument to run the full corpus.

2.  **Filter excludes every rule.** Combining `standards =`,
    `authorities =`, and `rules =` ANDs the conditions. Inspect with
    [`rule_catalog()`](https://vthanik.github.io/herald/reference/rule_catalog.md)
    first.

3.  **Datasets do not match any rule scope.** Some rules are
    dataset-scoped (e.g. AE-only rules). If you only pass DM, AE-only
    rules are silently out of scope.

``` r
# Smoke-test mode: rules_total = 0 by design
r <- validate(files = dm, rules = character(0), quiet = TRUE)
r$rules_total
#> [1] 0

# Run the full corpus
r <- validate(files = list(DM = apply_spec(dm, sdtm_spec)), quiet = TRUE)
r$rules_total
#> [1] 1762
```

## How do I run only SDTM rules?

Use `standards = "SDTM-IG"`. Any combination of standards is allowed.

``` r
r <- validate(
  files = list(DM = apply_spec(dm, sdtm_spec)),
  standards = "SDTM-IG",
  quiet = TRUE
)
r$rules_total
#> [1] 740
```

The available standard names are:

``` r
supported_standards()$standard
#> [1] "ADaM-IG"     "Define-XML"  "Define-XML"  "herald-spec"
#> [5] "SDTM-IG"     "SDTM-IG"     "SEND-IG"
```

## How do I add MedDRA?

Build a provider with
[`meddra_provider()`](https://vthanik.github.io/herald/reference/meddra_provider.md),
register it, then run. The provider expects a directory of MedDRA ASCII
files (`mdhier.asc`, `llt.asc`, etc.) and a version string for
reproducibility.

``` r
meddra <- meddra_provider("dictionaries/meddra", version = "27.0")
register_dictionary("meddra", meddra)

result <- validate(path = "data/adam", quiet = TRUE)
```

If MedDRA is not registered when a rule needs it, the rule is skipped
and `result$skipped_refs$dictionaries$meddra` will explain how to wire
it up.

## Why is my Define-XML rejected?

[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md)
validates against the Define-XML 2.1 schema and the herald conformance
ruleset. Common rejections:

- **Missing namespace declaration** on the root element.
- **OID collisions** – e.g. two `MetaDataVersion/ItemDef` items sharing
  the same `OID`.
- **Codelist references that point to nothing** – a variable cites
  `CL.SEX` but no `<CodeList OID="CL.SEX">` block exists.

Run
[`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md)
directly on the parsed object to see every finding before it derails
downstream code:

``` r
d <- read_define_xml("metadata/define.xml")
findings <- validate_spec(d)
findings[findings$severity == "High", ]
```

## Why are my AE / VS rules being skipped?

Cross-dataset rules need their reference datasets present in the same
[`validate()`](https://vthanik.github.io/herald/reference/validate.md)
call. If you pass only `AE`, any rule that needs `DM` is recorded in
`result$skipped_refs$datasets`.

``` r
r <- validate(
  files = list(AE = adae),
  standards = "SDTM-IG",
  quiet = TRUE
)
str(r$skipped_refs$datasets, max.level = 1)
#> List of 2
#>  $ SUPPAE:List of 3
#>  $ DM    :List of 3
```

Provide every related domain together:

``` r
r <- validate(
  files = list(
    DM = apply_spec(dm,  sdtm_spec),
    AE = adae
  ),
  standards = "SDTM-IG",
  quiet = TRUE
)
r$datasets_checked
#> [1] "DM" "AE"
```

## How do I keep severities under control across runs?

Use `severity_map=` to rewrite labels at run time, and store the mapping
in your project config (not in the rule catalog).

``` r
sponsor_policy <- c("Medium" = "High")

r <- validate(
  files = list(DM = apply_spec(dm, sdtm_spec)),
  standards = "SDTM-IG",
  severity_map = sponsor_policy,
  quiet = TRUE
)
table(r$findings$severity)
#> 
#> High 
#>  242
```

## Can I read SAS XPT without `haven` / SAS?

Yes.
[`read_xpt()`](https://vthanik.github.io/herald/reference/read_xpt.md)
is pure R and supports XPT v5. It preserves labels, lengths, and SAS
types.

``` r
out <- file.path(tempdir(), "herald-faq")
dir.create(out, showWarnings = FALSE)

write_xpt(apply_spec(dm, sdtm_spec), file.path(out, "dm.xpt"))
dm2 <- read_xpt(file.path(out, "dm.xpt"))

attr(dm2, "label")
#> [1] "Demographics"
attr(dm2$USUBJID, "label")
#> [1] "Unique Subject Identifier"
attr(dm2$USUBJID, "sas.length")
#> [1] 11
```

## Can I write a Define-XML from scratch?

Build a `herald_spec` (use
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md)
for full control) and write it. Round-tripping a parsed Define-XML
through
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md)
is also supported and preserves codelists, methods, comments, and ARM
metadata.

``` r
spec <- herald_spec(
  ds_spec  = ds_spec_df,
  var_spec = var_spec_df
)
write_define_xml(spec, "metadata/define.xml")
```

## How do I do XPT -\> Dataset-JSON -\> Parquet conversion?

[`convert_dataset()`](https://vthanik.github.io/herald/reference/convert_dataset.md)
infers source and target formats from the file extensions. Parquet
support requires the optional `arrow` package.

``` r
out <- file.path(tempdir(), "herald-faq-convert")
dir.create(out, showWarnings = FALSE)

write_xpt(apply_spec(dm, sdtm_spec), file.path(out, "dm.xpt"))
convert_dataset(file.path(out, "dm.xpt"), file.path(out, "dm.json"))
file.exists(file.path(out, "dm.json"))
#> [1] TRUE
```

## How do I tell which rule fired on which row?

Inspect the `findings` table on the result. Each row of `findings`
points at the originating rule and dataset.

``` r
r <- validate(path = "data/sdtm", quiet = TRUE)
head(r$findings[, c("rule_id", "dataset", "severity", "status")])
```

## How do I run herald in CI?

Any CI that runs `Rscript` can run herald. A minimal GitHub Actions step
looks like:

``` yaml
- uses: r-lib/actions/setup-r@v2
- run: Rscript -e 'install.packages("pak"); pak::pak("vthanik/herald")'
- run: Rscript -e 'herald::validate(path="data/sdtm") |>
                   herald::report("qc/report.html")'
```

Use the `is_blocking()` helper from the *Cookbook* article to fail the
job on high-impact fired findings while still uploading the reports as
artifacts.

## How does herald differ from Pinnacle 21?

See the dedicated `migrating-from-p21` article for a full mapping. The
short version:

- Same rule sources (SDTM-IG, ADaM-IG, Define-XML 2.1, CORE).
- Pure R, no JVM. Installs from CRAN-style sources.
- Reports in HTML, XLSX, and JSON from the same result object.
- Dictionary and rule configuration live in code, not in a GUI.

## Where do I report bugs?

Open an issue at <https://github.com/vthanik/herald/issues> with a
minimal reproducible example. The pilot datasets bundled with the
package (`dm`, `adsl`, `adae`, `advs`) are a good starting point.

## Where to go next

- `cookbook` – ready-to-run recipes against the bundled pilot data.
- `extending-herald` – write your own dictionary or operator.
- `migrating-from-p21` – side-by-side mapping from Pinnacle 21.
