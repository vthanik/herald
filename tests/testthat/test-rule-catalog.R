test_that("rule_catalog() returns a tibble with required columns", {
  cat <- herald:::rule_catalog()
  expect_s3_class(cat, "tbl_df")
  expect_in(
    c("rule_id", "standard", "authority", "severity", "message",
      "source_document", "has_predicate"),
    names(cat)
  )
})

test_that("rule_catalog() total row count matches rules.rds + spec_rules.rds", {
  cat <- herald:::rule_catalog()
  n_rules <- nrow(readRDS(system.file("rules", "rules.rds", package = "herald")))
  n_spec  <- nrow(readRDS(system.file("rules", "spec_rules.rds", package = "herald")))
  expect_equal(nrow(cat), n_rules + n_spec)
})

test_that("rule_catalog() has no NAs in key identifier columns", {
  cat <- herald:::rule_catalog()
  expect_false(anyNA(cat$rule_id))
  expect_false(anyNA(cat$standard))
  expect_false(anyNA(cat$authority))
})

test_that("rule_catalog() has_predicate is logical", {
  cat <- herald:::rule_catalog()
  expect_type(cat$has_predicate, "logical")
})

test_that("supported_standards() returns a tibble with required columns", {
  ss <- herald:::supported_standards()
  expect_s3_class(ss, "tbl_df")
  expect_in(
    c("standard", "authority", "n_rules", "n_predicate", "n_narrative",
      "pct_predicate"),
    names(ss)
  )
})

test_that("supported_standards() row count == unique standard x authority pairs", {
  cat <- herald:::rule_catalog()
  expected_rows <- nrow(unique(cat[, c("standard", "authority")]))
  ss <- herald:::supported_standards()
  expect_equal(nrow(ss), expected_rows)
})

test_that("supported_standards() pct_predicate is in [0, 1]", {
  ss <- herald:::supported_standards()
  pct <- ss$pct_predicate[!is.na(ss$pct_predicate)]
  expect_true(all(pct >= 0 & pct <= 1))
})

test_that("supported_standards() carries compiled_at and herald_version attributes", {
  ss <- herald:::supported_standards()
  expect_false(is.null(attr(ss, "compiled_at")))
  expect_false(is.null(attr(ss, "herald_version")))
})

test_that("supported_standards() n_predicate + n_narrative == n_rules", {
  ss <- herald:::supported_standards()
  expect_equal(ss$n_predicate + ss$n_narrative, ss$n_rules)
})

# ---------------------------------------------------------------------------
# rules.rds catalog integrity (from test-fast-rules-catalog.R)
# ---------------------------------------------------------------------------

test_that("rule catalog loads from inst/rules/rules.rds", {
  rules_path <- system.file("rules", "rules.rds", package = "herald")
  skip_if(!nzchar(rules_path), "rules.rds not yet installed")

  rules <- readRDS(rules_path)

  expect_s3_class(rules, "tbl_df")
  expect_gt(nrow(rules), 0)

  required_cols <- c(
    "id", "authority", "standard", "severity", "scope", "check_tree",
    "message", "source_url", "license", "content_hash"
  )
  expect_true(all(required_cols %in% names(rules)))
})

test_that("every rule has a valid severity", {
  rules_path <- system.file("rules", "rules.rds", package = "herald")
  skip_if(!nzchar(rules_path), "rules.rds not yet installed")

  rules <- readRDS(rules_path)
  valid <- c("Reject", "High", "Medium", "Low")
  expect_true(all(rules$severity %in% valid))
})

test_that("every rule has a non-empty message", {
  rules_path <- system.file("rules", "rules.rds", package = "herald")
  skip_if(!nzchar(rules_path), "rules.rds not yet installed")

  rules <- readRDS(rules_path)
  expect_true(all(nzchar(rules$message)))
})

test_that("rule ids are unique", {
  rules_path <- system.file("rules", "rules.rds", package = "herald")
  skip_if(!nzchar(rules_path), "rules.rds not yet installed")

  rules <- readRDS(rules_path)
  expect_equal(anyDuplicated(rules$id), 0)
})

test_that("no P21-derived rule sneaks in via source_url / source_document", {
  rules_path <- system.file("rules", "rules.rds", package = "herald")
  skip_if(!nzchar(rules_path), "rules.rds not yet installed")

  rules <- readRDS(rules_path)
  banned <- c("p21", "pinnacle", "opencdisc", "Pinnacle 21")

  # Case-insensitive substring check across provenance fields
  hay <- tolower(paste(
    rules$source_url, rules$source_document, rules$source_version
  ))
  for (term in banned) {
    hits <- grepl(term, hay, fixed = TRUE)
    expect_false(
      any(hits),
      info = sprintf(
        "Banned source term '%s' appears in %d rule(s)",
        term, sum(hits)
      )
    )
  }
})
