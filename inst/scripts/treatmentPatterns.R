
# This script runs a basic workflow of using the TreatmentPatterns package
# 1. Bind the target, event and (optional) exit cohort tables into one cohort table
# 2. computePathways
# 3. Export the aggregate, disclosure-controlled results
# Patient-level export and plotting are deliberately not supported,
# as this runs eyes-off in a TRE.

'Compute treatment pathways with TreatmentPatterns and export aggregate results.

Usage:
  treatmentPatterns.R --targetCohortTable=<table> --eventCohortTable=<table> [options]

Options:
  -h --help                                Show this screen
  --version                                Show version
  --targetCohortTable=<table>              Cohort table holding the target cohort(s), e.g. a disease
  --eventCohortTable=<table>               Cohort table holding the event cohorts, e.g. treatments
  --exitCohortTable=<table>                Optional cohort table holding exit cohorts, e.g. death
  --combinedCohortTable=<table>            Name of the combined cohort table. Dropped at the end [default: tp_cohorts]
  --output-path=<path>                     Directory to write output CSVs to [default: outputs/treatment_patterns/]
  --archiveName=<name>                     Optional ZIP file name in the output directory
  --analysisId=<id>                        Analysis identifier [default: 1]
  --description=<text>                     Analysis description [default: Treatment Patterns analysis]
  --startAnchor=<anchor>                   Anchor for window start: startDate or endDate [default: startDate]
  --windowStart=<days>                     Offset in days from startAnchor [default: 0]
  --endAnchor=<anchor>                     Anchor for window end: startDate or endDate [default: endDate]
  --windowEnd=<days>                       Offset in days from endAnchor [default: 0]
  --splitEventCohorts=<names>              Comma-separated event cohort names to split into acute and therapy
  --splitTime=<days>                       Days classified as acute before therapy. One value or one per cohort
  --minEraDuration=<days>                  Minimum duration of an event era [default: 30]
  --filterTreatments=<method>              One of First, Changes, All [default: First]
  --eraCollapseSize=<days>                 Gap within which repeated eras are collapsed [default: 30]
  --combinationWindow=<days>               Minimum overlap for two events to count as a combination [default: 30]
  --minPostCombinationDuration=<days>      Minimum remaining era duration after separating combinations [default: 30]
  --overlapWithKeep                        Keep both record dates for non-significant overlap
  --maxPathLength=<n>                      Maximum number of steps in a pathway [default: 5]
  --concatTargets=<logical>                Concatenate multiple target entries per person [default: TRUE]
  --minCellCount=<n>                       Minimum cell count for disclosure control [default: 5]
  --censorType=<type>                      One of minCellCount, remove, mean [default: minCellCount]
  --ageWindow=<ages>                       Age group width or comma-separated age breaks [default: 10]
  --nonePaths                              Include pathways where no events occurred
' -> doc


# ---- Libraries and helpers ----

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(TreatmentPatterns)
library(CDMConnector)
library(omopgenerics)

source("R/postgres-connect-5s-tes.R")
source("R/cleanCohortTables.R")
source("R/parseIntList.R")
source("R/treatmentPatternsCohort.R")
source("R/parseStringVector.R")
source("R/checkChoice.R")


# ---- Parse command-line arguments ----

arguments <- docopt(doc, version = "Treatment Patterns 0.1.0")


# ---- Parse and validate arguments before database connection ----

startAnchor <- checkChoice(
  arguments$startAnchor,
  c("startDate", "endDate"),
  "startAnchor"
)

endAnchor <- checkChoice(
  arguments$endAnchor,
  c("startDate", "endDate"),
  "endAnchor"
)

filterTreatments <- checkChoice(
  arguments$filterTreatments,
  c("First", "Changes", "All"),
  "filterTreatments"
)

overlapMethod <- if (arguments$overlapWithKeep) "keep" else "truncate"

censorType <- checkChoice(
  arguments$censorType,
  c("minCellCount", "remove", "mean"),
  "censorType"
)


# ---- Parse numeric parameters ----

