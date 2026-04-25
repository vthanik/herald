# -----------------------------------------------------------------------------
# test-fast-rules-scope.R — scoped_datasets() filter
# -----------------------------------------------------------------------------

mk_ctx <- function(dataset_names, ds_spec = NULL) {
  ctx <- new_herald_ctx()
  ctx$datasets <- setNames(
    lapply(dataset_names, function(n) data.frame(X = 1)),
    dataset_names
  )
  if (!is.null(ds_spec)) ctx$spec <- list(ds_spec = ds_spec)
  ctx
}

test_that("empty scope rule runs against every dataset", {
  ctx <- mk_ctx(c("DM", "AE", "LB"))
  rule <- list(id = "X", standard = "SDTM-IG", scope = list())
  expect_equal(scoped_datasets(rule, ctx), c("DM", "AE", "LB"))
})

test_that("scope.domains filters to named domains", {
  ctx <- mk_ctx(c("DM", "AE", "LB"))
  rule <- list(id = "X", standard = "SDTM-IG",
               scope = list(domains = list("AE", "LB")))
  expect_equal(scoped_datasets(rule, ctx), c("AE", "LB"))
})

test_that("scope.domains ALL wildcard matches everything", {
  ctx <- mk_ctx(c("DM", "AE", "LB"))
  rule <- list(id = "X", standard = "SDTM-IG",
               scope = list(domains = list("ALL")))
  expect_equal(scoped_datasets(rule, ctx), c("DM", "AE", "LB"))
})

test_that("SDTM rule does NOT fire against ADaM datasets (by name prefix)", {
  ctx <- mk_ctx(c("DM", "AE", "ADSL", "ADAE"))
  rule <- list(id = "X", standard = "SDTM-IG",
               scope = list(domains = list("ALL")))
  # ALL wildcard overrides at the domain layer, so ALL actually passes.
  # Use a specific domain list to test exclusion:
  rule2 <- list(id = "Y", standard = "SDTM-IG",
                scope = list(domains = list("DM", "AE", "ADSL", "ADAE")))
  expect_equal(scoped_datasets(rule2, ctx), c("DM", "AE"))
})

test_that("SDTM rule DOES fire against ADaM names when scope is empty (structural)", {
  ctx <- mk_ctx(c("DM", "ADSL"))
  rule <- list(id = "CT0001", standard = "SDTM-IG", scope = list())
  expect_equal(scoped_datasets(rule, ctx), c("DM", "ADSL"))
})

test_that("ADaM rules fire against ADaM datasets", {
  ctx <- mk_ctx(c("ADSL", "ADAE"))
  rule <- list(id = "X", standard = "ADaM-IG",
               scope = list(domains = list("ADSL")))
  expect_equal(scoped_datasets(rule, ctx), "ADSL")
})

test_that("scope.classes matches via ds_class lookup", {
  ds_spec <- data.frame(
    dataset = c("ADAE", "ADLB", "ADSL"),
    class   = c("OCCDS", "BDS", "ADSL"),
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx(c("ADAE", "ADLB", "ADSL"), ds_spec = ds_spec)
  rule <- list(id = "X", standard = "ADaM-IG",
               scope = list(classes = list("BDS")))
  expect_equal(scoped_datasets(rule, ctx), "ADLB")
})

test_that("scope.classes normalises ADaM long <-> short forms", {
  ds_spec <- data.frame(
    dataset = c("ADAE", "ADLB"),
    class   = c("OCCURRENCE DATA STRUCTURE", "BASIC DATA STRUCTURE"),
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx(c("ADAE", "ADLB"), ds_spec = ds_spec)
  rule <- list(id = "X", standard = "ADaM-IG",
               scope = list(classes = list("BDS")))
  expect_equal(scoped_datasets(rule, ctx), "ADLB")
})

test_that("empty datasets -> empty scoped result", {
  ctx <- new_herald_ctx()
  ctx$datasets <- list()
  rule <- list(id = "X", scope = list(domains = "AE"))
  expect_equal(scoped_datasets(rule, ctx), character())
})

test_that("CT rules are exempt from SDTM -> ADaM exclusion", {
  ctx <- mk_ctx(c("ADSL", "ADAE"))
  rule <- list(id = "CT0045", standard = "SDTM-IG",
               scope = list(domains = list("ADSL")))
  # CT rule, so ADaM exclusion does NOT apply
  expect_equal(scoped_datasets(rule, ctx), "ADSL")
})
