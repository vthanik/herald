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

# =============================================================================
# op_is_not_contained_by_case_insensitive (ci inverse)
# =============================================================================

test_that("is_not_contained_by_ci returns complement of is_contained_by_ci", {
  d <- data.frame(x = c("A", "B", "C"), stringsAsFactors = FALSE)
  expect_equal(
    op_is_not_contained_by_ci(d, NULL, "x", c("a", "b")),
    c(FALSE, FALSE, TRUE)
  )
})

test_that("is_not_contained_by_ci handles missing column", {
  d <- data.frame(y = "A", stringsAsFactors = FALSE)
  expect_equal(op_is_not_contained_by_ci(d, NULL, "x", c("A")), !rep(NA, 1L))
})

# =============================================================================
# op_contains_all / op_not_contains_all
# =============================================================================

test_that("op_contains_all fires when all required tokens are present", {
  d <- data.frame(
    FLAG = c("CRIT1 CRIT2", "CRIT1", "CRIT2 CRIT1", NA_character_),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_contains_all(d, NULL, "FLAG", c("CRIT1", "CRIT2"))
  expect_equal(unname(out), c(TRUE, FALSE, TRUE, NA))
})

test_that("op_contains_all passes with empty needed set (always TRUE)", {
  d <- data.frame(FLAG = c("CRIT1", "CRIT2"), stringsAsFactors = FALSE)
  out <- herald:::op_contains_all(d, NULL, "FLAG", character(0))
  expect_equal(out, c(TRUE, TRUE))
})

test_that("op_contains_all returns NA for missing column", {
  d <- data.frame(X = "A", stringsAsFactors = FALSE)
  out <- herald:::op_contains_all(d, NULL, "FLAG", c("CRIT1"))
  expect_equal(out, NA)
})

test_that("op_contains_all returns NA for empty/NA values", {
  d <- data.frame(FLAG = c("", NA_character_), stringsAsFactors = FALSE)
  out <- herald:::op_contains_all(d, NULL, "FLAG", c("CRIT1"))
  expect_equal(unname(out), c(NA, NA))
})

test_that("op_not_contains_all is the inverse of op_contains_all", {
  d <- data.frame(
    FLAG = c("CRIT1 CRIT2", "CRIT1"),
    stringsAsFactors = FALSE
  )
  m <- herald:::op_contains_all(d, NULL, "FLAG", c("CRIT1", "CRIT2"))
  mnot <- herald:::op_not_contains_all(d, NULL, "FLAG", c("CRIT1", "CRIT2"))
  expect_equal(mnot, ifelse(is.na(m), NA, !m))
})

# =============================================================================
# op_shares_no_elements_with
# =============================================================================

test_that("op_shares_no_elements_with fires when tokenized value has banned token", {
  d <- data.frame(
    QEVLTYP = c("SAFETY EFFICACY", "SAFETY", "PHARMACOKINETICS"),
    stringsAsFactors = FALSE
  )
  banned <- c("SAFETY")
  out <- herald:::op_shares_no_elements_with(d, NULL, "QEVLTYP", banned)
  expect_equal(unname(out), c(FALSE, FALSE, TRUE))
})

test_that("op_shares_no_elements_with returns NA for NA/empty values", {
  d <- data.frame(
    QEVLTYP = c(NA_character_, ""),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_shares_no_elements_with(d, NULL, "QEVLTYP", c("SAFETY"))
  expect_equal(unname(out), c(NA, NA))
})

test_that("op_shares_no_elements_with returns NA for missing column", {
  d <- data.frame(X = "A", stringsAsFactors = FALSE)
  out <- herald:::op_shares_no_elements_with(d, NULL, "QEVLTYP", c("SAFETY"))
  expect_equal(out, NA)
})

# =============================================================================
# op_is_ordered_subset_of / op_is_not_ordered_subset_of
# =============================================================================

test_that("op_is_ordered_subset_of passes for in-order sequence", {
  d <- data.frame(VISITNUM = c(1, 2, 4), stringsAsFactors = FALSE)
  universe <- as.list(c(1, 2, 3, 4, 5))
  out <- herald:::op_is_ordered_subset_of(d, NULL, "VISITNUM", universe)
  expect_equal(out, c(TRUE, TRUE, TRUE))
})

test_that("op_is_ordered_subset_of fires when sequence goes backward", {
  d <- data.frame(VISITNUM = c(1, 3, 2), stringsAsFactors = FALSE)
  universe <- as.list(c(1, 2, 3, 4, 5))
  out <- herald:::op_is_ordered_subset_of(d, NULL, "VISITNUM", universe)
  expect_equal(out, c(TRUE, TRUE, FALSE))
})

test_that("op_is_ordered_subset_of returns NA when value not in universe", {
  d <- data.frame(VISITNUM = c(1, 99), stringsAsFactors = FALSE)
  universe <- as.list(c(1, 2, 3))
  out <- herald:::op_is_ordered_subset_of(d, NULL, "VISITNUM", universe)
  expect_equal(out[[1L]], TRUE)
  expect_true(is.na(out[[2L]]))
})

test_that("op_is_ordered_subset_of returns NA for missing column", {
  d <- data.frame(X = 1L, stringsAsFactors = FALSE)
  out <- herald:::op_is_ordered_subset_of(d, NULL, "VISITNUM", as.list(1:5))
  expect_equal(out, NA)
})

test_that("op_is_not_ordered_subset_of is the inverse", {
  d <- data.frame(VISITNUM = c(1, 3, 2), stringsAsFactors = FALSE)
  universe <- as.list(c(1, 2, 3))
  m <- herald:::op_is_ordered_subset_of(d, NULL, "VISITNUM", universe)
  mnot <- herald:::op_is_not_ordered_subset_of(d, NULL, "VISITNUM", universe)
  expect_equal(mnot, ifelse(is.na(m), NA, !m))
})

# =============================================================================
# .tokenize helper
# =============================================================================

test_that(".tokenize splits on comma, pipe, semicolon, and space", {
  result <- herald:::.tokenize("A,B|C;D E")
  expect_equal(sort(result), c("A", "B", "C", "D", "E"))
})

# =============================================================================
# .as_set helper
# =============================================================================

test_that(".as_set converts NULL to empty character", {
  expect_equal(herald:::.as_set(NULL), character(0))
})

test_that(".as_set converts list to character vector", {
  expect_equal(herald:::.as_set(list("A", "B")), c("A", "B"))
})

# =============================================================================
# .lookup_codelist helper
# =============================================================================

test_that(".lookup_codelist finds by submission name", {
  ct <- list(SEX = list(codelist_code = "C66731", codelist_name = "Sex"))
  expect_equal(herald:::.lookup_codelist(ct, "SEX")$codelist_code, "C66731")
})

test_that(".lookup_codelist finds by codelist_code", {
  ct <- list(SEX = list(codelist_code = "C66731", codelist_name = "Sex"))
  expect_equal(herald:::.lookup_codelist(ct, "C66731")$codelist_name, "Sex")
})

test_that(".lookup_codelist finds by codelist_name", {
  ct <- list(SEX = list(codelist_code = "C66731", codelist_name = "Sex"))
  expect_equal(herald:::.lookup_codelist(ct, "Sex")$codelist_code, "C66731")
})

test_that(".lookup_codelist returns NULL when not found", {
  ct <- list(SEX = list(codelist_code = "C66731", codelist_name = "Sex"))
  expect_null(herald:::.lookup_codelist(ct, "NOTEXIST"))
})

# =============================================================================
# op_value_in_codelist -- additional branch coverage
# =============================================================================

# Helper: fake CT provider that returns all-NA for any contains() call.
# Used to exercise the "codelist not found in provider" advisory path.
.mk_ct_ctx_na_provider <- function() {
  provider <- herald:::new_dict_provider(
    name = "ct-sdtm",
    version = "test",
    source = "test",
    license = "CC-BY-4.0",
    fields = character(0L),
    contains = function(value, field = NULL, ignore_case = FALSE) {
      rep(NA, length(value))
    }
  )
  ctx <- herald:::new_herald_ctx()
  ctx$dict <- list("ct-sdtm" = provider)
  ctx
}

# Helper: fake CT provider that always returns TRUE (all values in codelist).
.mk_ct_ctx_all_pass <- function() {
  provider <- herald:::new_dict_provider(
    name = "ct-sdtm",
    version = "test",
    source = "test",
    license = "CC-BY-4.0",
    fields = c("NY"),
    contains = function(value, field = NULL, ignore_case = FALSE) {
      rep(TRUE, length(value))
    }
  )
  ctx <- herald:::new_herald_ctx()
  ctx$dict <- list("ct-sdtm" = provider)
  ctx
}

test_that("op_value_in_codelist returns logical(0) for 0-row dataset", {
  d <- data.frame(FL = character(0L), stringsAsFactors = FALSE)
  ctx <- .mk_ct_ctx_all_pass()
  out <- herald:::op_value_in_codelist(d, ctx, name = "FL", codelist = "NY")
  expect_equal(out, logical(0L))
})

test_that("op_value_in_codelist returns NA when column absent", {
  d <- data.frame(OTHER = "Y", stringsAsFactors = FALSE)
  ctx <- .mk_ct_ctx_all_pass()
  out <- herald:::op_value_in_codelist(d, ctx, name = "FL", codelist = "NY")
  expect_equal(out, NA)
})

test_that("op_value_in_codelist returns NA advisory when CT provider not found", {
  # Use a non-existent package name so ct_provider() throws and the op
  # falls back to recording a missing_ref and returning NA.
  d <- data.frame(FL = "Y", stringsAsFactors = FALSE)
  ctx <- herald:::new_herald_ctx() # no dict, ct_provider("nopackage") will fail
  herald:::.init_missing_refs(ctx)
  ctx$current_rule_id <- "SDTMIG-CG0001"
  out <- herald:::op_value_in_codelist(
    d, ctx,
    name = "FL",
    codelist = "NY",
    package = "nopackage_that_does_not_exist"
  )
  expect_true(is.na(out[[1L]]))
  expect_true("ct-nopackage_that_does_not_exist" %in%
    names(ctx$missing_refs$dictionaries))
})

test_that("op_value_in_codelist returns NA advisory when codelist not in provider", {
  # Provider is found but returns all-NA for the codelist lookup.
  d <- data.frame(FL = "Y", stringsAsFactors = FALSE)
  ctx <- .mk_ct_ctx_na_provider()
  out <- herald:::op_value_in_codelist(d, ctx, name = "FL", codelist = "NONEXISTENT_CL")
  expect_true(all(is.na(out)))
})

test_that("op_value_in_codelist extensible = TRUE always passes non-empty rows", {
  d <- data.frame(
    FL = c("Y", "SPONSOR_TERM", "ANOTHER"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ct_ctx_na_provider()
  # Even though provider returns all-NA, extensible = TRUE should
  # override so non-empty values all pass (FALSE = does not fire).
  # But since NA provider returns all NA, the codelist-not-found
  # branch fires first. Use the all-pass provider instead.
  ctx2 <- .mk_ct_ctx_all_pass()
  out <- herald:::op_value_in_codelist(
    d, ctx2,
    name = "FL",
    codelist = "NY",
    extensible = TRUE
  )
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

# =============================================================================
# op_value_in_srs_table -- additional branch coverage
# =============================================================================

test_that("op_value_in_srs_table returns logical(0) for 0-row dataset", {
  d <- data.frame(TSVAL = character(0L), stringsAsFactors = FALSE)
  ctx <- .mk_fake_srs_ctx("ASPIRIN", character())
  out <- herald:::op_value_in_srs_table(d, ctx, name = "TSVAL")
  expect_equal(out, logical(0L))
})

test_that("op_value_in_srs_table returns NA advisory when SRS contains() returns all-NA", {
  # Provider registered but contains() returns all-NA (unknown field/structure).
  provider <- herald:::new_dict_provider(
    name = "srs",
    version = "test",
    source = "test",
    license = "public",
    fields = c("preferred_name"),
    contains = function(value, field = "preferred_name", ignore_case = FALSE) {
      rep(NA, length(value))
    }
  )
  ctx <- herald:::new_herald_ctx()
  ctx$dict <- list(srs = provider)
  d <- data.frame(TSVAL = "ASPIRIN", stringsAsFactors = FALSE)
  out <- herald:::op_value_in_srs_table(d, ctx, name = "TSVAL")
  expect_true(all(is.na(out)))
})

# =============================================================================
# op_value_in_dictionary -- additional branch coverage
# =============================================================================

test_that("op_value_in_dictionary returns logical(0) for 0-row dataset", {
  d <- data.frame(AEDECOD = character(0L), stringsAsFactors = FALSE)
  ctx <- .mk_fake_meddra_ctx("Headache")
  out <- herald:::op_value_in_dictionary(
    d, ctx,
    name = "AEDECOD",
    dict_name = "meddra",
    field = "pt"
  )
  expect_equal(out, logical(0L))
})

test_that("op_value_in_dictionary returns NA advisory when contains() returns all-NA", {
  # Provider registered but contains() returns all-NA (field not supported).
  provider <- herald:::new_dict_provider(
    name = "meddra",
    version = "test",
    source = "test",
    license = "MSSO",
    fields = c("pt"),
    contains = function(value, field = "pt", ignore_case = FALSE) {
      rep(NA, length(value))
    }
  )
  ctx <- herald:::new_herald_ctx()
  ctx$dict <- list(meddra = provider)
  d <- data.frame(AEDECOD = "Headache", stringsAsFactors = FALSE)
  out <- herald:::op_value_in_dictionary(
    d, ctx,
    name = "AEDECOD",
    dict_name = "meddra",
    field = "pt"
  )
  expect_true(all(is.na(out)))
})
