# -----------------------------------------------------------------------------
# test-fast-ops-set.R -- is_contained_by / is_not_contained_by (P21-parity)
# -----------------------------------------------------------------------------

test_that("is_contained_by basic membership", {
  d <- data.frame(x = c("A", "B", "C"), stringsAsFactors = FALSE)
  expect_equal(
    op_is_contained_by(d, NULL, "x", c("A", "B")),
    c(TRUE, TRUE, FALSE)
  )
})

test_that("is_contained_by right-trims the value (P21 rtrim parity)", {
  d <- data.frame(
    x = c("S1-001", "S1-001 ", "S1-002"),
    stringsAsFactors = FALSE
  )
  expect_equal(
    op_is_contained_by(d, NULL, "x", c("S1-001")),
    c(TRUE, TRUE, FALSE)
  )
})

test_that("is_contained_by returns NA when the row's value is null/empty", {
  d <- data.frame(
    x = c("A", "", "   ", NA_character_),
    stringsAsFactors = FALSE
  )
  m <- op_is_contained_by(d, NULL, "x", c("A", "B"))
  expect_equal(m, c(TRUE, NA, NA, NA))
})

test_that("is_not_contained_by is the complement, preserving NA", {
  d <- data.frame(x = c("A", "C", "", NA_character_), stringsAsFactors = FALSE)
  m <- op_is_not_contained_by(d, NULL, "x", c("A", "B"))
  expect_equal(m, c(FALSE, TRUE, NA, NA))
})

test_that("missing column returns all-NA mask", {
  d <- data.frame(y = "A", stringsAsFactors = FALSE)
  expect_equal(op_is_contained_by(d, NULL, "x", c("A")), rep(NA, 1L))
})

# =============================================================================
# op_value_in_srs_table
# =============================================================================

.mk_fake_srs_ctx <- function(pt_terms, unii_terms) {
  pool_pt <- as.character(pt_terms)
  pool_unii <- as.character(unii_terms)
  provider <- herald:::new_dict_provider(
    name = "srs",
    version = "test",
    source = "test",
    license = "public",
    fields = c("preferred_name", "unii"),
    contains = function(value, field = "preferred_name", ignore_case = FALSE) {
      pool <- if (identical(field, "unii")) pool_unii else pool_pt
      as.character(value) %in% pool
    }
  )
  ctx <- herald:::new_herald_ctx()
  ctx$dict <- list(srs = provider)
  ctx
}

