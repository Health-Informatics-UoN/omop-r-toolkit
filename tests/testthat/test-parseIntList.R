test_that("Parsing lists of integers works", {
  expect_equal(parseNInts("0", 1), 0)
  expect_error(parseNInts("0",2), "Expected")
  expect_equal(parseNInts("0,0", 2), c(0,0))
  expect_error(parseNInts("0,0",1), "Expected")
  expect_error(parseNInts("0,0",3), "Expected")
})