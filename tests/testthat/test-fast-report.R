# -----------------------------------------------------------------------------
# test-fast-report.R -- report()/write_report_* (HTML + XLSX + JSON)
# -----------------------------------------------------------------------------

mk_findings_fixture <- function() {
  tibble::tibble(
    rule_id           = c("CORE-000172", "CORE-000172", "CORE-000201"),
    authority         = rep("CDISC", 3L),
    standard          = rep("SDTM-IG", 3L),
    severity          = c("Reject", "High", "Medium"),
    status            = c("fired", "fired", "advisory"),
    dataset           = c("AE", "DM", "AE"),
    variable          = c("USUBJID", "STUDYID", NA_character_),
    row               = c(1L, 2L, NA_integer_),
    value             = c("x", "y", NA_character_),
    expected          = rep(NA_character_, 3L),
    message           = c("bad link", "bad study id", "could not decide"),
    source_url        = c("https://example/rules/172",
                          "https://example/rules/172",
                          "https://example/rules/201"),
    p21_id_equivalent = rep(NA_character_, 3L),
    license           = rep("CC-BY-4.0", 3L)
  )
}

mk_result_fixture <- function(findings = mk_findings_fixture()) {
  rule_catalog <- tibble::tibble(
    id        = c("CORE-000172", "CORE-000201", "CORE-999999"),
    authority = rep("CDISC", 3L),
    standard  = rep("SDTM-IG", 3L),
    severity  = c("Reject", "Medium", "Low"),
    message   = c("study id must match", "usubjid must be present", "x")
  )
  new_herald_result(
    findings         = findings,
    rules_applied    = 2L,
    rules_total      = 3L,
    datasets_checked = c("AE", "DM"),
    duration         = as.difftime(1.75, units = "secs"),
    profile          = NA_character_,
    config_hash      = NA_character_,
    dataset_meta     = list(
      AE = list(rows = 10L, cols = 5L, label = "Adverse Events", class = "EVENTS"),
      DM = list(rows = 3L,  cols = 6L, label = "Demographics",   class = "SPECIAL PURPOSE")
    ),
    rule_catalog     = rule_catalog,
    op_errors        = list()
  )
}

# ---- dispatcher + input validation ----------------------------------------

test_that("report() rejects non-herald_result inputs", {
  expect_error(report(list(), tempfile(fileext = ".json")), "herald_result")
})

test_that("report() rejects unknown formats", {
  r <- mk_result_fixture()
  expect_error(
    report(r, tempfile(fileext = ".pdf")),
    "Unknown report format"
  )
})

test_that("report() errors when path directory is missing", {
  r <- mk_result_fixture()
  expect_error(
    report(r, "/no/such/dir/out.json"),
    "does not exist"
  )
})

test_that("report() dispatches on extension", {
  r <- mk_result_fixture()
  p_json <- withr::local_tempfile(fileext = ".json")
  p_xlsx <- withr::local_tempfile(fileext = ".xlsx")
  p_html <- withr::local_tempfile(fileext = ".html")

  report(r, p_json)
  report(r, p_xlsx)
  report(r, p_html)
  expect_true(file.exists(p_json))
  expect_true(file.exists(p_xlsx))
  expect_true(file.exists(p_html))
})

test_that("report() accepts explicit format overriding extension", {
  r <- mk_result_fixture()
  p <- withr::local_tempfile(fileext = ".out")
  report(r, p, format = "json")
  expect_true(jsonlite::validate(paste(readLines(p), collapse = "\n")))
})

# ---- JSON writer ----------------------------------------------------------

