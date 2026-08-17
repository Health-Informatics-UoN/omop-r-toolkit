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
  --denominatorDaysPriorObservation                   The number of days of prior observation observed in the database required for an individual to start contributing time in a cohort. [default: ]
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
print(denominatorAgeGroup)
denominatorSex <- cohortGenders(
  !arguments$denominatorBothOff,
  arguments$denominatorFemale,
  arguments$denominatorMale
)

if (length(denominatorSex) == 0) {
  stop("You need at least one sex cohort")
}

#cdm <- connectFiveSafesTESPg("postgres_omop")
