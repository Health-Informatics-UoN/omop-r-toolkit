'Define a cohort using a concept set

Usage:
  defineConceptCohortSet.R <name> --conceptSet=<json> [--alloccurrences] [--end=<end>] [--requiredObservation=<days>]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --alloccurrences              Include all occurrences of events in the cohort. Otherwise, only includes the first
  --end=<end>                   How the cohort end date should be defined. One of "observation_period_end_date", a numeric scalar for the number of days, or "event_end_date" [default: observation_period_end_date]
  --requiredObservation=<days>  Comma-separated pair of days of required observation time prior,post index, e.g. "0,0" [default: 0,0]
  --conceptSet=<json>           JSON string describing the concept set for the cohort ({"someName": [1234, 5678],...})
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(CohortCharacteristics)
library(docopt)
library(jsonlite)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/cleanCohortTables.R")
source("R/parseIntList.R")

arguments <- docopt(doc, version = "Define Concept Cohort set 0.1.0")

# requiredObservation arrives as a string like "0,0" - split into a numeric vector of length 2
requiredObservation <- parseNInts(arguments$requiredObservation, 2)

# conceptSet arrives as a JSON string - parse it into an R list
conceptSet <- fromJSON(arguments$conceptSet)

cdm <- connectFiveSafesTESPg("postgres_omop")

cdm_cohorts <- CDMConnector::generateConceptCohortSet(
  cdm = cdm,
  name = arguments$name,
  limit = if (arguments$alloccurrences) "all" else "first",
  conceptSet = conceptSet,
  end = arguments$end,
  requiredObservation = requiredObservation
)

CDMConnector::cdmDisconnect(cdm)