test_that("value_in_srs_table fires when preferred_name not in SRS", {
  d <- data.frame(
    TSVAL = c("ASPIRIN", "UNKNOWN_DRUG"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_fake_srs_ctx(pt_terms = "ASPIRIN", unii_terms = character())
  out <- herald:::op_value_in_srs_table(
    d,
    ctx,
    name = "TSVAL",
    field = "preferred_name"
  )
  expect_false(out[[1L]]) # ASPIRIN is valid -> pass
  expect_true(out[[2L]]) # UNKNOWN_DRUG not in SRS -> fires
})

test_that("value_in_srs_table fires when unii not in SRS", {
  d <- data.frame(
    TSVALCD = c("R16CO5Y76E", "BADINVALID"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_fake_srs_ctx(pt_terms = character(), unii_terms = "R16CO5Y76E")
  out <- herald:::op_value_in_srs_table(
    d,
    ctx,
    name = "TSVALCD",
    field = "unii"
  )
  expect_false(out[[1L]])
  expect_true(out[[2L]])
})

test_that("value_in_srs_table returns NA advisory when SRS cache absent", {
  d <- data.frame(TSVAL = "ASPIRIN", stringsAsFactors = FALSE)
  ctx <- herald:::new_herald_ctx() # no dict set
  out <- herald:::op_value_in_srs_table(d, ctx, name = "TSVAL")
  expect_true(is.na(out[[1L]]))
})

test_that("value_in_srs_table returns NA when column absent", {
  d <- data.frame(OTHER = "A", stringsAsFactors = FALSE)
  ctx <- .mk_fake_srs_ctx("ASPIRIN", character())
  out <- herald:::op_value_in_srs_table(d, ctx, name = "TSVAL")
  expect_true(is.na(out[[1L]]))
})

test_that("value_in_srs_table passes empty/NA values as NA", {
  d <- data.frame(TSVAL = c(NA_character_, "", "  "), stringsAsFactors = FALSE)
  ctx <- .mk_fake_srs_ctx("ASPIRIN", character())
  out <- herald:::op_value_in_srs_table(d, ctx, name = "TSVAL")
  expect_true(all(is.na(out)))
})

# =============================================================================
# op_value_in_dictionary
# =============================================================================

.mk_fake_meddra_ctx <- function(pt_terms, soc_terms = character()) {
  provider <- herald:::new_dict_provider(
    name = "meddra",
    version = "test",
    source = "test",
    license = "MSSO",
    fields = c("pt", "soc"),
    contains = function(value, field = "pt", ignore_case = FALSE) {
      pool <- if (identical(field, "soc")) {
        as.character(soc_terms)
      } else {
        as.character(pt_terms)
      }
      as.character(value) %in% pool
    }
  )
  ctx <- herald:::new_herald_ctx()
  ctx$dict <- list(meddra = provider)
  ctx
}

test_that("value_in_dictionary fires when PT not in MedDRA", {
  d <- data.frame(
    AEDECOD = c("Headache", "NotAValidTerm"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_fake_meddra_ctx(pt_terms = "Headache")
  out <- herald:::op_value_in_dictionary(
    d,
    ctx,
    name = "AEDECOD",
    dict_name = "meddra",
    field = "pt"
  )
  expect_false(out[[1L]]) # Headache is valid -> pass
  expect_true(out[[2L]]) # NotAValidTerm not in MedDRA -> fires
})

test_that("value_in_dictionary returns NA advisory when dict not registered", {
  d <- data.frame(AEDECOD = "Headache", stringsAsFactors = FALSE)
  ctx <- herald:::new_herald_ctx() # no dict set
  out <- herald:::op_value_in_dictionary(
    d,
    ctx,
    name = "AEDECOD",
    dict_name = "meddra",
    field = "pt"
  )
  expect_true(is.na(out[[1L]]))
})

test_that("value_in_dictionary returns NA when column absent", {
  d <- data.frame(OTHER = "A", stringsAsFactors = FALSE)
  ctx <- .mk_fake_meddra_ctx("Headache")
  out <- herald:::op_value_in_dictionary(
    d,
    ctx,
    name = "AEDECOD",
    dict_name = "meddra",
    field = "pt"
  )
  expect_true(is.na(out[[1L]]))
})

test_that("value_in_dictionary passes empty/NA values as NA", {
  d <- data.frame(
    AEDECOD = c(NA_character_, "", "  "),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_fake_meddra_ctx("Headache")
  out <- herald:::op_value_in_dictionary(
    d,
    ctx,
    name = "AEDECOD",
    dict_name = "meddra",
    field = "pt"
  )
  expect_true(all(is.na(out)))
})

test_that("value_in_dictionary records missing_ref when dict absent", {
  d <- data.frame(AEDECOD = "Headache", stringsAsFactors = FALSE)
  ctx <- herald:::new_herald_ctx()
  herald:::.init_missing_refs(ctx)
  ctx$current_rule_id <- "CG0379"
  herald:::op_value_in_dictionary(
    d,
    ctx,
    name = "AEDECOD",
    dict_name = "meddra",
    field = "pt"
  )
  # missing_refs$dictionaries is keyed by dict name, value = rule_ids
  expect_true("meddra" %in% names(ctx$missing_refs$dictionaries))
  expect_true("CG0379" %in% ctx$missing_refs$dictionaries[["meddra"]])
})

# =============================================================================
# op_is_not_unique_relationship
# =============================================================================

test_that("functional dependency X -> Y: same X, same Y -> no violation", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR"),
    PARAM = c("Heart Rate", "Heart Rate", "Heart Rate"),
    stringsAsFactors = FALSE
  )
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  expect_equal(mask, c(FALSE, FALSE, FALSE))
})

test_that("X -> Y violation fires all rows in the violating group", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR", "BP"),
    PARAM = c("Heart Rate", "Heart Rate", "Heart", "Blood Pressure"),
    stringsAsFactors = FALSE
  )
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  # All three HR rows fire (violating group); the BP row does not.
  expect_equal(mask, c(TRUE, TRUE, TRUE, FALSE))
})

test_that("right-trim collapses 'Heart Rate' and 'Heart Rate ' to the same value", {
  d <- data.frame(
    PARAMCD = c("HR", "HR"),
    PARAM = c("Heart Rate", "Heart Rate "),
    stringsAsFactors = FALSE
  )
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  # Both rows should collapse to same value -> NOT a violation.
  expect_equal(mask, c(FALSE, FALSE))
})

test_that("NA in either variable is excluded from the count", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR", "BP"),
    PARAM = c("Heart Rate", NA, "", "Blood Pressure"),
    stringsAsFactors = FALSE
  )
  # Only the first HR row has both vars populated; others are excluded.
  # The HR group has one distinct PARAM -> no violation.
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  expect_equal(mask[1:4], c(FALSE, FALSE, FALSE, FALSE))
})

test_that("whitespace-only values collapse to NA (excluded)", {
  d <- data.frame(
    PARAMCD = c("HR", "HR"),
    PARAM = c("Heart Rate", "   "),
    stringsAsFactors = FALSE
  )
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  expect_equal(mask, c(FALSE, FALSE))
})

test_that("single-row group is trivially unique", {
  d <- data.frame(
    PARAMCD = "HR",
    PARAM = "Heart Rate",
    stringsAsFactors = FALSE
  )
  expect_equal(
    op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM"),
    FALSE
  )
})

test_that("missing dependent column -> NA mask", {
  d <- data.frame(PARAMCD = c("HR", "HR"), stringsAsFactors = FALSE)
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  expect_equal(mask, rep(NA, 2L))
})

test_that("is_not_unique_relationship flags inconsistent X->Y mappings (AEDECOD scenario)", {
  ae <- data.frame(
    AEDECOD = c("HEADACHE", "HEADACHE", "NAUSEA", "HEADACHE"),
    AELLT = c("HEAD PAIN", "HEADACHE", "NAUSEA", "HEAD PAIN"),
    stringsAsFactors = FALSE
  )
  # HEADACHE maps to both HEAD PAIN and HEADACHE -> inconsistent
  # NAUSEA maps to NAUSEA only -> consistent
  out <- op_is_not_unique_relationship(
    ae,
    NULL,
    "AEDECOD",
    list(related_name = "AELLT")
  )
  expect_equal(out, c(TRUE, TRUE, FALSE, TRUE))
})
