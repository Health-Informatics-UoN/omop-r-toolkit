test_that("dates parse", {
  expect_equal(parseDates("2026-08-17"), as.Date("2026-08-17"))
  expect_equal(parseDates("2026-08-17,2021-09-25"), as.Date(c("2026-08-17", "2021-09-25")))
  expect_equal(parseDates("2026-08-17,2021-09-25,2023-02-08"), as.Date(c("2026-08-17", "2021-09-25", "2023-02-08")))
})

test_that("The right number of dates will parse", {
  expect_equal(parseNDates("2026-08-17", 1), as.Date("2026-08-17"))
  expect_equal(parseNDates("2026-08-17,2021-09-25", 2), as.Date(c("2026-08-17", "2021-09-25")))
  expect_equal(parseNDates("2026-08-17,2021-09-25,2023-02-08", 3), as.Date(c("2026-08-17", "2021-09-25", "2023-02-08")))
})

test_that("The wrong number of dates will error", {
  expect_error(parseNDates("2026-08-17", 2), "When parsing dates")
  expect_error(parseNDates("2026-08-17,2021-09-25", 1), "When parsing dates")
  expect_error(parseNDates("2026-08-17,2021-09-25", 3), "When parsing dates")
  expect_error(parseNDates("2026-08-17,2021-09-25,2023-02-08", 2), "When parsing dates")
  expect_error(parseNDates("2026-08-17,2021-09-25,2023-02-08", 4), "When parsing dates")
})