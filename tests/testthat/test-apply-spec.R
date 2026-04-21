# Tests for R/apply-spec.R -- pre-validation attribute stamper.

.test_spec <- function() {
  as_herald_spec(
    ds_spec = data.frame(
      dataset = c("DM", "AE"),
      class   = c("SPECIAL PURPOSE", "EVENTS"),
      label   = c("Demographics", "Adverse Events"),
      stringsAsFactors = FALSE
    ),
    var_spec = data.frame(
      dataset  = c("DM", "DM", "DM", "AE"),
      variable = c("USUBJID", "AGE", "AGEU", "AEDECOD"),
      type     = c("text", "integer", "text", "text"),
      label    = c("Unique Subject Identifier", "Age", "Age Unit",
                   "Dictionary-Derived Term"),
      format   = c("", "", "", ""),
      length   = c(40L, 8L, 6L, 200L),
      stringsAsFactors = FALSE
    )
  )
}

test_that("apply_spec() stamps dataset and column labels", {
  dm <- data.frame(USUBJID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  out <- apply_spec(list(DM = dm), .test_spec())

  expect_equal(attr(out$DM, "label"), "Demographics")
  expect_equal(attr(out$DM$USUBJID, "label"), "Unique Subject Identifier")
  expect_equal(attr(out$DM$AGE,     "label"), "Age")
})

test_that("apply_spec() stamps length and xpt_type from var_spec", {
  dm <- data.frame(USUBJID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  out <- apply_spec(list(DM = dm), .test_spec())

  expect_equal(attr(out$DM$USUBJID, "sas.length"), 40L)
  expect_equal(attr(out$DM$AGE,     "sas.length"), 8L)
  expect_equal(attr(out$DM$USUBJID, "xpt_type"),   "text")
  expect_equal(attr(out$DM$AGE,     "xpt_type"),   "integer")
})

test_that("apply_spec() overwrites existing attrs when spec has a value", {
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  attr(dm$USUBJID, "label") <- "stale label"
  out <- apply_spec(list(DM = dm), .test_spec())

  expect_equal(attr(out$DM$USUBJID, "label"), "Unique Subject Identifier")
})

test_that("apply_spec() leaves unknown columns and datasets untouched", {
  dm <- data.frame(USUBJID = "S1", FOO = "bar", stringsAsFactors = FALSE)
  out <- apply_spec(list(DM = dm, EX = data.frame(x = 1)), .test_spec())

  expect_null(attr(out$DM$FOO, "label"))
  expect_null(attr(out$EX, "label"))
  expect_null(attr(out$EX$x, "label"))
})

test_that("apply_spec() matches dataset + variable names case-insensitively", {
  dm <- data.frame(usubjid = "S1", stringsAsFactors = FALSE)
  out <- apply_spec(list(dm = dm), .test_spec())

  expect_equal(attr(out$dm$usubjid, "label"), "Unique Subject Identifier")
})

test_that("apply_spec() skips empty-string labels without clobbering", {
  spec <- as_herald_spec(
    ds_spec = data.frame(dataset = "DM", label = "",
                         stringsAsFactors = FALSE),
    var_spec = data.frame(
      dataset  = "DM",
      variable = "USUBJID",
      label    = "",
      stringsAsFactors = FALSE
    )
  )
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  attr(dm, "label") <- "pre-existing"
  attr(dm$USUBJID, "label") <- "pre-existing col"

  out <- apply_spec(list(DM = dm), spec)
  expect_equal(attr(out$DM, "label"),          "pre-existing")
  expect_equal(attr(out$DM$USUBJID, "label"),  "pre-existing col")
})

test_that("apply_spec() errors on non-list / non-spec inputs", {
  expect_error(
    apply_spec("nope", .test_spec()),
    class = "herald_error_input"
  )
  expect_error(
    apply_spec(list(DM = data.frame(x = 1)), "nope"),
    class = "herald_error_input"
  )
  expect_error(
    apply_spec(list(data.frame(x = 1)), .test_spec()),  # no names
    class = "herald_error_input"
  )
})

test_that("apply_spec() skips non-data-frame elements gracefully", {
  out <- apply_spec(list(DM = data.frame(USUBJID = "S1"),
                         NOTDF = list(a = 1)),
                    .test_spec())
  expect_equal(attr(out$DM$USUBJID, "label"), "Unique Subject Identifier")
  expect_equal(out$NOTDF, list(a = 1))
})
