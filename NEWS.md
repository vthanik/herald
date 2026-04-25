# herald 0.1.0 (development)

Initial clean-slate rewrite. See plan at `.local/plan.md`.

- Added a current-API documentation set: expanded README, pkgdown reference
  structure, and vignettes for getting started, validation/reporting, data I/O,
  Define-XML, dictionary providers, best practices, and architecture.
- `convert_dataset()` replaces the six directional converters (`xpt_to_json()`, `json_to_xpt()`, `xpt_to_parquet()`, `parquet_to_xpt()`, `json_to_parquet()`, `parquet_to_json()`). Formats are inferred from file extensions; pass `from =` / `to =` to override.
- All `@examples` now use `pharmaversesdtm` and `pharmaverseadam` pilot datasets instead of hand-crafted toy data frames.
- Pure-R, CRAN-clean, no JVM.
- SDTM + ADaM + Define-XML 2.1.
- CDISC Library API harvested rules + controlled terminology.
- Define-XML full roundtrip (read / mutate / write with semantic preservation).
- Submission-ready HTML / XLSX / JSON reports.
