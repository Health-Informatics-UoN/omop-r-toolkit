'Summarise drug restart patterns for a cohort.

Usage:
  summariseDrugRestart.R <name> --switchCohortTable=<table> [options]

Options:
  -h --help                          Show this screen
  --version                          Show version
  --switchCohortTable=<table>        Switch cohort table in the cdm
  --switchCohortId=<ids>             Optional switch cohort IDs
  --strata=<json>                    Optional JSON list of strata variables [default: []]
  --followUpDays=<n>                 Follow-up window in days [default: 365]
  --censorDate=<date_col>            Optional censor date column
  --incident=<logical>               Restrict to incident restarts
  --restrictToFirstDiscontinuation=<logical> Restrict to first discontinuation only
  --output-path=<path>               Output CSV path
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(DrugUtilisation)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseJSONOrDefault.R")
source("R/parseNumericVector.R")

arguments <- docopt(doc, version = "Summarise Drug Restart 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = c(arguments$name, arguments$switchCohortTable))
cohort <- cdm[[arguments$name]]

switch_id <- NULL
if (!is.null(arguments$switchCohortId) && nzchar(arguments$switchCohortId)) {
  switch_id <- parseNumericVector(arguments$switchCohortId)
}

strata <- parseJSONOrDefault(arguments$strata, list())

restart_arguments <- list(
  cohort = cohort,
  cohortId = NULL,
  switchCohortTable = arguments$switchCohortTable,
  switchCohortId = switch_id,
  strata = strata,
  followUpDays = as.numeric(arguments$followUpDays),
  censorDate = if (is.null(arguments$censorDate) || !nzchar(arguments$censorDate)) NULL else arguments$censorDate
)
restart_arguments <- c(restart_arguments, Filter(Negate(is.null), list(
  incident = parseLogical(arguments$incident),
  restrictToFirstDiscontinuation = parseLogical(arguments$restrictToFirstDiscontinuation)
)))

result <- do.call(DrugUtilisation::summariseDrugRestart, restart_arguments)

if (!is.null(arguments$output_path) && nzchar(arguments$output_path)) {
  dir.create(dirname(arguments$output_path), recursive = TRUE, showWarnings = FALSE)
  write.csv(as.data.frame(result), arguments$output_path, row.names = FALSE)
}

CDMConnector::cdmDisconnect(cdm)
