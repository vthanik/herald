# -----------------------------------------------------------------------------
# test-fast-rules-findings.R — findings emitter
# -----------------------------------------------------------------------------

mk_rule <- function(...) {
  base <- list(
    id = "TEST-001", authority = "CDISC", standard = "SDTM-IG",
    severity = "High", message = "must be X",
    source_url = "herald-own", license = "MIT",
    p21_id_equivalent = NA_character_
  )
  utils::modifyList(base, list(...))
}

mk_data <- function(n = 4L) {
  data.frame(USUBJID = sprintf("S%d", seq_len(n)),
             AESTDTC = as.character(seq_len(n)),
             stringsAsFactors = FALSE)
}

test_that("empty_findings() returns tibble with canonical columns", {
  f <- empty_findings()
  expect_s3_class(f, "tbl_df")
  expect_equal(nrow(f), 0L)
  expect_true(all(c("rule_id","status","dataset","row","severity","message")
                  %in% names(f)))
})

test_that("emit_findings fires on TRUE rows (CDISC violation semantics)", {
  rule <- mk_rule()
  d <- mk_data(4L)
  # TRUE = violation condition met = emit finding
  mask <- c(TRUE, FALSE, TRUE, FALSE)
  f <- emit_findings(rule, "AE", mask, d, variable = "AESTDTC")
  expect_equal(nrow(f), 2L)
  expect_equal(f$row, c(1L, 3L))
  expect_equal(f$status, c("fired", "fired"))
  expect_equal(f$dataset, c("AE", "AE"))
  expect_equal(f$variable, c("AESTDTC", "AESTDTC"))
  expect_equal(f$value, c("1", "3"))
})

test_that("all-FALSE mask produces no findings (all pass)", {
  rule <- mk_rule()
  f <- emit_findings(rule, "AE", c(FALSE, FALSE, FALSE), mk_data(3))
  expect_equal(nrow(f), 0L)
})

test_that("all-NA mask produces one advisory row", {
  rule <- mk_rule()
  f <- emit_findings(rule, "AE", c(NA, NA, NA), mk_data(3))
  expect_equal(nrow(f), 1L)
  expect_equal(f$status, "advisory")
  expect_true(is.na(f$row))
})

test_that("mixed NA + TRUE mask emits only 'fired' rows (advisory suppressed)", {
  rule <- mk_rule()
  f <- emit_findings(rule, "AE", c(TRUE, NA, FALSE, NA), mk_data(4),
                     variable = "USUBJID")
  expect_equal(nrow(f), 1L)
  expect_equal(f$status, "fired")
  expect_equal(f$row, 1L)
})

test_that("variable=NA omits the value column data", {
  rule <- mk_rule()
  f <- emit_findings(rule, "AE", c(TRUE, TRUE), mk_data(2))
  expect_equal(nrow(f), 2L)
  expect_true(all(is.na(f$value)))
  expect_true(all(is.na(f$variable)))
})

test_that("primary_variable() picks first leaf with a name", {
  tree <- list(all = list(
    list(all = list(
      list(operator = "iso8601", name = "AESTDTC"),
      list(operator = "non_empty", name = "AETERM")
    )),
    list(operator = "length_le", name = "AEDECOD", value = 200L)
  ))
  expect_equal(primary_variable(tree), "AESTDTC")
})

test_that("primary_variable() handles narrative/empty trees", {
  expect_true(is.na(primary_variable(NULL)))
  expect_true(is.na(primary_variable(list())))
  expect_true(is.na(primary_variable(list(narrative = "text"))))
})

test_that("primary_variable() descends into {not}", {
  tree <- list(`not` = list(operator = "non_empty", name = "VSORRES"))
  expect_equal(primary_variable(tree), "VSORRES")
})
