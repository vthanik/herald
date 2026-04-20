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
