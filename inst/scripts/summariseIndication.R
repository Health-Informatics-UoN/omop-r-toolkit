'Summarise indication patterns in a cohort using DrugUtilisation.

Usage:
  summariseIndication.R <name> --indicationCohortName=<table> [options]

Options:
  -h --help                             Show this screen
  --version                             Show version
  --indicationCohortName=<table>        Indication cohort table name in the cdm
  --indicationCohortId=<ids>            Optional indication cohort IDs
  --window=<windows>                   Indication window(s) as JSON or comma-pair, e.g. [-30,0] or [[-30,0],[0,0]] [default: [-30,0]]
  --unknownIndicationTable=<table>      Optional table for unknown indications (e.g. condition_occurrence)
  --strata=<json>                       Optional JSON list of strata variables [default: []]
  --indexDate=<date_col>                Index date column [default: cohort_start_date]
  --censorDate=<date_col>               Optional censor date column
  --mutuallyExclusive=<logical>         Consider mutually exclusive indication labels
  --restrictIncident=<logical>          Restrict to incident indication events
  --output-path=<path>                  Path to write output csv
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(DrugUtilisation)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseJSONOrDefault.R")
source("R/parseNumericVector.R")
source("R/parseWindows.R")

arguments <- docopt(doc, version = "Summarise Indication 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = c(arguments$name, arguments$indicationCohortName))
cohort <- cdm[[arguments$name]]

window_list <- parseWindows(arguments$window)
indication_id <- NULL
if (!is.null(arguments$indicationCohortId) && nzchar(arguments$indicationCohortId)) {
  indication_id <- parseNumericVector(arguments$indicationCohortId)
}

unknown_table <- NULL
if (!is.null(arguments$unknownIndicationTable) && nzchar(arguments$unknownIndicationTable)) {
  unknown_table <- arguments$unknownIndicationTable
}

strata <- parseJSONOrDefault(arguments$strata, list())

indication_arguments <- list(
  indicationCohortName = arguments$indicationCohortName,
  indicationCohortId = indication_id,
  indicationWindow = window_list,
  unknownIndicationTable = unknown_table,
  strata = strata,
  indexDate = arguments$indexDate,
  censorDate = if (is.null(arguments$censorDate) || !nzchar(arguments$censorDate)) NULL else arguments$censorDate
)
indication_arguments <- c(indication_arguments, Filter(Negate(is.null), list(
  mutuallyExclusive = parseLogical(arguments$mutuallyExclusive),
  restrictIncident = parseLogical(arguments$restrictIncident)
)))

result <- do.call(
  DrugUtilisation::summariseIndication,
  c(list(cohort = cohort), indication_arguments)
)

if (!is.null(arguments$output_path) && nzchar(arguments$output_path)) {
  dir.create(dirname(arguments$output_path), recursive = TRUE, showWarnings = FALSE)
  write.csv(as.data.frame(result), arguments$output_path, row.names = FALSE)
}

CDMConnector::cdmDisconnect(cdm)