test_that("write_report_json produces canonical keys and counts", {
  r <- mk_result_fixture()
  p <- withr::local_tempfile(fileext = ".json")
  write_report_json(r, p)
  obj <- jsonlite::read_json(p)

  expect_equal(obj$herald_version, as.character(utils::packageVersion("herald")))
  expect_equal(obj$rules_applied, 2L)
  expect_equal(obj$rules_total, 3L)
  expect_equal(unlist(obj$datasets_checked), c("AE", "DM"))
  expect_equal(obj$counts$by_status$fired,    2L)
  expect_equal(obj$counts$by_status$advisory, 1L)
  expect_equal(obj$counts$by_severity$Reject, 1L)
  expect_equal(length(obj$findings), 3L)
  expect_equal(length(obj$dataset_meta), 2L)
  expect_true(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T", obj$timestamp))
})

test_that("write_report_json handles an empty result", {
  r <- new_herald_result()
  p <- withr::local_tempfile(fileext = ".json")
  write_report_json(r, p)
  obj <- jsonlite::read_json(p)
  expect_equal(length(obj$findings), 0L)
  expect_equal(length(obj$datasets_checked), 0L)
})

# ---- XLSX writer ----------------------------------------------------------

test_that("write_report_xlsx emits the expected 5 sheets", {
  r <- mk_result_fixture()
  p <- withr::local_tempfile(fileext = ".xlsx")
  write_report_xlsx(r, p)
  expect_true(file.exists(p))

  wb <- openxlsx2::wb_load(p)
  expect_equal(unname(wb$get_sheet_names()),
               c("summary", "findings", "datasets", "rules", "spec_validation"))

  findings_back <- openxlsx2::wb_to_df(wb, sheet = "findings")
  expect_equal(nrow(findings_back), 3L)
  expect_true("rule_id" %in% names(findings_back))

  rules_back <- openxlsx2::wb_to_df(wb, sheet = "rules")
  expect_true(all(c("fired_n", "advisory_n") %in% names(rules_back)))
})

# ---- HTML writer ----------------------------------------------------------

test_that("write_report_html produces a self-contained document", {
  r <- mk_result_fixture()
  p <- withr::local_tempfile(fileext = ".html")
  write_report_html(r, p)

  html <- paste(readLines(p, warn = FALSE), collapse = "\n")

  # All placeholders resolved
  expect_false(grepl("[{][{][A-Z_]+[}][}]", html))
  # No remote assets
  expect_false(grepl("<script[^>]*\\ssrc=", html))
  expect_false(grepl("<link[^>]*\\shref=\"https?://", html))
  # Content made it in
  expect_true(grepl("CORE-000172", html))
  expect_true(grepl("panel-issues",   html))
  expect_true(grepl("panel-details",  html))
  expect_true(grepl("panel-datasets", html))
  expect_true(grepl("panel-rules",    html))
  # Both datasets surfaced
  expect_true(grepl(">AE<",  html))
  expect_true(grepl(">DM<",  html))
  # Severity rows carry the printable class
  expect_true(grepl("sev-reject", html))
})

test_that("write_report_html escapes HTML-unsafe strings", {
  f <- mk_findings_fixture()
  f$message[1] <- "<script>alert(1)</script>"
  r <- mk_result_fixture(findings = f)
  p <- withr::local_tempfile(fileext = ".html")
  write_report_html(r, p)
  html <- paste(readLines(p, warn = FALSE), collapse = "\n")
  expect_false(grepl("<script>alert", html, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;alert", html, fixed = TRUE))
})

test_that("write_report_html handles empty findings gracefully", {
  r <- new_herald_result()
  p <- withr::local_tempfile(fileext = ".html")
  write_report_html(r, p)
  html <- paste(readLines(p, warn = FALSE), collapse = "\n")
  expect_true(grepl("No findings emitted", html))
})

# ---- helpers --------------------------------------------------------------

test_that("summarise_counts tallies by all four columns", {
  counts <- summarise_counts(mk_findings_fixture())
  expect_equal(counts$by_status[["fired"]], 2L)
  expect_equal(counts$by_severity[["Reject"]], 1L)
  expect_equal(counts$by_dataset[["AE"]], 2L)
  expect_equal(counts$by_rule[["CORE-000172"]], 2L)
})

test_that("applied_rules joins fired/advisory counts onto catalog", {
  r <- mk_result_fixture()
  ar <- applied_rules(r$rule_catalog, r$findings)
  expect_true(all(c("fired_n", "advisory_n") %in% names(ar)))
  i172 <- which(ar$id == "CORE-000172")
  expect_equal(ar$fired_n[i172], 2L)
  i201 <- which(ar$id == "CORE-000201")
  expect_equal(ar$advisory_n[i201], 1L)
  i999 <- which(ar$id == "CORE-999999")
  expect_equal(ar$fired_n[i999], 0L)
  expect_equal(ar$advisory_n[i999], 0L)
})

test_that("dataset_meta_tbl flattens named list to a tibble with counts", {
  r <- mk_result_fixture()
  t <- dataset_meta_tbl(r$dataset_meta, r$findings)
  expect_equal(nrow(t), 2L)
  expect_equal(t$fired_n[t$name == "AE"],    1L)
  expect_equal(t$fired_n[t$name == "DM"],    1L)
  expect_equal(t$advisory_n[t$name == "AE"], 1L)
})

test_that("iso_timestamp returns a Z-suffixed ISO-8601 string", {
  s <- iso_timestamp(as.POSIXct("2026-04-20 12:34:56", tz = "UTC"))
  expect_equal(s, "2026-04-20T12:34:56Z")
})

test_that("format_duration_secs rounds to 2 dp", {
  d <- as.difftime(1.23456, units = "secs")
  expect_equal(format_duration_secs(d), 1.23)
})
