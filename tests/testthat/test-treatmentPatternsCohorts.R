combinedSettings <- data.frame(
  cohort_definition_id = c(1L, 2L, 3L, 4L),
  cohort_name = c("viral_sinusitis", "amoxicillin", "aspirin", "death")
)

test_that("Numbers parse and bad numbers error", {
  expect_equal(parseNumber("30", "minEraDuration"), 30)
  expect_equal(parseNumber("-30", "windowStart"), -30)
  expect_error(parseNumber("thirty", "minEraDuration"), "must be a number")
})

test_that("Pathway settings warn against best practice", {
  expect_silent(checkPathwaySettings(30, 30, 30))
  expect_warning(checkPathwaySettings(7, 30, 30), "minPostCombinationDuration")
  expect_warning(checkPathwaySettings(30, 7, 7), "combinationWindow")
})

test_that("Cohort types are built from the combined settings", {
  cohorts <- buildCohortTypes(
    combinedSettings,
    list(target = "viral_sinusitis", event = c("amoxicillin", "aspirin"), exit = "death")
  )
  expect_equal(
    cohorts,
    data.frame(
      cohortId = c(1L, 2L, 3L, 4L),
      cohortName = c("viral_sinusitis", "amoxicillin", "aspirin", "death"),
      type = c("target", "event", "event", "exit")
    )
  )
})

test_that("Exit cohorts are optional", {
  cohorts <- buildCohortTypes(
    combinedSettings,
    list(target = "viral_sinusitis", event = "amoxicillin", exit = character())
  )
  expect_equal(cohorts$type, c("target", "event"))
})

test_that("Bad cohort types error", {
  expect_error(
    buildCohortTypes(combinedSettings, list(target = character(), event = "amoxicillin")),
    "at least one target"
  )
  expect_error(
    buildCohortTypes(combinedSettings, list(target = "viral_sinusitis", event = character())),
    "at least one event"
  )
  expect_error(
    buildCohortTypes(combinedSettings, list(target = "viral_sinusitis", event = "viral_sinusitis")),
    "must be unique"
  )
  expect_error(
    buildCohortTypes(combinedSettings, list(target = "viral_sinusitis", event = "ibuprofen")),
    "not found"
  )
  expect_error(
    buildCohortTypes(combinedSettings, list(target = "viral_sinusitis", treatment = "aspirin")),
    "Unknown cohort type"
  )
})

test_that("Split cohort names map to event cohort IDs", {
  cohorts <- buildCohortTypes(
    combinedSettings,
    list(target = "viral_sinusitis", event = c("amoxicillin", "aspirin"), exit = "death")
  )
  expect_equal(cohortIdsFromNames(cohorts, c("aspirin", "amoxicillin")), c(3L, 2L))
  expect_error(cohortIdsFromNames(cohorts, "death"), "Not event cohorts")
  expect_error(cohortIdsFromNames(cohorts, "viral_sinusitis"), "Not event cohorts")
})