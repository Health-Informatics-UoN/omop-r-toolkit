test_that("multipleEvents parses correctly", {
  expect_null(parseMultipleEvents("null"))
  expect_null(parseMultipleEvents("NULL"))
  expect_true(parseMultipleEvents("true"))
  expect_true(parseMultipleEvents("TRUE"))
  expect_equal(parseMultipleEvents("osteoarthritis,diverticular_disease"),
               c("osteoarthritis", "diverticular_disease"))
})