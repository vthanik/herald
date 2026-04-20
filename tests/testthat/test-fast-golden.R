# -----------------------------------------------------------------------------
# test-fast-golden.R -- parameterised runner for golden fixtures
# -----------------------------------------------------------------------------
# Walks tests/testthat/fixtures/golden/, loads every fixture JSON, and
# calls .assert_fixture() on each. Each fixture becomes its own
# test_that() so failures report the rule id + positive/negative type.

fx_dir <- testthat::test_path("fixtures", "golden")

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
