# -----------------------------------------------------------------------------
# test-fast-report.R -- report()/write_report_* (HTML + XLSX + JSON)
# -----------------------------------------------------------------------------

mk_findings_fixture <- function() {
  tibble::tibble(
    rule_id = c("CORE-000172", "CORE-000172", "CORE-000201"),
    authority = rep("CDISC", 3L),
    standard = rep("SDTM-IG", 3L),
    severity = c("Reject", "High", "Medium"),
    status = c("fired", "fired", "advisory"),
    dataset = c("AE", "DM", "AE"),
    variable = c("USUBJID", "STUDYID", NA_character_),
    row = c(1L, 2L, NA_integer_),
    value = c("x", "y", NA_character_),
    expected = rep(NA_character_, 3L),
    message = c("bad link", "bad study id", "could not decide"),
    source_url = c(
      "https://example/rules/172",
      "https://example/rules/172",
      "https://example/rules/201"
    ),
    p21_id_equivalent = rep(NA_character_, 3L),
    license = rep("CC-BY-4.0", 3L)
  )
}

mk_result_fixture <- function(findings = mk_findings_fixture()) {
  rule_catalog <- tibble::tibble(
    id = c("CORE-000172", "CORE-000201", "CORE-999999"),
    authority = rep("CDISC", 3L),
    standard = rep("SDTM-IG", 3L),
    severity = c("Reject", "Medium", "Low"),
    message = c("study id must match", "usubjid must be present", "x")
  )
  new_herald_result(
    findings = findings,
    rules_applied = 2L,
    rules_total = 3L,
    datasets_checked = c("AE", "DM"),
    duration = as.difftime(1.75, units = "secs"),
    profile = NA_character_,
    config_hash = NA_character_,
    dataset_meta = list(
      AE = list(
        rows = 10L,
        cols = 5L,
        label = "Adverse Events",
        class = "EVENTS"
      ),
      DM = list(
        rows = 3L,
        cols = 6L,
        label = "Demographics",
        class = "SPECIAL PURPOSE"
      )
    ),
    rule_catalog = rule_catalog,
    op_errors = list()
  )
}

# ---- dispatcher + input validation ----------------------------------------

test_that("report() rejects non-herald_result inputs", {
  expect_error(
    report(list(), tempfile(fileext = ".json")),
    class = "herald_error_report"
  )
})

test_that("report() rejects unknown formats", {
  r <- mk_result_fixture()
  expect_error(
    report(r, tempfile(fileext = ".pdf")),
    class = "herald_error_report"
  )
})

