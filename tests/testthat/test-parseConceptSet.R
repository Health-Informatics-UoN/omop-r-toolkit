test_that("Concept sets parse OK", {
  expect_equal(parseJSONConceptSet('{"pretend cohort": [82828, 3728]}'), list("pretend cohort" = c(82828, 3728)))
  expect_equal(
    parseJSONConceptSet('{"pretend cohort": [82828, 3728], "a second pretend cohort": [493287, 437289]}'),
    list("pretend cohort" = c(82828, 3728), "a second pretend cohort" = c(493287, 437289))
  )
})

test_that("Bad concept sets get thrown out", {
  expect_error(parseJSONConceptSet('{"pretend cohort": ["cancer", "earache"]}'))
})