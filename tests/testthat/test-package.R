test_that("package loads", {
  expect_true("herald" %in% loadedNamespaces())
})

test_that("herald exports core IO functions", {
  exports <- getNamespaceExports("herald")
  core_fns <- c("read_xpt", "write_xpt", "read_json", "write_json", "validate")
  expect_true(all(core_fns %in% exports))
})

test_that("herald version is a package_version", {
  expect_s3_class(packageVersion("herald"), "package_version")
})
