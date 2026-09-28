# This script runs a basic workflow of using the [TreatmentPatterns](https://darwin-eu-dev.github.io/TreatmentPatterns/) package
# 1. Bind the target, event and (optional) exit cohort tables into one cohort table
# 2. computePathways
# 3. export the aggregate, disclosure-controlled results
# Patient-level export (exportPatientLevel) and plotting are deliberately not supported, as this runs eyes-off in a TRE.


'Compute treatment pathways with TreatmentPatterns and export aggregate results.

Usage:
  treatmentPatterns.R --targetCohortTable=<table> --eventCohortTable=<table> [options]

Options:
  -h --help                                Show this screen
  --version                                Show version
  --targetCohortTable=<table>              Cohort table holding the target cohort(s), e.g. a disease
  --eventCohortTable=<table>               Cohort table holding the event cohorts, e.g. treatments
  --exitCohortTable=<table>                Optional cohort table holding exit cohorts, e.g. death
  --combinedCohortTable=<table>            Name of the table the cohorts are combined into. Dropped at the end [default: tp_cohorts]
  --output-path=<path>                     Directory to write output csvs to [default: outputs/treatment_patterns/]
  --archiveName=<name>                     Optional name of a zip file (in the output directory) to bundle the csvs into
  --analysisId=<id>                        Analysis identifier [default: 1]
  --description=<text>                     Analysis description [default: Treatment Patterns analysis]
  --startAnchor=<anchor>                   Anchor for the window start. One of startDate, endDate [default: startDate]
  --windowStart=<days>                     Offset in days from startAnchor [default: 0]
  --endAnchor=<anchor>                     Anchor for the window end. One of startDate, endDate [default: endDate]
  --windowEnd=<days>                       Offset in days from endAnchor [default: 0]
  --splitEventCohorts=<names>              Optional comma-separated event cohort names to split into acute and therapy
  --splitTime=<days>                       Days classified as acute before therapy. One value, or one per split cohort
  --minEraDuration=<days>                  Minimum duration of an event era [default: 30]
  --filterTreatments=<method>              One of First, Changes, All [default: First]
  --eraCollapseSize=<days>                 Gap within which repeated eras of the same event are collapsed [default: 30]
  --combinationWindow=<days>               Minimum overlap for two events to count as a combination [default: 30]
  --minPostCombinationDuration=<days>      Minimum duration of eras left after splitting out a combination [default: 30]
  --overlapMethod=<method>                 How to handle non-significant overlap. One of truncate, keep [default: truncate]
  --maxPathLength=<n>                      Maximum number of steps in a pathway [default: 5]
  --concatTargets=<logical>                Concatenate multiple target cohort entries per person [default: TRUE]
  --minCellCount=<n>                       Minimum cell count for disclosure control [default: 5]
  --censorType=<type>                      How to censor counts below minCellCount. One of minCellCount, remove, mean [default: minCellCount]
  --ageWindow=<ages>                       Age group width in years, or comma-separated age breaks (e.g. 0,18,65,150) [default: 10]
  --nonePaths                              Include pathways where no events occurred
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(TreatmentPatterns)
library(CDMConnector)
library(omopgenerics)
source("R/postgres-connect-5s-tes.R")
source("R/cleanCohortTables.R")
source("R/parseIntList.R")
source("R/treatmentPatternsCohorts.R")

arguments <- docopt(doc, version = "Treatment Patterns 0.1.0")

# ---- Parse and validate arguments before connecting to the database ----
startAnchor <- checkChoice(arguments$startAnchor, c("startDate", "endDate"), "startAnchor")
endAnchor <- checkChoice(arguments$endAnchor, c("startDate", "endDate"), "endAnchor")
filterTreatments <- checkChoice(arguments$filterTreatments, c("First", "Changes", "All"), "filterTreatments")
overlapMethod <- checkChoice(arguments$overlapMethod, c("truncate", "keep"), "overlapMethod")
censorType <- checkChoice(arguments$censorType, c("minCellCount", "remove", "mean"), "censorType")

