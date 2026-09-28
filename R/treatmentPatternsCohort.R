#' TreatmentPatterns expects all cohorts to be in a single cohort table, plus a data frame labelling
#' each cohort as "target", "event" or "exit".
#' In this toolkit, target, event and exit cohorts are defined in separate tables, so each can use its own
#' cohort settings (e.g. first occurrence until observation end for the target, all occurrences until
#' event end for treatments). The script binds them into one table, and these helpers check and label them.

parseNumber <- function(value, argName) {
  number <- suppressWarnings(as.numeric(value))
  if (is.na(number)) {
    stop(sprintf("--%s must be a number, got: %s", argName, value))
  }
  number
}

#' Warn when settings go against the TreatmentPatterns best-practice guidance:
#' minPostCombinationDuration <= minEraDuration and combinationWindow >= minEraDuration
checkPathwaySettings <- function(minEraDuration, combinationWindow, minPostCombinationDuration) {
  if (minPostCombinationDuration > minEraDuration) {
    warning(sprintf(
      "minPostCombinationDuration (%s) is greater than minEraDuration (%s). TreatmentPatterns guidance is minPostCombinationDuration <= minEraDuration.",
      minPostCombinationDuration,
      minEraDuration
    ), call. = FALSE)
  }
  if (combinationWindow < minEraDuration) {
    warning(sprintf(
      "combinationWindow (%s) is less than minEraDuration (%s). TreatmentPatterns guidance is combinationWindow >= minEraDuration.",
      combinationWindow,
      minEraDuration
    ), call. = FALSE)
  }
  invisible(TRUE)
}

checkDistinctCohortNames <- function(cohortNamesByType) {
  allNames <- unlist(cohortNamesByType, use.names = FALSE)
  duplicates <- unique(allNames[duplicated(allNames)])
  if (length(duplicates) > 0) {
    stop(sprintf(
      "Cohort names must be unique across the target, event and exit tables. Duplicated: %s",
      paste(duplicates, collapse = ", ")
    ))
  }
  invisible(cohortNamesByType)
}

#' Build the cohorts data frame TreatmentPatterns needs (cohortId, cohortName, type)
#' cohortSettings: settings of the combined cohort table (cohort_definition_id, cohort_name)
#' cohortNamesByType: list(target = <names>, event = <names>, exit = <names>)
buildCohortTypes <- function(cohortSettings, cohortNamesByType) {
  unknownTypes <- setdiff(names(cohortNamesByType), c("target", "event", "exit"))
  if (length(unknownTypes) > 0) {
    stop(sprintf("Unknown cohort type(s): %s", paste(unknownTypes, collapse = ", ")))
  }
  if (length(cohortNamesByType$target) == 0) {
    stop("You need at least one target cohort")
  }
  if (length(cohortNamesByType$event) == 0) {
    stop("You need at least one event cohort")
  }
  checkDistinctCohortNames(cohortNamesByType)

  cohortNames <- unlist(cohortNamesByType, use.names = FALSE)
  missingNames <- setdiff(cohortNames, cohortSettings$cohort_name)
  if (length(missingNames) > 0) {
    stop(sprintf(
      "Cohorts not found in the combined cohort table: %s",
      paste(missingNames, collapse = ", ")
    ))
  }

  data.frame(
    cohortId = as.integer(cohortSettings$cohort_definition_id[match(cohortNames, cohortSettings$cohort_name)]),
    cohortName = cohortNames,
    type = rep(names(cohortNamesByType), lengths(cohortNamesByType))
  )
}

#' Look up cohort IDs by name, checking they are of the expected type.
#' Used for splitEventCohorts, because cohort IDs are reassigned when tables are combined.
cohortIdsFromNames <- function(cohorts, cohortNames, type = "event") {
  typedCohorts <- cohorts[cohorts$type == type, ]
  missingNames <- setdiff(cohortNames, typedCohorts$cohortName)
  if (length(missingNames) > 0) {
    stop(sprintf(
      "Not %s cohorts: %s",
      type,
      paste(missingNames, collapse = ", ")
    ))
  }
  typedCohorts$cohortId[match(cohortNames, typedCohorts$cohortName)]
}