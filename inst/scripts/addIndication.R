'Add indication flags to a cohort using DrugUtilisation.

Usage:
  addIndication.R <name> --indicationCohortName=<table> [options]

Options:
  -h --help                          Show this screen
  --version                          Show version
  --indicationCohortName=<table>     Indication cohort table name in the cdm
  --indicationCohortId=<ids>         Optional indication cohort IDs
  --window=<windows>                Indication window(s) as JSON or comma-pair, e.g. [-30,0] or [[-30,0],[0,0]] [default: [-30,0]]
  --unknownIndicationTable=<table>   Optional table for unknown indications (e.g. condition_occurrence)
  --indexDate=<date_col>             Index date column [default: cohort_start_date]
  --censorDate=<date_col>            Optional censor date column
  --mutuallyExclusive=<logical>      Consider mutually exclusive indication labels [default: FALSE]
  --restrictIncident=<logical>       Restrict to incident indication events [default: TRUE]
  --nameStyle=<style>                Naming style for the added columns [default: {window_name}]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(DrugUtilisation)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseNumericVector.R")
source("R/parseWindows.R")

arguments <- docopt(doc, version = "Add Indication 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = c(arguments$name, arguments$indicationCohortName))
cohort <- cdm[[arguments$name]]

indication_id <- NULL
if (!is.null(arguments$indicationCohortId) && nzchar(arguments$indicationCohortId)) {
  indication_id <- parseNumericVector(arguments$indicationCohortId)
}

unknown_table <- NULL
if (!is.null(arguments$unknownIndicationTable) && nzchar(arguments$unknownIndicationTable)) {
  unknown_table <- arguments$unknownIndicationTable
}

window_list <- parseWindows(arguments$window)

cohort <- cohort |>
  addIndication(
    indicationCohortName = arguments$indicationCohortName,
    indicationCohortId = indication_id,
    indicationWindow = window_list,
    unknownIndicationTable = unknown_table,
    indexDate = arguments$indexDate,
    censorDate = if (is.null(arguments$censorDate) || !nzchar(arguments$censorDate)) NULL else arguments$censorDate,
    mutuallyExclusive = parseLogical(arguments$mutuallyExclusive, FALSE),
    nameStyle = arguments$nameStyle,
    restrictIncident = parseLogical(arguments$restrictIncident, TRUE)
  )

cdm[[arguments$name]] <- cohort
CDMConnector::cdmDisconnect(cdm)
