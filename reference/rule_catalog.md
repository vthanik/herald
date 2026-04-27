# Compiled rule catalog

**\[experimental\]**

Returns every rule shipped with herald as a flat tibble. The catalog is
the union of two compiled corpora:

- `inst/rules/rules.rds` – CDISC conformance rules (SDTM-IG, ADaM-IG,
  SEND-IG, Define-XML).

- `inst/rules/spec_rules.rds` – herald-authored spec pre-flight checks
  that run against a `herald_spec` before validation.

Use this to discover available rules, inspect predicate coverage, or
build a `rules =` filter for
[`validate()`](https://vthanik.github.io/herald/reference/validate.md).

## Usage

``` r
rule_catalog()
```

## Value

A tibble with columns:

- rule_id:

  Rule identifier (e.g. `"CG0006"`, `"1"`, `"define_version_is_2_1"`).

- standard:

  CDISC standard family (`"SDTM-IG"`, `"ADaM-IG"`, `"Define-XML"`,
  `"SEND-IG"`, `"herald-spec"`).

- authority:

  Rule authority (`"CDISC"`, `"FDA"`, `"HERALD"`).

- severity:

  Finding severity (`"Error"`, `"Warning"`, `"Medium"`, etc.).

- message:

  Short finding message / error code.

- source_document:

  Upstream source (e.g. `"CDISC ADaM Conformance Rules v5.0"`).

- has_predicate:

  `TRUE` when an executable check-tree is compiled for this rule;
  `FALSE` for rules that are authored as narrative stubs awaiting
  predicate implementation.

## See also

[`validate()`](https://vthanik.github.io/herald/reference/validate.md),
[`supported_standards()`](https://vthanik.github.io/herald/reference/supported_standards.md)

Other validate:
[`supported_standards()`](https://vthanik.github.io/herald/reference/supported_standards.md),
[`validate()`](https://vthanik.github.io/herald/reference/validate.md)

## Examples

``` r
cat <- rule_catalog()
nrow(cat)                                       # total rules
#> [1] 1865

# Rules with an executable predicate
sum(cat$has_predicate)
#> [1] 1861

# Filter by standard
cat[cat$standard == "ADaM-IG", ]
#> # A tibble: 790 × 7
#>    rule_id standard authority severity message          source_document
#>    <chr>   <chr>    <chr>     <chr>    <chr>            <chr>          
#>  1 1       ADaM-IG  CDISC     Medium   ADSL dataset do… CDISC ADaM Con…
#>  2 10      ADaM-IG  CDISC     Medium   A variable with… CDISC ADaM Con…
#>  3 102     ADaM-IG  CDISC     Medium   For every uniqu… CDISC ADaM Con…
#>  4 103     ADaM-IG  CDISC     Medium   For every uniqu… CDISC ADaM Con…
#>  5 104     ADaM-IG  CDISC     Medium   For every uniqu… CDISC ADaM Con…
#>  6 105     ADaM-IG  CDISC     Medium   There is more t… CDISC ADaM Con…
#>  7 106     ADaM-IG  CDISC     Medium   There is more t… CDISC ADaM Con…
#>  8 109     ADaM-IG  CDISC     Medium   Within a given … CDISC ADaM Con…
#>  9 11      ADaM-IG  CDISC     Medium   A variable with… CDISC ADaM Con…
#> 10 110     ADaM-IG  CDISC     Medium   Within a given … CDISC ADaM Con…
#> # ℹ 780 more rows
#> # ℹ 1 more variable: has_predicate <lgl>
cat[cat$standard == "SDTM-IG", ]
#> # A tibble: 740 × 7
#>    rule_id standard authority severity message          source_document
#>    <chr>   <chr>    <chr>     <chr>    <chr>            <chr>          
#>  1 CG0001  SDTM-IG  CDISC     Medium   DOMAIN = valid … CDISC SDTM and…
#>  2 CG0002  SDTM-IG  CDISC     Medium   --DUR collected… CDISC SDTM and…
#>  3 CG0006  SDTM-IG  CDISC     Medium   --DY calculated… CDISC SDTM and…
#>  4 CG0007  SDTM-IG  CDISC     Medium   --DY = null      CDISC SDTM and…
#>  5 CG0008  SDTM-IG  CDISC     Medium   --ELTM = null    CDISC SDTM and…
#>  6 CG0009  SDTM-IG  CDISC     Medium   EPOCH in TA.EPO… CDISC SDTM and…
#>  7 CG0010  SDTM-IG  CDISC     Medium   Metadata attrib… CDISC SDTM and…
#>  8 CG0011  SDTM-IG  CDISC     Medium   Variable Format… CDISC SDTM and…
#>  9 CG0012  SDTM-IG  CDISC     Medium   Variable Type =… CDISC SDTM and…
#> 10 CG0013  SDTM-IG  CDISC     Medium   Variable = Mode… CDISC SDTM and…
#> # ℹ 730 more rows
#> # ℹ 1 more variable: has_predicate <lgl>

# Narrative stubs awaiting implementation
cat[!cat$has_predicate, c("rule_id", "standard", "message")]
#> # A tibble: 4 × 3
#>   rule_id                                     standard    message      
#>   <chr>                                       <chr>       <chr>        
#> 1 define_attribute_length_le_1000             Define-XML  ATTRIBUTE_LE…
#> 2 define_arm_parameter_oid_references_paramcd herald-spec ARM_PARAMETE…
#> 3 define_arm_parameter_oid_required_bds       herald-spec ARM_PARAMETE…
#> 4 define_paired_terms_same_c_code             herald-spec PAIRED_TERMS…

# Rules by severity
table(cat$severity)
#> 
#>   High    Low Medium 
#>    120      2   1743 

# Find a rule by ID
cat[cat$rule_id == "CG0006", ]
#> # A tibble: 1 × 7
#>   rule_id standard authority severity message           source_document
#>   <chr>   <chr>    <chr>     <chr>    <chr>             <chr>          
#> 1 CG0006  SDTM-IG  CDISC     Medium   --DY calculated … CDISC SDTM and…
#> # ℹ 1 more variable: has_predicate <lgl>
```
