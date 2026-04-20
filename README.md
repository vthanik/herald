# herald

CDISC Conformance Validation for Clinical Trial Submissions.

Pure-R, CRAN-clean, R-native alternative to Java-based desktop validators.
SDTM + ADaM + Define-XML 2.1 with full roundtrip authoring.

## Status

Pre-alpha. Under active development. See `NEWS.md` for the roadmap.

## Install

```r
# (post-v1.0)
install.packages("herald")
```

## Quick start

```r
library(herald)
result <- validate("/path/to/sdtm/", spec = "spec.xlsx")
print(result)
```

## License

MIT. Rule content authored independently from CDISC Library (CC-BY-4.0) and
primary regulator documents. See `LICENSE.md` and `inst/NOTICE`.
