# Tests for R/parquet-read.R (read_parquet function).

test_that("read_parquet errors when the file is missing", {
  skip_if_not_installed("arrow")
  expect_error(
    read_parquet("/definitely/not/here.parquet"),
    class = "herald_error_io"
  )
})

# Note: a mocked-requireNamespace() test was considered for the "arrow not
# installed" path but the file.exists() check fires first in read_parquet()
# so it adds no real coverage. Left as documentation-only behaviour.
