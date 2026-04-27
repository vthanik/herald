# List available CDISC CT releases

Returns a tibble of CT releases visible to herald: the bundled one
shipped under `inst/rules/ct/`, plus everything in the user cache, plus
(when network is reachable) every archived quarterly release listed on
NCI EVS. Works offline – missing columns become `NA` rather than errors.

## Usage

``` r
available_ct_releases(
  package = c("sdtm", "adam", "send"),
  include_remote = TRUE,
  timeout = 30L
)
```

## Arguments

- package:

  Character scalar, one of `"sdtm"`, `"adam"`, `"send"`. Defaults to
  `"sdtm"`.

- include_remote:

  Whether to query the NCI EVS archive index for historical releases.
  Defaults to `TRUE`. Set `FALSE` to stay strictly local (bundled +
  cache).

- timeout:

  Seconds for the remote listing fetch. Default 30.

## Value

Tibble with columns

- package:

  `"sdtm"`, `"adam"`, or `"send"`.

- version:

  Release date as `YYYY-MM-DD`, or `"bundled"` for the one shipped in
  the package.

- release_date:

  Release date.

- url:

  NCI EVS source URL, or `NA` for bundled-only.

- format:

  `"txt"` (tab-delimited) – always for fetched.

- source:

  `"bundled"`, `"cache"`, or `"remote"`.

## See also

Other ct:
[`ct_info()`](https://vthanik.github.io/herald/reference/ct_info.md),
[`download_ct()`](https://vthanik.github.io/herald/reference/download_ct.md),
[`download_srs()`](https://vthanik.github.io/herald/reference/download_srs.md),
[`load_ct()`](https://vthanik.github.io/herald/reference/load_ct.md)

## Examples

``` r
# Bundled + cache only (no network)
available_ct_releases("sdtm", include_remote = FALSE)
#> # A tibble: 1 × 6
#>   package version    release_date url   format source 
#>   <chr>   <chr>      <chr>        <chr> <chr>  <chr>  
#> 1 sdtm    2026-03-27 2026-03-27   NA    rds    bundled

# ADaM CT -- local only
available_ct_releases("adam", include_remote = FALSE)
#> # A tibble: 1 × 6
#>   package version    release_date url   format source 
#>   <chr>   <chr>      <chr>        <chr> <chr>  <chr>  
#> 1 adam    2026-03-27 2026-03-27   NA    rds    bundled

# Filter to cached entries
rel <- available_ct_releases("sdtm", include_remote = FALSE)
rel[rel$source == "cache", ]
#> # A tibble: 0 × 6
#> # ℹ 6 variables: package <chr>, version <chr>, release_date <chr>,
#> #   url <chr>, format <chr>, source <chr>

# Full listing including NCI EVS archive (requires internet)
if (interactive()) {
  available_ct_releases("sdtm")
  available_ct_releases("adam")
  available_ct_releases("send")
}
```
