test_that("Cohort table names are built for one cohort", {
  expect_setequal(
    cohortTableNames("cohort_a"),
    c("cohort_a", "cohort_a_attrition", "cohort_a_codelist", "cohort_a_set")
  )
})

test_that("Cohort table names are built for several cohorts", {
  expect_setequal(
    cohortTableNames(c("cohort_a", "cohort_b")),
    c(
      "cohort_a", "cohort_a_attrition", "cohort_a_codelist", "cohort_a_set",
      "cohort_b", "cohort_b_attrition", "cohort_b_codelist", "cohort_b_set"
    )
  )
})