analysisId <- parseNumber(arguments$analysisId, "analysisId")
windowStart <- parseNumber(arguments$windowStart, "windowStart")
windowEnd <- parseNumber(arguments$windowEnd, "windowEnd")
minEraDuration <- parseNumber(arguments$minEraDuration, "minEraDuration")
eraCollapseSize <- parseNumber(arguments$eraCollapseSize, "eraCollapseSize")
combinationWindow <- parseNumber(arguments$combinationWindow, "combinationWindow")
minPostCombinationDuration <- parseNumber(arguments$minPostCombinationDuration, "minPostCombinationDuration")
maxPathLength <- parseNumber(arguments$maxPathLength, "maxPathLength")
minCellCount <- parseNumber(arguments$minCellCount, "minCellCount")
ageWindow <- parseIntegerVector(arguments$ageWindow)

concatTargets <- as.logical(arguments$concatTargets)
if (is.na(concatTargets)) {
  stop("--concatTargets must be TRUE or FALSE")
}

checkPathwaySettings(minEraDuration, combinationWindow, minPostCombinationDuration)

splitEventCohortNames <- if (is.null(arguments$splitEventCohorts)) NULL else parseStringVector(arguments$splitEventCohorts)
splitTime <- if (is.null(arguments$splitTime)) NULL else parseIntegerVector(arguments$splitTime)
if (xor(is.null(splitEventCohortNames), is.null(splitTime))) {
  stop("--splitEventCohorts and --splitTime must be specified together")
}
if (!is.null(splitTime) && !length(splitTime) %in% c(1, length(splitEventCohortNames))) {
  stop("--splitTime must have one value, or one value per cohort in --splitEventCohorts")
}

combinedCohortTable <- arguments$combinedCohortTable
cohortTableNames <- c(arguments$targetCohortTable, arguments$eventCohortTable, arguments$exitCohortTable)
if (anyDuplicated(cohortTableNames)) {
  stop("Target, event and exit cohorts must be in different tables. Define them with separate defineConceptCohortSet runs.")
}
if (combinedCohortTable %in% cohortTableNames) {
  stop("--combinedCohortTable must not be the same as an input cohort table, as it is dropped at the end")
}

output_dir <- arguments$output_path
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# ---- Combine cohorts into one table ----
cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = cohortTableNames)

cohortNamesByType <- list(
  target = omopgenerics::settings(cdm[[arguments$targetCohortTable]])$cohort_name,
  event = omopgenerics::settings(cdm[[arguments$eventCohortTable]])$cohort_name,
  exit = if (is.null(arguments$exitCohortTable)) character() else omopgenerics::settings(cdm[[arguments$exitCohortTable]])$cohort_name
)
checkDistinctCohortNames(cohortNamesByType)

# bind() reassigns cohort_definition_id, so cohorts are matched back to their type by name
cohortTablesToBind <- lapply(cohortTableNames, function(tableName) cdm[[tableName]])
cdm[[combinedCohortTable]] <- do.call(
  omopgenerics::bind,
  c(cohortTablesToBind, list(name = combinedCohortTable))
)

cohorts <- buildCohortTypes(omopgenerics::settings(cdm[[combinedCohortTable]]), cohortNamesByType)
splitEventCohorts <- if (is.null(splitEventCohortNames)) NULL else cohortIdsFromNames(cohorts, splitEventCohortNames, "event")

# ---- Compute pathways ----
outputEnv <- TreatmentPatterns::computePathways(
  cohorts = cohorts,
  cohortTableName = combinedCohortTable,
  cdm = cdm,
  analysisId = analysisId,
  description = arguments$description,
  startAnchor = startAnchor,
  windowStart = windowStart,
  endAnchor = endAnchor,
  windowEnd = windowEnd,
  splitEventCohorts = splitEventCohorts,
  splitTime = splitTime,
  minEraDuration = minEraDuration,
  filterTreatments = filterTreatments,
  eraCollapseSize = eraCollapseSize,
  combinationWindow = combinationWindow,
  minPostCombinationDuration = minPostCombinationDuration,
  overlapMethod = overlapMethod,
  maxPathLength = maxPathLength,
  concatTargets = concatTargets
)

# ---- Export aggregate results ----
TreatmentPatterns::export(
  andromeda = outputEnv,
  outputPath = output_dir,
  ageWindow = ageWindow,
  minCellCount = minCellCount,
  censorType = censorType,
  archiveName = arguments$archiveName,
  nonePaths = arguments$nonePaths
)

Andromeda::close(outputEnv)

cdm <- cleanUpTables(cdm, combinedCohortTable)

CDMConnector::cdmDisconnect(cdm)