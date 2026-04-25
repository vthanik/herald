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
    herald_error_runtime(
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
    df_cols <- lapply(cols, function(v) {
      # JSON nulls arrive as NULL entries in a list -- promote to NA.
      if (is.list(v)) {
        v <- lapply(v, function(x) if (is.null(x)) NA else x)
      }
      unlist(v, use.names = FALSE)
    })
    as.data.frame(df_cols, stringsAsFactors = FALSE, check.names = FALSE)
  })
  names(out) <- toupper(names(out))
  out
}

#' Build a minimal `herald_spec` from a fixture's `spec.class_map` field, or
#' NULL when the fixture carries no class mapping.
#' @noRd
.fixture_spec <- function(fx) {
  cm <- fx$spec$class_map
  if (is.null(cm) || length(cm) == 0L) return(NULL)
  nms <- names(cm)
  classes <- vapply(cm, function(x) as.character(x)[[1L]], character(1L))
  structure(
    list(
      ds_spec = data.frame(
        dataset = toupper(nms),
        class   = unname(classes),
        stringsAsFactors = FALSE
      )
    ),
    class = c("herald_spec", "list")
  )
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
    spec  = .fixture_spec(fx),
    rules = fx$rule_id,
    quiet = TRUE
  )

  # Rule may have been superseded (dedup pass) and is no longer in rules.rds.
  # Skip gracefully instead of failing -- a skip is visible in CI.
  if (isTRUE(res$rules_applied == 0L)) {
    testthat::skip(sprintf("rule %s not in catalog (superseded or not yet authored)",
                           fx$rule_id))
  }

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
