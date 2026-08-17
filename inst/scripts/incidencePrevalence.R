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
  --denominatorCohortDateRange=<dates>                Optional comma-separated pair of dates ("YYYY-MM-DD").The first indicating the earliest cohort start date and the second indicating the latest possible cohort end date. [default: ""]
  --denominatorAgeGroup=<groups>                      A list of age groups for which cohorts will be generated. [default: ""]
  --denominatorBothOff                                Do not have a cohort of people assigned either Male or Female
  --denominatorMale                                   Have a cohort of people assigned Male
  --denominatorFemale                                 Have a cohort of people assigned Female
  --denominatorDaysPriorObservation                   The number of days of prior observation observed in the database required for an individual to start contributing time in a cohort. [default: ""]
  --estimateIncidenceOutputPath=<output_path>         A path to which the output of estimateIncidence is saved. [default: ""]
  --estimatePointPrevalenceOutputPath=<output_path>   A path to which the output of estimateIncidence is saved. [default: ""]
  --estimatePeriodPrevalenceOutputPath=<output_path>  A path to which the output of estimateIncidence is saved. [default: ""]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(jsonlite)
source("R/postgres-connect-5s-tes.R")
source("R/cleanCohortTables.R")
source("R/parseDateVector.R")
source("R/cohortGenders.R")

arguments <- docopt(doc, version = "Incidence and Prevalence 0.1.0")

print(arguments)

if (is.null(attr(arguments, estimateIncidenceOutputPath))
  & is.null(attr(arguments, estimatePointPrevalenceOutputPath))
  & is.null(attr(arguments, estimatePeriodPrevalenceOutputPath))) {
    stop("You need to specify at least one output path for an IncidencePrevalence function")
  }

denominatorCohortDateRange = parseNDates(arguments$denominatorCohortDateRange, 2)
denominatorAgeGroup = as.numeric(strsplit(arguments$denominatorAgeGroup, ",")[[1]])
denominatorSex = cohortGenders(
  !arguments$denominatorBothOff,
  arguments$denominatorFemale,
  arguments$denominatorMale
)

if (length(denominatorSex) == 0) {
  stop("You need at least one sex cohort")
}

#cdm <- connectFiveSafesTESPg("postgres_omop")
