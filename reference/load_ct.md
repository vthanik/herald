# Load bundled or cached CDISC Controlled Terminology

Returns a named list of codelists – one entry per CDISC codelist, keyed
by its submission-short-name (e.g. `"NY"`, `"ACCPARTY"`). Each entry is
a list with `codelist_code`, `codelist_name`, `extensible`, and a
`terms` data frame holding submission values, NCI concept ids, and
preferred terms.

## Usage

``` r
load_ct(package = c("sdtm", "adam"), version = "bundled")
```

## Arguments

- package:

  Character scalar, one of `"sdtm"`, `"adam"`. Defaults to `"sdtm"`.

- version:

  Which release to load. One of:

  - `"bundled"` (default) – the RDS under `inst/rules/ct/` shipped with
    the installed herald.

  - `"latest-cache"` – newest entry for `package` in the user CT cache
    (`tools::R_user_dir("herald","cache")`).

  - `"YYYY-MM-DD"` – a specific release already downloaded into the
    cache.

  - an absolute `.rds` path – loaded as-is.

## Value

Named list with the schema above. Carries attributes `package`,
`version`, `release_date`, `source_url`, `source_path`.

## See also

[`available_ct_releases()`](https://vthanik.github.io/herald/reference/available_ct_releases.md),
[`download_ct()`](https://vthanik.github.io/herald/reference/download_ct.md),
[`ct_info()`](https://vthanik.github.io/herald/reference/ct_info.md).

Other ct:
[`available_ct_releases()`](https://vthanik.github.io/herald/reference/available_ct_releases.md),
[`ct_info()`](https://vthanik.github.io/herald/reference/ct_info.md),
[`download_ct()`](https://vthanik.github.io/herald/reference/download_ct.md),
[`download_srs()`](https://vthanik.github.io/herald/reference/download_srs.md)

## Examples

``` r
# Bundled SDTM CT (no network; always available)
ct <- load_ct("sdtm")
length(ct)                  # number of codelists
#> [1] 1215
names(ct)[1:5]              # first 5 codelist short names
#> [1] "TENMW1TC" "TENMW1TN" "A4STR1TC" "A4STR1TN" "D4STR1TC"
ct[["NY"]]$codelist_name   # "No Yes Response"
#> [1] "No Yes Response"
ct[["NY"]]$terms            # data frame of submission values
#>   submissionValue conceptId  preferredTerm
#> 1               N    C49487             No
#> 2              NA    C48660 Not Applicable
#> 3               U    C17998        Unknown
#> 4               Y    C49488            Yes
attr(ct, "version")
#> [1] "2026-03-27"
attr(ct, "release_date")
#> [1] "2026-03-27"

# ADaM CT
ct_adam <- load_ct("adam")
names(ct_adam)[1:5]
#> [1] "CHSFPC"  "CHSFPN"  "DATEFL"  "DTYPE"   "GAD02PC"

# Pinned version from user cache (requires prior download_ct() call)
if (interactive()) {
  ct_pinned <- load_ct("sdtm", version = "2024-09-27")
  attr(ct_pinned, "version")

  # Newest cached version
  ct_latest <- load_ct("sdtm", version = "latest-cache")
}
```
