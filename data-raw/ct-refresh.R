# =============================================================================
# data-raw/ct-refresh.R -- MAINTAINER SCRIPT
# =============================================================================
# Refresh the bundled CDISC Controlled Terminology RDS files with the
# latest NCI EVS quarterly release. Not sourced at build time.
#
# Run from the project root:
#
#   Rscript data-raw/ct-refresh.R                     # latest for sdtm + adam
#   Rscript data-raw/ct-refresh.R sdtm 2025-12-19     # specific version
#
# Commits the resulting RDS + CT-MANIFEST.json, then release a patch.
# =============================================================================

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

args     <- commandArgs(trailingOnly = TRUE)
packages <- if (length(args) >= 1L) args[[1L]] else c("sdtm", "adam")
version  <- if (length(args) >= 2L) args[[2L]] else "latest"

dest <- file.path("inst", "rules", "ct")
dir.create(dest, recursive = TRUE, showWarnings = FALSE)

manifest <- list(
  schema_version = 2L,
  version        = format(Sys.Date(), "%Y-%m-%d"),
  source         = "NCI EVS CDISC Controlled Terminology",
  fetched        = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  packages       = list()
)

for (pkg in packages) {
  cat(sprintf("\n=== refreshing %s CT (version=%s) ===\n", pkg, version))
  rds_path <- download_ct(package = pkg,
                          version = version,
                          dest    = dest,
                          force   = TRUE,
                          quiet   = FALSE)
  ct <- readRDS(rds_path)
  n_terms     <- sum(vapply(ct, function(e) nrow(e$terms), integer(1L)))
  n_codelists <- length(ct)
  n_ext       <- sum(vapply(ct, function(e) isTRUE(e$extensible), logical(1L)))

  effective <- attr(ct, "release_date") %||% attr(ct, "version")

  # Rewrite the RDS with stable filename (without date in name) so
  # system.file() picks it up as the default bundled copy.
  stable <- file.path(dest, sprintf("%s-ct.rds", pkg))
  saveRDS(ct, stable, compress = "xz")

  manifest$packages[[pkg]] <- list(
    name        = sprintf("CDISC %s Controlled Terminology", toupper(pkg)),
    effective   = sprintf("%sct-%s", pkg, effective),
    n_codelists = n_codelists,
    n_terms     = n_terms,
    n_extensible = n_ext
  )
  cat(sprintf("  -> %s  (%d codelists, %d terms)\n",
              stable, n_codelists, n_terms))
}

manifest_path <- file.path(dest, "CT-MANIFEST.json")
jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE)
cat(sprintf("\nmanifest written: %s\n", manifest_path))

size_kb <- sum(file.info(list.files(dest, full.names = TRUE))$size) / 1024
cat(sprintf("\ntotal inst/rules/ct/ = %.1f KB (CRAN cap is 5 MB tarball)\n",
            size_kb))