test_that("report() errors when path directory is missing", {
  r <- mk_result_fixture()
  expect_error(
    report(r, "/no/such/dir/out.json"),
    class = "herald_error_file"
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

  expect_equal(
    obj$herald_version,
    as.character(utils::packageVersion("herald"))
  )
  expect_equal(obj$rules_applied, 2L)
  expect_equal(obj$rules_total, 3L)
  expect_equal(unlist(obj$datasets_checked), c("AE", "DM"))
  expect_equal(obj$counts$by_status$fired, 2L)
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

test_that("write_report_xlsx emits the expected 4 sheets", {
  r <- mk_result_fixture()
  p <- withr::local_tempfile(fileext = ".xlsx")
  write_report_xlsx(r, p)
  expect_true(file.exists(p))

  wb <- openxlsx2::wb_load(p)
  expect_equal(
    unname(wb$get_sheet_names()),
    c("summary", "findings", "datasets", "rules")
  )

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
  expect_true(grepl("panel-issues", html))
  expect_true(grepl("panel-details", html))
  expect_true(grepl("panel-datasets", html))
  expect_true(grepl("panel-rules", html))
  # Both datasets surfaced
  expect_true(grepl(">AE<", html))
  expect_true(grepl(">DM<", html))
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
  expect_equal(t$fired_n[t$name == "AE"], 1L)
  expect_equal(t$fired_n[t$name == "DM"], 1L)
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

# ---- report-html.R: uncovered branches ------------------------------------

test_that("write_report_html shows skipped refs cell in header meta", {
  # Build a result that has skipped references so n_skipped > 0 in header
  r <- mk_result_fixture()
  # Inject skipped_refs with one dataset entry
  r$skipped_refs <- list(
    datasets = list(
      DM = list(rule_ids = c("CG0001", "CG0002"), hint = "Provide DM dataset")
    ),
    dictionaries = list()
  )
  p <- withr::local_tempfile(fileext = ".html")
  write_report_html(r, p)
  html <- paste(readLines(p, warn = FALSE), collapse = "\n")
  expect_true(grepl("Skipped", html))
})

test_that("write_report_html renders skipped refs section with dict entries", {
  r <- mk_result_fixture()
  r$skipped_refs <- list(
    datasets = list(
      AE = list(rule_ids = c("CG0100"), hint = "Provide AE dataset")
    ),
    dictionaries = list(
      MedDRA = list(rule_ids = c("CG0200"), hint = "Provide MedDRA dictionary")
    )
  )
  p <- withr::local_tempfile(fileext = ".html")
  write_report_html(r, p)
  html <- paste(readLines(p, warn = FALSE), collapse = "\n")
  expect_true(grepl("Missing reference data", html))
  expect_true(grepl("MedDRA", html))
  expect_true(grepl("Dictionary", html))
})

test_that("write_report_html truncates details at 2000 rows with notice", {
  # Build result with > 2000 findings rows
  big_findings <- tibble::tibble(
    rule_id = rep("CORE-000001", 2005L),
    authority = rep("CDISC", 2005L),
    standard = rep("SDTM-IG", 2005L),
    severity = rep("Low", 2005L),
    status = rep("fired", 2005L),
    dataset = rep("AE", 2005L),
    variable = rep("AETERM", 2005L),
    row = seq_len(2005L),
    value = rep("x", 2005L),
    expected = rep(NA_character_, 2005L),
    message = rep("msg", 2005L),
    source_url = rep(NA_character_, 2005L),
    p21_id_equivalent = rep(NA_character_, 2005L),
    license = rep(NA_character_, 2005L)
  )
  r <- mk_result_fixture(findings = big_findings)
  p <- withr::local_tempfile(fileext = ".html")
  write_report_html(r, p)
  html <- paste(readLines(p, warn = FALSE), collapse = "\n")
  expect_true(grepl("additional findings omitted", html))
})

test_that(".html_tab_issues renders empty rule list row with dash", {
  # Pass a counts list with empty by_rule so top_rows = dash row
  counts <- list(
    by_severity = c(Reject = 1L, High = 0L, Medium = 0L, Low = 0L),
    by_rule = c(),  # empty named integer
    by_status = c(fired = 1L),
    by_dataset = c()
  )
  out <- herald:::.html_tab_issues(counts, n_fired = 1L, n_adv = 0L)
  expect_true(grepl("&mdash;", out))
})

test_that(".html_tab_details returns no-findings row for zero-row data.frame", {
  findings <- data.frame(
    rule_id = character(),
    severity = character(),
    status = character(),
    dataset = character(),
    variable = character(),
    row = integer(),
    value = character(),
    message = character(),
    stringsAsFactors = FALSE
  )
  out <- herald:::.html_tab_details(findings)
  expect_true(grepl("No findings to report", out))
})

test_that(".html_tab_rules renders no-rules row for empty data frame", {
  rules_df <- data.frame(
    id = character(),
    severity = character(),
    authority = character(),
    standard = character(),
    fired_n = integer(),
    advisory_n = integer(),
    message = character(),
    stringsAsFactors = FALSE
  )
  out <- herald:::.html_tab_rules(rules_df)
  expect_true(grepl("No rules in the applied catalog", out))
})

test_that(".html_tab_rules includes source link when source_url present", {
  rules_df <- data.frame(
    id = "CORE-000001",
    severity = "Low",
    authority = "CDISC",
    standard = "SDTM-IG",
    fired_n = 0L,
    advisory_n = 0L,
    source_url = "https://example.com/rule/1",
    message = "test rule",
    stringsAsFactors = FALSE
  )
  out <- herald:::.html_tab_rules(rules_df)
  expect_true(grepl("href=", out))
  expect_true(grepl("source", out))
})

test_that(".html_tab_rules uses dash when source_url is NA", {
  rules_df <- data.frame(
    id = "CORE-000001",
    severity = "Low",
    authority = "CDISC",
    standard = "SDTM-IG",
    fired_n = 0L,
    advisory_n = 0L,
    source_url = NA_character_,
    message = "test rule",
    stringsAsFactors = FALSE
  )
  out <- herald:::.html_tab_rules(rules_df)
  expect_true(grepl("&mdash;", out))
})

test_that(".na_blank returns empty string for length-0 input", {
  out <- herald:::.na_blank(character(0L))
  expect_equal(out, "")
})

test_that(".fmt_int returns '0' for NA", {
  expect_equal(herald:::.fmt_int(NA_integer_), "0")
})

test_that(".fmt_int returns '0' for length-0 input", {
  expect_equal(herald:::.fmt_int(integer(0L)), "0")
})

test_that(".fmt_row returns dash for NA", {
  expect_equal(herald:::.fmt_row(NA_integer_), "&mdash;")
})

test_that(".fmt_row returns dash for length-0 input", {
  expect_equal(herald:::.fmt_row(integer(0L)), "&mdash;")
})

test_that(".source_link returns dash for empty string url", {
  expect_equal(herald:::.source_link(""), "&mdash;")
})

test_that(".source_link returns dash for NULL", {
  expect_equal(herald:::.source_link(NULL), "&mdash;")
})

test_that(".source_link returns anchor for valid url", {
  out <- herald:::.source_link("https://example.com")
  expect_true(grepl("<a href=", out))
})

test_that(".html_skipped_refs returns empty string for non-list input", {
  out <- herald:::.html_skipped_refs("not_a_list")
  expect_equal(out, "")
})

test_that(".html_skipped_refs returns empty string when both entries empty", {
  out <- herald:::.html_skipped_refs(list(datasets = list(), dictionaries = list()))
  expect_equal(out, "")
})

test_that("write_report_html sets custom title when provided", {
  r <- mk_result_fixture()
  p <- withr::local_tempfile(fileext = ".html")
  write_report_html(r, p, title = "My Custom Title")
  html <- paste(readLines(p, warn = FALSE), collapse = "\n")
  expect_true(grepl("My Custom Title", html))
})
