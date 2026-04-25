# Tests for R/spec-read.R -- herald_spec constructor + internal accessors.

test_that("as_herald_spec() builds a valid herald_spec with ds_spec only", {
  spec <- as_herald_spec(
    ds_spec = data.frame(
      dataset = c("ADSL", "ADAE"),
      class = c("SLAD", "BDS"),
      stringsAsFactors = FALSE
    )
  )
  expect_s3_class(spec, "herald_spec")
  expect_true(is_herald_spec(spec))
  expect_equal(spec$ds_spec$dataset, c("ADSL", "ADAE"))
  expect_null(spec$var_spec)
})

test_that("as_herald_spec() accepts ds_spec + var_spec and uppercases keys", {
  spec <- as_herald_spec(
    ds_spec = data.frame(
      Dataset = c("adsl"),
      Class = c("SLAD"),
      stringsAsFactors = FALSE
    ),
    var_spec = data.frame(
      Dataset = c("adsl", "adsl"),
      Variable = c("usubjid", "age"),
      Type = c("text", "integer"),
      stringsAsFactors = FALSE
    )
  )
  expect_equal(spec$ds_spec$dataset, "ADSL")
  expect_equal(spec$var_spec$dataset, c("ADSL", "ADSL"))
  expect_equal(spec$var_spec$variable, c("USUBJID", "AGE"))
  expect_equal(names(spec$var_spec), c("dataset", "variable", "type"))
})

test_that("as_herald_spec() errors when required columns are missing", {
  expect_error(
    as_herald_spec(ds_spec = data.frame(x = 1)),
    class = "herald_error_input"
  )
  expect_error(
    as_herald_spec(
      ds_spec = data.frame(dataset = "ADSL"),
      var_spec = data.frame(dataset = "ADSL") # missing variable
    ),
    class = "herald_error_input"
  )
})

test_that("as_herald_spec() errors on non-data-frame input", {
  expect_error(as_herald_spec(ds_spec = "ADSL"), class = "herald_error_input")
  expect_error(
    as_herald_spec(
      ds_spec = data.frame(dataset = "ADSL"),
      var_spec = "not a data frame"
    ),
    class = "herald_error_input"
  )
})

test_that("as_herald_spec() rejects case-insensitive duplicate columns", {
  expect_error(
    as_herald_spec(
      ds_spec = data.frame(
        dataset = "ADSL",
        Dataset = "ADSL",
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    ),
    class = "herald_error_input"
  )
})

test_that(".spec_var() finds rows case-insensitively", {
  spec <- as_herald_spec(
    ds_spec = data.frame(dataset = "ADSL", stringsAsFactors = FALSE),
    var_spec = data.frame(
      dataset = "ADSL",
      variable = "USUBJID",
      label = "Unique Subject Identifier",
      stringsAsFactors = FALSE
    )
  )
  expect_equal(
    .spec_var(spec, "adsl", "usubjid")$label,
    "Unique Subject Identifier"
  )
  expect_null(.spec_var(spec, "ADSL", "ARM"))
  expect_null(.spec_var(NULL, "ADSL", "USUBJID"))
})

test_that(".spec_ds() finds a row case-insensitively", {
  spec <- as_herald_spec(
    ds_spec = data.frame(
      dataset = c("ADSL", "ADAE"),
      label = c("Subject-Level Analysis Dataset", "Adverse Events"),
      stringsAsFactors = FALSE
    )
  )
  expect_equal(.spec_ds(spec, "adsl")$label, "Subject-Level Analysis Dataset")
  expect_null(.spec_ds(spec, "ADVS"))
  expect_null(.spec_ds(NULL, "ADSL"))
})

test_that(".spec_var()/.spec_ds() return NULL when spec has no var_spec", {
  spec <- as_herald_spec(
    ds_spec = data.frame(dataset = "ADSL", stringsAsFactors = FALSE)
  )
  expect_null(.spec_var(spec, "ADSL", "USUBJID"))
  expect_equal(.spec_ds(spec, "ADSL")$dataset, "ADSL")
})

test_that("print.herald_spec summarises counts", {
  spec <- as_herald_spec(
    ds_spec = data.frame(dataset = c("ADSL", "ADAE"), stringsAsFactors = FALSE),
    var_spec = data.frame(
      dataset = c("ADSL", "ADAE"),
      variable = c("USUBJID", "USUBJID"),
      stringsAsFactors = FALSE
    )
  )
  expect_output(print(spec), "<herald_spec>")
  expect_output(print(spec), "2 datasets, 2 variables")
})