analysisId <- parseNumber(arguments$analysisId, "analysisId")
windowStart <- parseNumber(arguments$windowStart, "windowStart")
windowEnd <- parseNumber(arguments$windowEnd, "windowEnd")

minEraDuration <- parseNumber(
  arguments$minEraDuration,
  "minEraDuration"
)

eraCollapseSize <- parseNumber(
  arguments$eraCollapseSize,
  "eraCollapseSize"
)

combinationWindow <- parseNumber(
  arguments$combinationWindow,
  "combinationWindow"
)

minPostCombinationDuration <- parseNumber(
  arguments$minPostCombinationDuration,
  "minPostCombinationDuration"
)

maxPathLength <- parseNumber(
  arguments$maxPathLength,
  "maxPathLength"
)

minCellCount <- parseNumber(
  arguments$minCellCount,
  "minCellCount"
)

ageWindow <- parseStringAsInts(arguments$ageWindow)


# ---- Validate logical parameters ----

concatTargets <- as.logical(arguments$concatTargets)

if (is.na(concatTargets)) {
  stop("--concatTargets must be TRUE or FALSE")
}


# ---- Validate TreatmentPatterns configuration ----

checkPathwaySettings(
  minEraDuration,
  combinationWindow,
  minPostCombinationDuration
)


# ---- Parse split event cohorts ----

splitEventCohortNames <- if (is.null(arguments$splitEventCohorts)) {
  NULL
} else {
  parseStringVector(arguments$splitEventCohorts)
}

splitTime <- if (is.null(arguments$splitTime)) {
  NULL
} else {
  parseStringAsInts(arguments$splitTime)
}

if (xor(is.null(splitEventCohortNames), is.null(splitTime))) {
  stop("--splitEventCohorts and --splitTime must be specified together")
}

if (
  !is.null(splitTime) &&
  !length(splitTime) %in% c(1, length(splitEventCohortNames))
) {
  stop(
    "--splitTime must have one value, or one value per cohort in --splitEventCohorts"
  )
}


# ---- Validate cohort table names ----

combinedCohortTable <- arguments$combinedCohortTable

cohortTableNames <- c(
  arguments$targetCohortTable,
  arguments$eventCohortTable,
  arguments$exitCohortTable
)

if (anyDuplicated(cohortTableNames)) {
  stop(
    "Target, event and exit cohorts must be in different tables. ",
    "Define them with separate defineConceptCohortSet runs."
  )
}

if (combinedCohortTable %in% cohortTableNames) {
  stop(
    "--combinedCohortTable must not be the same as an input cohort table, ",
    "as it is dropped at the end"
  )
}


# ---- Prepare output directory ----

output_dir <- arguments$output_path

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cdm <- connectFiveSafesTESPg(
  "postgres_omop",
  cohortTables = cohortTableNames
)

cohortNamesByType <- list(
  target = omopgenerics::settings(
    cdm[[arguments$targetCohortTable]]
  )$cohort_name,

  event = omopgenerics::settings(
    cdm[[arguments$eventCohortTable]]
  )$cohort_name,

  exit = if (is.null(arguments$exitCohortTable)) {
    character()
  } else {
    omopgenerics::settings(
      cdm[[arguments$exitCohortTable]]
    )$cohort_name
  }
)

checkDistinctCohortNames(cohortNamesByType)


# ---- Combine cohorts into one table ----

cohortTablesToBind <- lapply(
  cohortTableNames,
  function(tableName) cdm[[tableName]]
)

cdm <- do.call(
  omopgenerics::bind,
  c(
    cohortTablesToBind,
    list(name = combinedCohortTable)
  )
)

cohorts <- buildCohortTypes(
  omopgenerics::settings(
    cdm[[combinedCohortTable]]
  ),
  cohortNamesByType
)

splitEventCohorts <- if (is.null(splitEventCohortNames)) {
  NULL
} else {
  cohortIdsFromNames(
    cohorts,
    splitEventCohortNames,
    "event"
  )
}

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

cdm <- cleanUpTables(
  cdm,
  combinedCohortTable
)

CDMConnector::cdmDisconnect(cdm)