# This script runs a basic workflow of using the [IncidencePrevalence](https://darwin-eu.github.io/IncidencePrevalence/) package
# The CLI options are designed to supply the arguments to the central functions of the package
# 1. estimateIncidence
# 2. estimatePointPrevalence
# 3. estimatePeriodPrevalence


'Calculate incidence or prevalence in a cohort.

Usage:
  incidencePrevalence.R <denominatorCohortName> [options]

Options:
  -h --help                                           Show this screen
  --version                                           Show version
  --denominatorCohortDateRange=<dates>                Optional comma-separated pair of dates ("YYYY-MM-DD").The first indicating the earliest cohort start date and the second indicating the latest possible cohort end date. [default: 1900-01-01,2100-01-01]
  --denominatorAgeGroup=<groups>                      A list of age groups for which cohorts will be generated. [default: [[0,150]]]
  --denominatorBothOff                                Do not have a cohort of people assigned either Male or Female
  --denominatorMale                                   Have a cohort of people assigned Male
  --denominatorFemale                                 Have a cohort of people assigned Female
  --denominatorDaysPriorObservation=<days>            The number of days of prior observation observed in the database required for an individual to start contributing time in a cohort. [default: 0]
  --requirementInteractions                           If TRUE, cohorts will be created for all combinations of ageGroup, sex, and daysPriorObservation. If FALSE, only the first value specified for the other factors will be used. Consequently, order of values matters when requirementInteractions is FALSE. [default: TRUE]
  --outcomeCohortName=<cohortName>                    Name of the outcome cohort in the cdm database
  --estimateIncidenceOutputPath=<output_path>         A path to which the output of estimateIncidence is saved. [default: ]
  --incidenceInterval=<interval>                      The interval for incidence, if estimating incidence. [default: years]
  --incidenceOutcomeWashout=<washout>                 The washout for incidence, if estimating incidence. [default: 0]
  --incidenceRepeatedEvents                           Whether to measure repeated events if estimating incidence
  --estimatePointPrevalenceOutputPath=<output_path>   A path to which the output of estimatePointPrevalence is saved. [default: ]
  --pointPrevalenceInterval=<interval>                The interval for point prevalence, if estimating point prevalence [default: Years]
  --pointPrevalenceTimePoint=<timePoint>              The time point for point prevalence, if estimating point prevalence [default: start]
  --estimatePeriodPrevalenceOutputPath=<output_path>  A path to which the output of estimatePeriodPrevalence is saved. [default: ]
  --periodPrevalenceInterval=<interval>               The interval for period prevalence, if estimating period prevalence [default: Years]
  --periodPrevalenceTimePoint=<timePoint>             The time period for period prevalence, if estimating period prevalence [default: start]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(jsonlite)
source("R/postgres-connect-5s-tes.R")
source("R/cleanCohortTables.R")
source("R/parseDateVector.R")
source("R/cohortGenders.R")
source("R/parseAgeGroups.R")
source("R/parseIntList.R")

arguments <- docopt(doc, version = "Incidence and Prevalence 0.1.0")

if (is.null(arguments$estimateIncidenceOutputPath)
  & is.null(arguments$estimatePointPrevalenceOutputPath)
  & is.null(arguments$estimatePeriodPrevalenceOutputPath)) {
    stop("You need to specify at least one output path for an IncidencePrevalence function")
  }

denominatorCohortDateRange <- parseNDates(arguments$denominatorCohortDateRange, 2)
denominatorAgeGroup <- parseAgeGroups(arguments$denominatorAgeGroup)
denominatorSex <- cohortGenders(
  !arguments$denominatorBothOff,
  arguments$denominatorFemale,
  arguments$denominatorMale
)

if (length(denominatorSex) == 0) {
  stop("You need at least one sex cohort")
}

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$outcomeCohortName)

cdm <- IncidencePrevalence::generateDenominatorCohortSet(
  cdm = cdm,
  name = arguments$denominatorCohortName,
  cohortDateRange = denominatorCohortDateRange,
  ageGroup = denominatorAgeGroup,
  sex = denominatorSex,
  daysPriorObservation = as.numeric(arguments$denominatorDaysPriorObservation),
  requirementInteractions = arguments$requirementInteractions
)

if (!is.null(arguments$estimateIncidenceOutputPath)) {
  inc <- IncidencePrevalence::estimateIncidence(
    cdm = cdm,
    denominatorTable = arguments$denominatorCohortName,
    outcomeTable = arguments$outcomeCohortName,
    interval = arguments$incidenceInterval,
    outcomeWashout = as.numeric(arguments$incidenceOutcomeWashout),
    repeatedEvents = arguments$incidenceRepeatedEvents
  )
  write.csv(IncidencePrevalence::asIncidenceResult(inc), file = arguments$estimateIncidenceOutputPath)
}

if (!is.null(arguments$estimatePointPrevalenceOutputPath)) {
  prev <- IncidencePrevalence::estimatePointPrevalence(
    cdm = cdm,
    denominatorTable = arguments$denominatorCohortName,
    outcomeTable = arguments$outcomeCohortName,
    interval = arguments$pointPrevalenceInterval,
    timePoint = arguments$pointPrevalenceTimePoint
  )
  write.csv(IncidencePrevalence::asIncidenceResult(prev), file = arguments$estimatePointPrevalenceOutputPath)
}

if (!is.null(arguments$estimatePeriodPrevalenceOutputPath)) {
  prev <- IncidencePrevalence::estimatePeriodPrevalence(
    cdm = cdm,
    denominatorTable = arguments$denominatorCohortName,
    outcomeTable = arguments$outcomeCohortName,
    interval = arguments$periodPrevalenceInterval,
    timePoint = arguments$periodPrevalenceTimePoint
  )
  write.csv(IncidencePrevalence::asIncidenceResult(prev), file = arguments$estimatePeriodPrevalenceOutputPath)
}

CDMConnector::cdmDisconnect(cdm)
