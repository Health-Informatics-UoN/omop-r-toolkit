'Add table intersection days and summarize.

Usage:
  addTableIntersectDays.R <name> --tableName=<table> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --tableName=<table>           OMOP table name
  --window=<window>             Window [default: [-Inf,Inf]]
  --order=<order>               first or last [default: first]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --targetDate=<col>            Date column in target table
  --inObservation=<logical>     Keep only records in observation [default: TRUE]
  --nameStyle=<style>           Naming pattern [default: {table_name}_{window_name}]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(PatientProfiles)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseWindows.R")

arguments <- docopt(doc, version = "Add Table Intersect Days 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)
cohort <- cdm[[arguments$name]]

indexDate <- if (is.null(arguments$indexDate) || !nzchar(arguments$indexDate, keepNA = FALSE)) "cohort_start_date" else arguments$indexDate
window <- parseWindows(arguments$window)
targetDate <- if (!is.null(arguments$targetDate) && nzchar(arguments$targetDate)) arguments$targetDate else startDateColumn(arguments$tableName)

cohort <- cohort |>
  addTableIntersectDays(
    tableName = arguments$tableName,
    window = window,
    order = arguments$order,
    indexDate = indexDate,
    targetDate = targetDate,
    inObservation = parseLogical(arguments$inObservation, TRUE),
    nameStyle = arguments$nameStyle
  )

CDMConnector::cdmDisconnect(cdm)