test_that("String vectors parse", {
  expect_equal(parseStringVector("amoxicillin"), "amoxicillin")
  expect_equal(parseStringVector("amoxicillin, aspirin"), c("amoxicillin", "aspirin"))
  expect_equal(parseStringVector("amoxicillin,,aspirin,"), c("amoxicillin", "aspirin"))
})