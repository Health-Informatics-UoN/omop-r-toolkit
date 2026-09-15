'Find first or last concept event date and summarize.

Usage:
  addConceptEventDate.R <name> --conceptSet=<json> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --conceptSet=<json>           JSON concept set ({"name": [concept_id, ...]})
  --window=<window>             Window [default: [[-Inf,Inf]]]
  --order=<order>               first or last [default: first]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --targetDate=<type>           event_start_date or event_end_date [default: event_start_date]
  --censorDate=<col>            Optional censor date column
  --multipleEvents=<mode>       null, true, or comma-separated priority list
  --nameStyle=<style>           Naming pattern [default: {value}_{window_name}]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(PatientProfiles)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseConceptSet.R")
source("R/parseWindows.R")
source("R/parseMultipleEvents.R")

arguments <- docopt(doc, version = "Add Concept Event Date 0.1.0")

conceptSet <- parseJSONConceptSet(arguments$conceptSet)
window <- parseWindows(arguments$window)
multipleEvents <- parseMultipleEvents(arguments$multipleEvents)

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)
cohort <- cdm[[arguments$name]]

cohort <- cohort |>
  addConceptEventDate(
    conceptSet = conceptSet,
    window = window,
    order = arguments$order,
    indexDate = arguments$indexDate,
    targetDate = arguments$targetDate,
    censorDate = arguments$censorDate,
    multipleEvents = multipleEvents,
    nameStyle = arguments$nameStyle
  )

CDMConnector::cdmDisconnect(cdm)