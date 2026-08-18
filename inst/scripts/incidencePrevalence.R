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
  --denominatorCohortDateRange=<dates>                Optional comma-separated pair of dates ("YYYY-MM-DD").The first indicating the earliest cohort start date and the second indicating the latest possible cohort end date. [default: NA,NA]
  --denominatorAgeGroup=<groups>                      A list of age groups for which cohorts will be generated. [default: [[0,150]]]
  --denominatorBothOff                                Do not have a cohort of people assigned either Male or Female
  --denominatorMale                                   Have a cohort of people assigned Male
  --denominatorFemale                                 Have a cohort of people assigned Female
  --denominatorDaysPriorObservation                   The number of days of prior observation observed in the database required for an individual to start contributing time in a cohort. [default: 0]
  --requirementInteractions                           If TRUE, cohorts will be created for all combinations of ageGroup, sex, and daysPriorObservation. If FALSE, only the first value specified for the other factors will be used. Consequently, order of values matters when requirementInteractions is FALSE. [default: TRUE]
  --outcomeAllOccurrences                             Include all occurrences of events in the outcome cohort. Otherwise, only includes the first
  --outcomeEnd=<end>                                  How the outcome cohort end date should be defined. One of "observation_period_end_date", a numeric scalar for the number of days, or "event_end_date" [default: observation_period_end_date]
  --outcomeRequiredObservation=<days>                 Comma-separated pair of days of required observation time prior, post index for the outcome cohort, e.g. "0,0" [default: 0,0]
  --outcomeConceptSet=<json>                          JSON string describing the concept set for the outcome cohort ({"someName": [1234, 5678],...})
  --estimateIncidenceOutputPath=<output_path>         A path to which the output of estimateIncidence is saved. [default: ]
  --estimatePointPrevalenceOutputPath=<output_path>   A path to which the output of estimatePointPrevalence is saved. [default: ]
  --estimatePeriodPrevalenceOutputPath=<output_path>  A path to which the output of estimatePeriodPrevalence is saved. [default: ]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(jsonlite)
source("R/postgres-connect-5s-tes.R")
source("R/cleanCohortTables.R")
source("R/parseDateVector.R")
source("R/cohortGenders.R")
source("R/parseAgeGroups.R")

arguments <- docopt(doc, version = "Incidence and Prevalence 0.1.0")

# If you don't specify anything, the defaults are:
# $ <denominatorCohortName>             : chr "test"
# $ help                                : logi FALSE
# $ version                             : logi FALSE
# $ denominatorCohortDateRange          : NULL
# $ denominatorAgeGroup                 : NULL
# $ denominatorBothOff                  : logi FALSE
# $ denominatorMale                     : logi FALSE
# $ denominatorFemale                   : logi FALSE
# $ denominatorDaysPriorObservation     : logi FALSE
# $ estimateIncidenceOutputPath         : NULL
# $ estimatePointPrevalenceOutputPath   : NULL
# $ estimatePeriodPrevalenceOutputPath  : NULL
# $ denominatorCohortName               : chr "test"

if (is.null(arguments$estimateIncidenceOutputPath)
  & is.null(arguments$estimatePointPrevalenceOutputPath)
  & is.null(arguments$estimatePeriodPrevalenceOutputPath)) {
    stop("You need to specify at least one output path for an IncidencePrevalence function")
  }

denominatorCohortDateRange <- ifelse((arguments$denominatorCohortDateRange == "NA,NA"), as.Date(c(NA, NA)), parseNDates(arguments$denominatorCohortDateRange, 2))
denominatorAgeGroup <- parseAgeGroups(arguments$denominatorAgeGroup)
denominatorSex <- cohortGenders(
  !arguments$denominatorBothOff,
  arguments$denominatorFemale,
  arguments$denominatorMale
)

if (length(denominatorSex) == 0) {
  stop("You need at least one sex cohort")
}

cdm <- connectFiveSafesTESPg("postgres_omop")

cdm <- IncidencePrevalence::generateDenominatorCohortSet(
  cdm = cdm,
  name = arguments$denominatorCohortName,
  cohortDateRange = denominatorCohortDateRange,
  ageGroup = denominatorAgeGroup,
  sex = denominatorSex,
  daysPriorObservation = arguments$denominatorDaysPriorObservation,
  requirementInteractions = arguments$requirementInteractions
)

# So far we've only used concept cohort definitions. When we've explored other packages for creating cohorts, we can add other options.

cdm_cohorts <- CodelistGenerator::generateConceptCohortSet(
  cdm = cdm,
  name = "outcome",
  limit = if (arguments$outcomeAllOccurrences) "all" else "first",
  conceptSet = conceptSet,
  end = arguments$end,
  requiredObservation = requiredObservation
)


cdm <- cleanUpTables(cdm, arguments$denominatorCohortName)

CDMConnector::cdmDisconnect(cdm)
