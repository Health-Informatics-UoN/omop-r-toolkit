test_that("Valid choices pass through", {
  expect_equal(checkChoice("First", c("First", "Changes", "All"), "filterTreatments"), "First")
  expect_equal(checkChoice(c("missing", "dose"), c("missing", "dose", "route"), "checks"), c("missing", "dose"))
})

test_that("Invalid choices error", {
  expect_error(checkChoice("first", c("First", "Changes", "All"), "filterTreatments"), "Invalid --filterTreatments")
  expect_error(checkChoice(c("missing", "doze"), c("missing", "dose"), "checks"), "doze")
  expect_error(checkChoice(character(), "missing", "checks"), "at least one value")
})