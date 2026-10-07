test_that("Strata parse to a list of character vectors", {
  expect_equal(parseStrata('["sex", ["age", "sex"]]'), list("sex", c("age", "sex")))
  expect_equal(parseStrata('["age", "sex"]'), list("age", "sex"))
  expect_equal(parseStrata('[["age", "sex"]]'), list(c("age", "sex")))
  expect_error(parseStrata('["age", ["age", "sex"], [["age", "sex"]]]'))
})