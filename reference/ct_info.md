# Summarise the currently resolvable CT.

Returns a list describing what `load_ct(package, version)` would return
without deserialising it. Pulls version + release date from the bundled
`CT-MANIFEST.json` or the user cache manifest.

## Usage

``` r
ct_info(package = c("sdtm", "adam"), version = "bundled")
```

## Arguments

- package:

  Character scalar, one of `"sdtm"`, `"adam"`.

- version:

  Same semantics as
  [`load_ct()`](https://vthanik.github.io/herald/reference/load_ct.md).

## Value

A list with `package`, `version`, `release_date`, `row_count`,
`codelist_count`, `source_path`, `source_url`.

## See also

Other ct:
[`available_ct_releases()`](https://vthanik.github.io/herald/reference/available_ct_releases.md),
[`download_ct()`](https://vthanik.github.io/herald/reference/download_ct.md),
[`download_srs()`](https://vthanik.github.io/herald/reference/download_srs.md),
[`load_ct()`](https://vthanik.github.io/herald/reference/load_ct.md)

## Examples

``` r
# SDTM CT summary
info <- ct_info("sdtm")
info$version
#> [1] "2026-03-27"
info$codelist_count
#> [1] 1215
info$row_count
#> [1] 45612
info$source_path
#> [1] "/home/runner/work/_temp/Library/herald/rules/ct/sdtm-ct.rds"

# ADaM CT summary
ct_info("adam")
#> $package
#> [1] "adam"
#> 
#> $version
#> [1] "2026-03-27"
#> 
#> $release_date
#> [1] "2026-03-27"
#> 
#> $row_count
#> [1] 144
#> 
#> $codelist_count
#> [1] 25
#> 
#> $source_path
#> [1] "/home/runner/work/_temp/Library/herald/rules/ct/adam-ct.rds"
#> 
#> $source_url
#> [1] NA
#> 
```
