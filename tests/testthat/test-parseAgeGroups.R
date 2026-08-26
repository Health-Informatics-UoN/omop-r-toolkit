test_that("Age groups parse as expected", {
  expect_equal(parseAgeGroups('[[0,150]]'), list(c(0,150)))
  expect_equal(parseAgeGroups('[[0,17],[18,30]]'), list(c(0,17), c(18,30)))
  expect_equal(parseAgeGroups('[[0,17],[18,30],[31,60]]'), list(c(0,17), c(18,30), c(31,60)))
})

test_that("Bad age groups don't parse", {
  expect_error(parseAgeGroups('[[0]]'), "Age groups need to be pairs")
  expect_error(parseAgeGroups('[[0, 17, 30]]'), "Age groups need to be pairs")
  expect_error(parseAgeGroups('[[0, 17, 30], [31,60]]'), "Age groups need to be pairs")
  expect_error(parseAgeGroups('[[0,"150"]]'), "Age group values need to be integer")
})