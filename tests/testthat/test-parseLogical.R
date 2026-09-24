test_that("parseLogical parses supported CLI values", {
  expect_true(parseLogical("TRUE"))
  expect_true(parseLogical(" yes "))
  expect_true(parseLogical("1"))
  expect_false(parseLogical("FALSE"))
  expect_false(parseLogical("no"))
  expect_false(parseLogical("0"))
})

test_that("parseLogical leaves omitted values unspecified", {
  expect_null(parseLogical(NULL))
  expect_null(parseLogical(""))
  expect_null(parseLogical("NULL"))
})

test_that("parseLogical rejects invalid supplied values", {
  expect_error(parseLogical("treu"), "Invalid logical value")
  expect_error(parseLogical("maybe"), "Invalid logical value")
  expect_error(parseLogical(NA), "Invalid logical value")
  expect_error(parseLogical(c("true", "false")), "Invalid logical value")
})