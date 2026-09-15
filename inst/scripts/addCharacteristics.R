'Add patient characteristics to a cohort and summarize.

Usage:
  addCharacteristics.R <name> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --addAge                      Add age at index date
  --ageGroup=<json>             JSON list of age groups [default: [[0,150]]]
  --ageName=<name>              Name for the age column [default: age]
  --ageMissingMonth=<m>         Month assumed if missing [default: NULL]
  --ageMissingDay=<d>           Day assumed if missing [default: NULL]
  --ageImposeMonth              Impose missing month to ageMissingMonth
  --ageImposeDay                Impose missing day to ageMissingDay
  --addSex                      Add sex
  --addPriorObservation         Add days of prior observation
  --addFutureObservation        Add days of future observation
  --addInObservation            Add in-observation flag
  --inObservationWindow=<win>   Window for in-observation [default: 0,0]
  --completeInterval            Require complete interval for in-observation
  --useDemographics             Use addDemographics() (more efficient, combines selected)
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(PatientProfiles)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseAgeGroups.R")
source("R/parseWindows.R")

arguments <- docopt(doc, version = "Add Characteristics 0.2.0")

if (!arguments$addAge && !arguments$addSex && !arguments$addPriorObservation
    && !arguments$addFutureObservation && !arguments$addInObservation) {
  stop("You must specify at least one characteristic")
}

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)
cohort <- cdm[[arguments$name]]

ageGroup <- if (arguments$addAge) parseAgeGroups(arguments$ageGroup) else NULL

if (arguments$useDemographics) {
  cohort <- cohort |> addDemographics(
    age = arguments$addAge,
    ageName = arguments$ageName,
    ageGroup = ageGroup,
    sex = arguments$addSex,
    sexName = "sex",
    priorObservation = arguments$addPriorObservation,
    priorObservationName = "prior_observation",
    futureObservation = arguments$addFutureObservation,
    futureObservationName = "future_observation",
    inObservation = arguments$addInObservation,
    inObservationName = "in_observation"
  )
} else {
  if (arguments$addAge) {
    ageArgs <- list(
      indexDate = arguments$indexDate,
      ageName = arguments$ageName,
      ageGroup = ageGroup,
      ageImposeMonth = arguments$ageImposeMonth,
      ageImposeDay = arguments$ageImposeDay
    )
    if (!is.null(arguments$ageMissingMonth) && !identical(arguments$ageMissingMonth, "NULL")) {
      ageArgs$ageMissingMonth <- as.numeric(arguments$ageMissingMonth)
    }
    if (!is.null(arguments$ageMissingDay) && !identical(arguments$ageMissingDay, "NULL")) {
      ageArgs$ageMissingDay <- as.numeric(arguments$ageMissingDay)
    }

    cohort <- do.call(addAge, c(list(x = cohort), ageArgs))
  }
  if (arguments$addSex) {
    cohort <- cohort |> addSex()
  }
  if (arguments$addPriorObservation) {
    cohort <- cohort |> addPriorObservation(indexDate = arguments$indexDate)
  }
  if (arguments$addFutureObservation) {
    cohort <- cohort |> addFutureObservation(indexDate = arguments$indexDate)
  }
  if (arguments$addInObservation) {
    inWin <- parseWindows(arguments$inObservationWindow)
    cohort <- cohort |> addInObservation(
      indexDate = arguments$indexDate,
      window = inWin,
      completeInterval = arguments$completeInterval
    )
  }
}

CDMConnector::cdmDisconnect(cdm)