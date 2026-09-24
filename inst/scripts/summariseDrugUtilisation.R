'Summarise drug utilisation metrics for a cohort using DrugUtilisation.

Usage:
  summariseDrugUtilisation.R <name> [options]

Options:
  -h --help                         Show this screen
  --version                         Show version
  --ingredientConceptId=<ids>       Comma-separated ingredient concept IDs
  --conceptSet=<json>               Optional concept set JSON for custom concepts
  --strata=<json>                   Optional JSON list of strata variables [default: []]
  --estimates=<json>                JSON vector of estimates [default: ["mean","sd","count_missing","percentage_missing"]]
  --indexDate=<date_col>            Index date column [default: cohort_start_date]
  --censorDate=<date_col>           Optional censor date column
  --restrictIncident=<logical>      Restrict to incident exposures
  --gapEra=<n>                     Gap era in days [default: 7]
  --numberExposures=<logical>      Include number of exposures
  --numberEras=<logical>           Include number of eras
  --daysExposed=<logical>          Include days exposed
  --daysPrescribed=<logical>       Include days prescribed
  --timeToExposure=<logical>        Include time to exposure
  --initialExposureDuration=<logical> Include initial exposure duration
  --initialQuantity=<logical>      Include initial quantity
  --cumulativeQuantity=<logical>   Include cumulative quantity
  --initialDailyDose=<logical>     Include initial daily dose
  --cumulativeDose=<logical>       Include cumulative dose
  --output-path=<path>             Output CSV path
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(DrugUtilisation)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseJSONOrDefault.R")
source("R/parseNumericVector.R")

arguments <- docopt(doc, version = "Summarise Drug Utilisation 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)
cohort <- cdm[[arguments$name]]

ingredient_ids <- NULL
if (!is.null(arguments$ingredientConceptId) && nzchar(arguments$ingredientConceptId)) {
  ingredient_ids <- parseNumericVector(arguments$ingredientConceptId)
}

concept_set <- NULL
if (!is.null(arguments$conceptSet) && nzchar(arguments$conceptSet)) {
  concept_set <- jsonlite::fromJSON(arguments$conceptSet)
}

strata <- parseJSONOrDefault(arguments$strata, list())
estimates <- parseJSONOrDefault(arguments$estimates, c("mean", "sd", "count_missing", "percentage_missing"))

utilisation_arguments <- list(
  strata = strata,
  estimates = estimates,
  ingredientConceptId = ingredient_ids,
  conceptSet = concept_set,
  indexDate = arguments$indexDate,
  censorDate = if (is.null(arguments$censorDate) || !nzchar(arguments$censorDate)) NULL else arguments$censorDate,
  gapEra = as.numeric(arguments$gapEra)
)
utilisation_arguments <- c(utilisation_arguments, Filter(Negate(is.null), list(
  restrictIncident = parseLogical(arguments$restrictIncident),
  numberExposures = parseLogical(arguments$numberExposures),
  numberEras = parseLogical(arguments$numberEras),
  daysExposed = parseLogical(arguments$daysExposed),
  daysPrescribed = parseLogical(arguments$daysPrescribed),
  timeToExposure = parseLogical(arguments$timeToExposure),
  initialExposureDuration = parseLogical(arguments$initialExposureDuration),
  initialQuantity = parseLogical(arguments$initialQuantity),
  cumulativeQuantity = parseLogical(arguments$cumulativeQuantity),
  initialDailyDose = parseLogical(arguments$initialDailyDose),
  cumulativeDose = parseLogical(arguments$cumulativeDose)
)))

result <- do.call(
  DrugUtilisation::summariseDrugUtilisation,
  c(list(cohort = cohort), utilisation_arguments)
)

if (!is.null(arguments$output_path) && nzchar(arguments$output_path)) {
  dir.create(dirname(arguments$output_path), recursive = TRUE, showWarnings = FALSE)
  write.csv(as.data.frame(result), arguments$output_path, row.names = FALSE)
}

CDMConnector::cdmDisconnect(cdm)
