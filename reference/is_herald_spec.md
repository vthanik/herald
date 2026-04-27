# Is `x` a `herald_spec`?

Is `x` a `herald_spec`?

## Usage

``` r
is_herald_spec(x)
```

## Arguments

- x:

  Any object.

## Value

`TRUE` if `x` inherits from `herald_spec`, else `FALSE`.

## See also

Other spec:
[`apply_spec()`](https://vthanik.github.io/herald/reference/apply_spec.md),
[`as_herald_spec()`](https://vthanik.github.io/herald/reference/as_herald_spec.md),
[`herald_spec()`](https://vthanik.github.io/herald/reference/herald_spec.md),
[`read_define_xml()`](https://vthanik.github.io/herald/reference/read_define_xml.md),
[`validate_spec()`](https://vthanik.github.io/herald/reference/validate_spec.md),
[`write_define_html()`](https://vthanik.github.io/herald/reference/write_define_html.md),
[`write_define_xml()`](https://vthanik.github.io/herald/reference/write_define_xml.md)

## Examples

``` r
dm <- readRDS(system.file("extdata", "dm.rds", package = "herald"))
spec <- as_herald_spec(
  ds_spec  = data.frame(dataset = "DM", stringsAsFactors = FALSE),
  var_spec = data.frame(dataset = "DM", variable = names(dm),
                        stringsAsFactors = FALSE)
)

# ---- Valid herald_spec -- returns TRUE -------------------------------
is_herald_spec(spec)
#> [1] TRUE

# ---- Plain list -- returns FALSE -------------------------------------
is_herald_spec(list(ds_spec = data.frame()))
#> [1] FALSE

# ---- NULL, data.frame, or character -- all FALSE ---------------------
is_herald_spec(NULL)
#> [1] FALSE
is_herald_spec(data.frame())
#> [1] FALSE
is_herald_spec("DM")
#> [1] FALSE
```
