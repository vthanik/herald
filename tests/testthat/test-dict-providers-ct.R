# Tests for R/dict-providers-ct.R -- ct_provider() factory.

test_that("ct_provider('sdtm') wraps the bundled SDTM CT", {
  p <- ct_provider("sdtm")
  expect_s3_class(p, "herald_dict_provider")
  expect_equal(p$name, "ct-sdtm")
  expect_equal(p$source, "bundled")
  expect_equal(p$license, "CC-BY-4.0")
  expect_gt(p$size_rows, 40000L)
  expect_true("NY" %in% p$fields)
})

test_that("ct_provider('adam') wraps the bundled ADaM CT", {
  p <- ct_provider("adam")
  expect_s3_class(p, "herald_dict_provider")
  expect_equal(p$name, "ct-adam")
  expect_true("DATEFL" %in% p$fields)
  expect_true("TIMEFL" %in% p$fields)
})

test_that("contains() tests codelist membership per submission value", {
  p <- ct_provider("sdtm")
  expect_true(all(p$contains(c("Y", "N"), field = "NY")))
  expect_equal(p$contains(c("Y", "UNKNOWN_VALUE"), field = "NY"),
               c(TRUE, FALSE))
  expect_true(p$contains("ASSIGNED, NOT TREATED", field = "ARMNULRS"))
})

test_that("contains() rtrims trailing spaces before match", {
  p <- ct_provider("sdtm")
  expect_true(p$contains("Y  ", field = "NY"))
})

test_that("contains() returns NA when field is missing or unknown", {
  p <- ct_provider("sdtm")
  expect_true(all(is.na(p$contains(c("Y"), field = NULL))))
  expect_true(all(is.na(p$contains(c("Y"), field = "NOT_A_CODELIST"))))
})

test_that("ignore_case = TRUE matches case-insensitively", {
  p <- ct_provider("sdtm")
  expect_true(p$contains("y", field = "NY", ignore_case = TRUE))
  expect_false(p$contains("y", field = "NY", ignore_case = FALSE))
})

test_that("lookup() returns the matching term rows", {
  p <- ct_provider("sdtm")
  hits <- p$lookup(c("Y", "N"), field = "NY")
  expect_s3_class(hits, "data.frame")
  expect_setequal(hits$submissionValue, c("Y", "N"))
})

test_that("lookup() returns NULL for unknown field or value", {
  p <- ct_provider("sdtm")
  expect_null(p$lookup("Y", field = "NOT_A_CODELIST"))
  expect_null(p$lookup("ZZZ_NO_MATCH", field = "NY"))
})

test_that("op_value_in_codelist still works unchanged (provider shim)", {
  d <- data.frame(FL = c("Y", "N", "UNKNOWN", NA_character_),
                  stringsAsFactors = FALSE)
  ctx <- list()
  out <- op_value_in_codelist(d, ctx, name = "FL", codelist = "NY")
  # Y and N are in NY, UNKNOWN is not, NA advises
  expect_equal(out, c(FALSE, FALSE, TRUE, NA))
})

test_that("op_value_in_codelist populates ctx$dict on first use", {
  d <- data.frame(FL = "Y", stringsAsFactors = FALSE)
  ctx <- new.env()
  ctx$dict <- list()
  op_value_in_codelist(d, ctx, name = "FL", codelist = "NY")
  expect_true("ct-sdtm" %in% names(ctx$dict))
  expect_s3_class(ctx$dict[["ct-sdtm"]], "herald_dict_provider")
})

test_that("op_value_in_codelist with match_synonyms reads raw CT", {
  # NY codelist has no synonyms; this exercises the synonym branch
  # code path and confirms it still returns a correct membership.
  d <- data.frame(FL = c("Y", "UNKNOWN_VALUE"), stringsAsFactors = FALSE)
  ctx <- list()
  out <- op_value_in_codelist(d, ctx, name = "FL", codelist = "NY",
                              match_synonyms = TRUE)
  expect_equal(out, c(FALSE, TRUE))
})

test_that("ct_provider() works via register_dictionary + validate()", {
  skip_if_not_installed("testthat")
  on.exit(unregister_dictionary("ct-sdtm"), add = TRUE)
  register_dictionary("ct-sdtm", ct_provider("sdtm"))
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  r <- validate(files = list(DM = dm), rules = character(0),
                quiet = TRUE)
  expect_s3_class(r, "herald_result")
})
