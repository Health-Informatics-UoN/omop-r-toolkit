test_that("Single window string parses to list", {
  expect_equal(parseWindows("-365,-1"), list(c(-365, -1)))
  expect_equal(parseWindows("0,30"), list(c(0, 30)))
  expect_equal(parseWindows("-Inf,-1"), list(c(-Inf, -1)))
  expect_equal(parseWindows("1, Inf"), list(c(1, Inf)))
})

test_that("Single JSON array window parses", {
  expect_equal(parseWindows("[-365, 0]"), list(c(-365, 0)))
  expect_equal(parseWindows("[0, 17]"), list(c(0, 17)))
})

test_that("JSON array of windows parses", {
  expect_equal(parseWindows("[[-365,0],[0,365]]"), list(c(-365, 0), c(0, 365)))
  expect_equal(parseWindows("[[0,17],[18,65],[66,150]]"), list(c(0, 17), c(18, 65), c(66, 150)))
})

test_that("JSON named windows parses", {
  res <- parseWindows('{"before": [-365, 0], "after": [0, 365]}')
  expect_equal(res, list("before" = c(-365, 0), "after" = c(0, 365)))
})

test_that("Bad windows error", {
  expect_error(parseWindows("10"), "pair")
  expect_error(parseWindows("a,b"), "Cannot parse")
  expect_error(parseWindows("[[0]]"), "pair of numbers")
  expect_error(parseWindows('{"x": [1]}'), "must be a pair")
})

# Rscript -e 'pkgload::load_all(); testthat::test_dir("tests/testthat")'