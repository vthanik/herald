# Tests for Q33: missing-reference-data semantics integration.

test_that(".ref_ds records a missing_ref when the dataset is absent", {
  ctx <- new.env()
  ctx$datasets <- list(DM = data.frame(USUBJID = "S1"))
  herald:::.init_missing_refs(ctx)
  ctx$current_rule_id <- "CG0069"

  # Resolvable -> no missing ref.
  hit <- herald:::.ref_ds(ctx, "DM")
  expect_equal(nrow(hit), 1L)
  expect_length(ctx$missing_refs$datasets, 0L)

  # Unresolvable -> missing-ref recorded.
  miss <- herald:::.ref_ds(ctx, "AE")
  expect_null(miss)
  expect_true("AE" %in% names(ctx$missing_refs$datasets))
  expect_equal(ctx$missing_refs$datasets$AE, "CG0069")
})

test_that("validate() surfaces missing datasets in result$skipped_refs", {
  # ADaM-581 (treatment_var_absent_across_datasets) is scoped to BDS and
  # references ADSL. Running it against a BDS-classed dataset without
  # ADSL in the submission must record ADSL as a missing ref.
  devtools::load_all(".", quiet = TRUE)

  bds <- data.frame(USUBJID = "S1", AEDECOD = "X",
                    stringsAsFactors = FALSE)
  spec <- as_herald_spec(
    ds_spec = data.frame(
      dataset = "ADAE",
      class   = "BASIC DATA STRUCTURE",
      stringsAsFactors = FALSE
    )
  )
  r <- validate(files = list(ADAE = bds), spec = spec,
                rules = "581", quiet = TRUE)

  expect_s3_class(r, "herald_result")
  expect_true("skipped_refs" %in% names(r))
  expect_true("ADSL" %in% names(r$skipped_refs$datasets))
  expect_match(r$skipped_refs$datasets$ADSL$hint,
               "Provide dataset ADSL")
  expect_true("581" %in% r$skipped_refs$datasets$ADSL$rule_ids)
})

test_that(".html_skipped_refs emits empty string when nothing is missing", {
  out <- herald:::.html_skipped_refs(
    list(datasets = list(), dictionaries = list())
  )
  expect_equal(out, "")
})

test_that(".html_skipped_refs renders both kinds with rule lists", {
  sk <- list(
    datasets = list(
      DM = list(kind = "dataset",
                rule_ids = c("CG0069", "ADaM-204"),
                hint = "Provide dataset DM to evaluate these rules.")
    ),
    dictionaries = list(
      srs = list(kind = "dictionary",
                 rule_ids = c("CG0442", "CG0443"),
                 hint = "Run `herald::download_srs()` to populate the cache.")
    )
  )
  out <- herald:::.html_skipped_refs(sk)
  expect_match(out, "Missing reference data")
  expect_match(out, "Dataset: DM")
  expect_match(out, "Dictionary: srs")
  expect_match(out, "CG0069")
  expect_match(out, "CG0443")
  expect_match(out, "download_srs")
})

test_that("write_report_html() includes the skipped_refs banner + header cell", {
  skip_if_not(requireNamespace("herald", quietly = TRUE))
  devtools::load_all(".", quiet = TRUE)

  # Synthesise a herald_result with populated skipped_refs.
  empty_findings <- herald:::empty_findings()
  r <- new_herald_result(
    findings         = empty_findings,
    rules_applied    = 0L,
    rules_total      = 2L,
    datasets_checked = c("ADSL"),
    duration         = as.difftime(0.1, units = "secs"),
    dataset_meta     = list(
      ADSL = list(rows = 1L, cols = 1L, label = "Subject-Level",
                  class = "ADSL")
    ),
    skipped_refs = list(
      datasets = list(
        DM = list(kind = "dataset", rule_ids = "ADaM-204",
                  hint = "Provide dataset DM to evaluate these rules.")
      ),
      dictionaries = list(
        srs = list(kind = "dictionary", rule_ids = c("CG0442"),
                   hint = "Run `herald::download_srs()` to populate the cache.")
      )
    )
  )

  path <- tempfile(fileext = ".html")
  on.exit(unlink(path), add = TRUE)
  write_report_html(r, path, title = "test")

  html <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(html, "Missing reference data")
  expect_match(html, "Skipped \\(ref data\\)")   # header cell
  expect_match(html, "Dataset: DM")
  expect_match(html, "Dictionary: srs")
})
