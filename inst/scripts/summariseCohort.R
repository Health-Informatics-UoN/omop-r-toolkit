'Summarise a cohort after feature generation using the PatientProfiles standard API.

Usage:
  summariseCohort.R <name> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the summary csv to [default: outputs/cohort_summary.csv]
  --group=<group>               Optional group variable name
  --includeOverallGroup=<logical>  Include overall group [default: TRUE]
  --strata=<json>               JSON vector/list of strata variable names [default: []]
  --includeOverallStrata=<logical> Include overall strata [default: TRUE]
  --variables=<json>            JSON vector/list of variables to summarise [default: []]
  --estimates=<json>            JSON vector/list of estimates to calculate [default: ["count","percentage"]]
  --counts=<logical>            Include record/subject counts [default: TRUE]
  --weights=<json>              Optional weights variable name(s) or NULL [default: NULL]
  --customEstimates=<json>      Optional custom estimates config [default: {}]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(jsonlite)
library(PatientProfiles)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/summariseCohortTable.R")

arguments <- docopt(doc, version = "Summarise Cohort 0.1.0")

parse_json_or_null <- function(x, default = NULL) {
  if (is.null(x) || identical(x, "NULL") || identical(x, "") || identical(x, "[]") || identical(x, "{}")) {
    return(default)
  }
  jsonlite::fromJSON(x)
}

parse_json_or_default <- function(x, default) {
  if (is.null(x) || identical(x, "") || identical(x, "NULL") || identical(x, "[]") || identical(x, "{}")) {
    return(default)
  }
  jsonlite::fromJSON(x)
}

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)
cohort <- cdm[[arguments$name]]

strata <- parse_json_or_default(arguments$strata, list())
variables <- parse_json_or_default(arguments$variables, NULL)
estimates <- parse_json_or_default(arguments$estimates, c("count", "percentage"))
weights <- parse_json_or_null(arguments$weights, NULL)
customEstimates <- parse_json_or_default(arguments$customEstimates, list())

group <- if (is.null(arguments$group) || !nzchar(arguments$group)) list() else arguments$group

summary_df <- summariseCohortTable(
  cohort = cohort,
  output_path = arguments$output_path,
  group = group,
  includeOverallGroup = as.logical(arguments$includeOverallGroup),
  strata = strata,
  includeOverallStrata = as.logical(arguments$includeOverallStrata),
  variables = variables,
  estimates = estimates,
  counts = as.logical(arguments$counts),
  weights = weights,
  customEstimates = customEstimates
)

CDMConnector::cdmDisconnect(cdm)

summary_df
