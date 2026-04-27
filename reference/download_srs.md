# Download + cache the FDA SRS / UNII table

Fetches the FDA's public bulk download, parses the tab-delimited body
inside the ZIP into a tidy tibble, writes it to the user cache as an
RDS, and updates the cache manifest. Idempotent – re-runs short-circuit
when the file is already cached.

## Usage

``` r
download_srs(
  version = format(Sys.Date(), "%Y-%m-%d"),
  dest = .ct_cache_dir(),
  force = FALSE,
  timeout = 180L,
  quiet = FALSE
)
```

## Arguments

- version:

  Release tag for the cache path. Defaults to today's ISO date
  (`format(Sys.Date(), "%Y-%m-%d")`), since the FDA does not expose a
  version in the filename.

- dest:

  Target directory. Defaults to `tools::R_user_dir("herald", "cache")`.

- force:

  Re-download even when the RDS already exists.

- timeout:

  Seconds for
  [`utils::download.file()`](https://rdrr.io/r/utils/download.file.html).
  Default 180.

- quiet:

  Suppress progress output.

## Value

The path to the generated RDS, invisibly.

## See also

[`srs_provider()`](https://vthanik.github.io/herald/reference/srs_provider.md),
[`download_ct()`](https://vthanik.github.io/herald/reference/download_ct.md).

Other ct:
[`available_ct_releases()`](https://vthanik.github.io/herald/reference/available_ct_releases.md),
[`ct_info()`](https://vthanik.github.io/herald/reference/ct_info.md),
[`download_ct()`](https://vthanik.github.io/herald/reference/download_ct.md),
[`load_ct()`](https://vthanik.github.io/herald/reference/load_ct.md)

## Examples

``` r
# Download the FDA SRS table (requires internet)
if (interactive()) {
  # Default: cache under tools::R_user_dir("herald", "cache")
  download_srs()

  # Download to a specific directory
  download_srs(dest = tempdir())

  # Tag with an explicit version (useful for reproducibility)
  download_srs(version = "2026-04-01", dest = tempdir())

  # Re-download even when cached
  download_srs(force = TRUE, quiet = TRUE)
}
```
