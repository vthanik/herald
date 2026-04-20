# -----------------------------------------------------------------------------
# fixture-runner.R -- internal helpers for the golden-fixture test runner
# -----------------------------------------------------------------------------
# Fixtures live under tests/testthat/fixtures/golden/<authority>/<rule_id>/
# as compact custom JSON (NOT Dataset-JSON). Each file encodes a single
# (rule, fixture_type) pair and declares the expected outcome.
#
# Schema:
# {
#   "rule_id":      "CORE-000172",
#   "fixture_type": "positive" | "negative",
#   "datasets":     { "<DS>": { "<COL>": [<values>], ... }, ... },
#   "expected":     { "fires": true|false, "rows": [1, 2] },
#   "notes":        "short prose",
#   "authored":     "auto-seed@v1" | "manual"
# }

#' Read a fixture JSON file into a parsed list.
#' @noRd
.read_fixture <- function(path) {
  fx <- jsonlite::read_json(path, simplifyVector = FALSE)
  req <- c("rule_id", "fixture_type", "datasets", "expected")
  missing <- setdiff(req, names(fx))
  if (length(missing) > 0L) {
    cli::cli_abort(
      "Fixture {.path {path}} is missing field{?s}: {.val {missing}}."
    )
  }
  fx$`_path` <- path
  fx
}

#' Convert a fixture's `datasets` list (columns-of-vectors) to a named
#' list of data.frames keyed by dataset name.
#' @noRd
.fixture_datasets <- function(fx) {
  out <- lapply(fx$datasets, function(cols) {
    # cols is a list: column name -> list of values
    df_cols <- lapply(cols, function(v) {
      vals <- unlist(v, use.names = FALSE)
      # JSON nulls come in as NULL entries -- preserve as NA
      if (is.list(v)) {
        vals <- vapply(v, function(x) if (is.null(x)) NA else x,
                       FUN.VALUE = NA)
      }
      vals
    })
    as.data.frame(df_cols, stringsAsFactors = FALSE, check.names = FALSE)
  })
  names(out) <- toupper(names(out))
  out
}

#' Run a fixture and assert the expected outcome against validate().
#'
#' Uses testthat expectations so a failure surfaces at the enclosing
#' `test_that()` call in the parameterised runner.
#' @noRd
.assert_fixture <- function(fx) {
  datasets <- .fixture_datasets(fx)
  res <- validate(
    files = datasets,
    rules = fx$rule_id,
    quiet = TRUE
  )

  fired <- res$findings[res$findings$status == "fired", , drop = FALSE]
  fires <- isTRUE(fx$expected$fires)

  if (fires) {
    testthat::expect_gt(
      nrow(fired), 0L,
      label = sprintf("fixture %s positive: rule %s should fire",
                      basename(dirname(fx$`_path`)), fx$rule_id)
    )
    exp_rows <- unlist(fx$expected$rows, use.names = FALSE)
    if (length(exp_rows) > 0L) {
      testthat::expect_true(
        all(exp_rows %in% fired$row),
        label = sprintf(
          "fixture %s positive: expected row(s) %s to be in fired %s",
          fx$rule_id,
          toString(exp_rows),
          toString(sort(unique(fired$row)))
        )
      )
    }
  } else {
    testthat::expect_equal(
      nrow(fired), 0L,
      label = sprintf("fixture %s negative: rule %s should NOT fire",
                      fx$rule_id, fx$rule_id)
    )
  }
  invisible(res)
}

#' List all fixture JSON files under `base_dir`, sorted for deterministic
#' test order.
#' @noRd
.list_fixtures <- function(base_dir) {
  if (!dir.exists(base_dir)) return(character())
  files <- list.files(
    base_dir,
    pattern     = "\\.json$",
    recursive   = TRUE,
    full.names  = TRUE,
    ignore.case = TRUE
  )
  sort(files)
}
