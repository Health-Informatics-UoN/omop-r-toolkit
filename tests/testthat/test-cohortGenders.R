test_that("Cohort genders correct", {
  expect_equal(cohortGenders(TRUE, TRUE, TRUE), c("Both", "Female", "Male"))
  expect_equal(cohortGenders(TRUE, TRUE, FALSE), c("Both", "Female"))
  expect_equal(cohortGenders(TRUE, FALSE, FALSE), "Both")
  expect_equal(cohortGenders(TRUE, FALSE, TRUE), c("Both", "Male"))
  expect_equal(cohortGenders(FALSE, TRUE, TRUE), c("Female", "Male"))
  expect_equal(cohortGenders(FALSE, TRUE, FALSE), "Female")
  expect_equal(cohortGenders(FALSE, FALSE, TRUE), "Male")
})