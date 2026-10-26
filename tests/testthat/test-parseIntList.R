test_that("Parsing lists of integers works", {
  expect_equal(parseStringAsInts("0", 1), 0)
  expect_error(parseStringAsInts("0",2), "Expected")
  expect_equal(parseStringAsInts("0,0", 2), c(0,0))
  expect_error(parseStringAsInts("0,0",1), "Expected")
  expect_error(parseStringAsInts("0,0",3), "Expected")
})

test_that("Trying to parse non-integer numbers throws errors", {
  expect_error(parseStringAsInts("0.1", 1), "integers")
  expect_error(parseStringAsInts("0, 0.1", 2), "integers")
})

test_that("Trying to parse integers outside limits fails", {
  expect_error(parseStringAsInts("-1, 0, 4", 3, 0), "lower")
  expect_error(parseStringAsInts("1, 0, 100", 3, -Inf, 99), "upper")
})