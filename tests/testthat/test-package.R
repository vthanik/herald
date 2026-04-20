test_that("package loads", {
  expect_true("herald" %in% loadedNamespaces())
})
