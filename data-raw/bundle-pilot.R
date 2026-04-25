# data-raw/bundle-pilot.R
# Subset CDISC Pilot 03 to 50 subjects, strip attributes, and bundle as .rds.
# Also builds SDTM and ADaM herald_spec objects from the pilot define.xml files.
# Run from the package root: Rscript data-raw/bundle-pilot.R

devtools::load_all(quiet = TRUE)

src <- "/Users/vignesh/projects/data/phuse-scripts"
out <- "inst/extdata"

dm   <- haven::read_xpt(file.path(src, "sdtm", "dm.xpt"))
adsl <- haven::read_xpt(file.path(src, "adam", "adsl.xpt"))
advs <- haven::read_xpt(file.path(src, "adam", "advs.xpt"))
adae <- haven::read_xpt(file.path(src, "adam", "adae.xpt"))

set.seed(42)
keep <- sample(unique(adsl$USUBJID), 50)

zap <- function(df) {
  df <- df[df$USUBJID %in% keep, , drop = FALSE]
  df <- as.data.frame(lapply(df, function(col) {
    attributes(col) <- NULL
    col
  }), stringsAsFactors = FALSE)
  rownames(df) <- NULL
  df
}

saveRDS(zap(dm),   file.path(out, "dm.rds"),   compress = "xz")
saveRDS(zap(adsl), file.path(out, "adsl.rds"), compress = "xz")
saveRDS(zap(advs), file.path(out, "advs.rds"), compress = "xz")
saveRDS(zap(adae), file.path(out, "adae.rds"), compress = "xz")

sizes <- vapply(
  c("dm.rds", "adsl.rds", "advs.rds", "adae.rds"),
  function(f) file.info(file.path(out, f))$size,
  numeric(1)
)
cat(sprintf("Data sizes (bytes): %s\n",
            paste(names(sizes), formatC(sizes, big.mark = ","), sep = "=", collapse = "  ")))
stopifnot("ADVS exceeds 200 KB -- trim columns" = all(sizes <= 200 * 1024))

# Build specs from define.xml
sdtm_def <- read_define_xml(file.path(src, "sdtm", "define.xml"))
adam_def <- read_define_xml(file.path(src, "adam", "define.xml"))

sdtm_spec <- as_herald_spec(sdtm_def$ds_spec, sdtm_def$var_spec)
adam_spec <- as_herald_spec(adam_def$ds_spec, adam_def$var_spec)

saveRDS(sdtm_spec, file.path(out, "sdtm-spec.rds"), compress = "xz")
saveRDS(adam_spec, file.path(out, "adam-spec.rds"), compress = "xz")

spec_sizes <- vapply(
  c("sdtm-spec.rds", "adam-spec.rds"),
  function(f) file.info(file.path(out, f))$size,
  numeric(1)
)
cat(sprintf("Spec sizes (bytes): %s\n",
            paste(names(spec_sizes), formatC(spec_sizes, big.mark = ","), sep = "=", collapse = "  ")))

cat("Done.\n")
