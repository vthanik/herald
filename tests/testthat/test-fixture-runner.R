# -----------------------------------------------------------------------------
# test-fixture-runner.R -- parameterised runner for golden fixtures
# -----------------------------------------------------------------------------
# Walks tools/rule-authoring/fixtures/, loads every fixture JSON, and
# calls .assert_fixture() on each. Each fixture becomes its own
# test_that() so failures report the rule id + positive/negative type.

# -- helpers ------------------------------------------------------------------

.read_fixture <- function(path) {
  fx <- jsonlite::read_json(path, simplifyVector = FALSE)
  req <- c("rule_id", "fixture_type", "datasets", "expected")
  missing <- setdiff(req, names(fx))
  if (length(missing) > 0L) {
    stop(sprintf("Fixture %s is missing field(s): %s", path,
                 paste(missing, collapse = ", ")))
  }
  fx$`_path` <- path
  fx
}

.fixture_datasets <- function(fx) {
  out <- lapply(fx$datasets, function(cols) {
    df_cols <- lapply(cols, function(v) {
      if (is.list(v)) v <- lapply(v, function(x) if (is.null(x)) NA else x)
      unlist(v, use.names = FALSE)
    })
    as.data.frame(df_cols, stringsAsFactors = FALSE, check.names = FALSE)
  })
  names(out) <- toupper(names(out))
  out
}

.fixture_spec <- function(fx) {
  cm <- fx$spec$class_map
  if (is.null(cm) || length(cm) == 0L) return(NULL)
  nms     <- names(cm)
  classes <- vapply(cm, function(x) as.character(x)[[1L]], character(1L))
  structure(
    list(ds_spec = data.frame(dataset = toupper(nms), class = unname(classes),
                              stringsAsFactors = FALSE)),
    class = c("herald_spec", "list")
  )
}

.fixture_dictionaries <- function() {
  fields <- c("pt", "pt_code", "llt", "llt_code", "hlt", "hlt_code",
              "hlgt", "hlgt_code", "soc", "soc_code", "drug", "code",
              "preferred_name")
  make <- function(name) {
    tbl <- as.data.frame(stats::setNames(rep(list("VALID"), length(fields)), fields),
                         stringsAsFactors = FALSE)
    custom_provider(tbl, name = name, fields = fields)
  }
  list(
    meddra  = make("meddra"),
    whodrug = make("whodrug"),
    srs     = make("srs"),
    loinc   = make("loinc"),
    snomed  = make("snomed")
  )
}

.assert_fixture <- function(fx) {
  datasets <- .fixture_datasets(fx)
  res <- validate(files = datasets, spec = .fixture_spec(fx),
                  rules = fx$rule_id, quiet = TRUE,
                  dictionaries = .fixture_dictionaries())

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
        label = sprintf("fixture %s positive: expected row(s) %s in fired %s",
                        fx$rule_id, toString(exp_rows),
                        toString(sort(unique(fired$row))))
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

.list_fixtures <- function(base_dir) {
  if (!dir.exists(base_dir)) return(character())
  sort(list.files(base_dir, pattern = "\\.json$", recursive = TRUE,
                  full.names = TRUE, ignore.case = TRUE))
}

# -- runner -------------------------------------------------------------------

fx_dir <- file.path(
  dirname(dirname(normalizePath(testthat::test_path("."), mustWork = FALSE))),
  "tools", "rule-authoring", "fixtures"
)

if (dir.exists(fx_dir)) {
  fixture_paths <- .list_fixtures(fx_dir)

  for (p in fixture_paths) {
    fx <- .read_fixture(p)
    label <- sprintf("golden fixture %s [%s]", fx$rule_id, fx$fixture_type)
    test_that(label, {
      .assert_fixture(fx)
    })
  }

  test_that("golden fixtures can all be parsed", {
    expect_true(length(fixture_paths) >= 0L)
    for (p in fixture_paths) {
      expect_no_error(.read_fixture(p))
    }
  })
}
