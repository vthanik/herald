# herald 0.1.0 (development)

Initial clean-slate rewrite. See plan at `.local/plan.md`.

- `json_to_parquet()`, `parquet_to_json()`, `parquet_to_xpt()`, and `xpt_to_parquet()` complete the three-way XPT/JSON/Parquet conversion matrix alongside the existing `xpt_to_json()` / `json_to_xpt()` pair.
- All `@examples` now use `pharmaversesdtm` and `pharmaverseadam` pilot datasets instead of hand-crafted toy data frames.
- Pure-R, CRAN-clean, no JVM.
- SDTM + ADaM + Define-XML 2.1.
- CDISC Library API harvested rules + controlled terminology.
- Define-XML full roundtrip (read / mutate / write with semantic preservation).
- Submission-ready HTML / XLSX / JSON reports.
