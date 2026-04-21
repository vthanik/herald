
test_that("scalar compare ops return NA when value is a multi-element vector", {
  d <- data.frame(x = c(1, 2, 3), stringsAsFactors = FALSE)
  # Simulating a $-ref that resolved to multiple values -- scalar compare
  # can't express join-by-key; should advisory, not fire per row.
  expect_equal(op_equal_to(d, NULL, "x", c(1, 2, 3)), rep(NA, 3L))
  expect_equal(op_not_equal_to(d, NULL, "x", c(1, 2, 3)), rep(NA, 3L))
  expect_equal(op_greater_than(d, NULL, "x", c(1, 2)), rep(NA, 3L))
  # Scalar value still works normally.
  expect_equal(op_equal_to(d, NULL, "x", 2), c(FALSE, TRUE, FALSE))
})
