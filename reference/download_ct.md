# Download + cache a CDISC CT release from NCI EVS

Fetches the tab-delimited release from NCI EVS, parses it into the
herald CT schema (a named list of codelists keyed by submission short
name), writes the result to `<dest>/<package>-ct-<version>.rds`, and
updates the cache manifest. Idempotent: returns the existing path if the
file already exists and `!force`.

## Usage

``` r
download_ct(
  package = c("sdtm", "adam", "send"),
  version = "latest",
  dest = .ct_cache_dir(),
  force = FALSE,
  timeout = 120L,
  quiet = FALSE
)
```

## Arguments

- package:

  One of `"sdtm"`, `"adam"`, `"send"`.

- version:

  Release identifier. Either `"latest"` or a `YYYY-MM-DD` date matching
  an NCI EVS archive entry.

- dest:

  Target directory. Defaults to the user CT cache
  (`tools::R_user_dir("herald","cache")`). Maintainers pass
  `"inst/rules/ct"` to refresh the bundled files.

- force:

  Re-download even when the target file exists.

- timeout:

  Seconds for
  [`utils::download.file()`](https://rdrr.io/r/utils/download.file.html).
  Default 120.

- quiet:

  Suppress progress output.

## Value

The path to the generated RDS, invisibly.

## See also

Other ct:
[`available_ct_releases()`](https://vthanik.github.io/herald/reference/available_ct_releases.md),
[`ct_info()`](https://vthanik.github.io/herald/reference/ct_info.md),
[`download_srs()`](https://vthanik.github.io/herald/reference/download_srs.md),
[`load_ct()`](https://vthanik.github.io/herald/reference/load_ct.md)

## Examples

``` r
# Download the latest SDTM CT (requires internet)
if (interactive()) {
  dest <- tempdir()
  download_ct("sdtm", version = "latest", dest = dest)

  # ADaM CT -- same pattern
  download_ct("adam", version = "latest", dest = dest)

  # Pin a specific quarterly release
  download_ct("sdtm", version = "2024-09-27", dest = dest)

  # Re-download even when already cached
  download_ct("sdtm", version = "latest", dest = dest, force = TRUE)

  # Suppress progress output (useful in scripts)
  download_ct("sdtm", version = "latest", dest = dest, quiet = TRUE)
}
```
