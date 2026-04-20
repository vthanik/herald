# -----------------------------------------------------------------------------
# test-fast-validate.R — end-to-end validate() entry
# -----------------------------------------------------------------------------

test_that("validate() errors when neither path nor files supplied", {
  expect_error(validate(), "path.*files")
})

test_that("validate() errors when path doesn't exist", {
  expect_error(validate("/no/such/path"), "does not exist")
})

test_that("validate() errors when files is not a named list of data frames", {
  expect_error(validate(files = list(1, 2)), "named list")
  expect_error(validate(files = list(DM = "not a df")), "data frames")
})

test_that("validate() runs end-to-end with a tiny fixture", {
  ie <- data.frame(
    STUDYID = c("S1", "S1", "S1"),
    USUBJID = c("S1-001", "S1-002", "S1-003"),
    IECAT   = c("INCLUSION", "INCLUSION", "EXCLUSION"),
    IEORRES = c("N", "Y", "Y"),
    stringsAsFactors = FALSE
  )
  r <- validate(files = list(IE = ie), quiet = TRUE)
  expect_s3_class(r, "herald_result")
  expect_true(r$rules_total > 0L)
  expect_true("IE" %in% r$datasets_checked)
  expect_s3_class(r$findings, "tbl_df")
})

test_that("validate() with rules filter runs only the selected rule", {
  d <- data.frame(USUBJID = c("S1", "", NA_character_),
                  stringsAsFactors = FALSE)
  # Pick a real rule id from the catalog; fall back if not available
  cat <- readRDS(system.file("rules", "rules.rds", package = "herald"))
  test_id <- cat$id[1]
  r <- validate(files = list(DM = d), rules = test_id, quiet = TRUE)
  expect_s3_class(r, "herald_result")
  expect_equal(r$rules_total, 1L)
})

test_that("validate() print banner works", {
  d <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  r <- validate(files = list(DM = d), rules = character(0), quiet = TRUE)
  # cli writes to stderr; expect_message catches it
  expect_message(print(r), "herald validation")
})

test_that("readiness_state covers all four banner states", {
  r0 <- new_herald_result(rules_applied = 0L, rules_total = 0L)
  expect_equal(readiness_state(r0), "Spec Checks Only")

  r1 <- new_herald_result(rules_applied = 5L, rules_total = 100L)
  expect_equal(readiness_state(r1), "Incomplete")

  f_high <- empty_findings()
  f_high <- rbind(f_high, tibble::tibble(
    rule_id = "X", authority = "CDISC", standard = "SDTM-IG",
    severity = "High", status = "fired",
    dataset = "AE", variable = NA_character_, row = 1L,
    value = NA_character_, expected = NA_character_,
    message = "x", source_url = NA_character_,
    p21_id_equivalent = NA_character_, license = NA_character_
  ))
  r_hi <- new_herald_result(rules_applied = 100L, rules_total = 100L,
                            findings = f_high)
  expect_equal(readiness_state(r_hi), "Issues Found")

  r_ok <- new_herald_result(rules_applied = 100L, rules_total = 100L)
  expect_equal(readiness_state(r_ok), "Submission Ready")
})

test_that("validate(files = list(dm, ae)) infers dataset names from symbols", {
  dm <- data.frame(USUBJID = "S1-001", stringsAsFactors = FALSE)
  ae <- data.frame(USUBJID = "S1-001", stringsAsFactors = FALSE)
  r <- validate(files = list(dm, ae), rules = character(0), quiet = TRUE)
  expect_setequal(r$datasets_checked, c("DM", "AE"))
})

test_that("validate(files = list(dm, AE = other)) mixes inferred + named", {
  dm    <- data.frame(USUBJID = "S1-001", stringsAsFactors = FALSE)
  other <- data.frame(USUBJID = "S1-001", stringsAsFactors = FALSE)
  r <- validate(files = list(dm, AE = other),
                rules = character(0), quiet = TRUE)
  expect_setequal(r$datasets_checked, c("DM", "AE"))
})

test_that("validate(files = list(<inline expr>)) errors with a helpful message", {
  # All-inline: falls through to the standard named-list error.
  expect_error(
    validate(
      files = list(data.frame(USUBJID = "S1-001", stringsAsFactors = FALSE)),
      rules = character(0), quiet = TRUE
    ),
    "named list"
  )
  # Mixed bare + inline: surfaces the "bare variable" guidance.
  dm <- data.frame(USUBJID = "S1-001", stringsAsFactors = FALSE)
  expect_error(
    validate(
      files = list(dm,
                   data.frame(USUBJID = "S1-001", stringsAsFactors = FALSE)),
      rules = character(0), quiet = TRUE
    ),
    "bare variable"
  )
})
