'Summarise dose coverage using DrugUtilisation.

Usage:
  summariseDoseCoverage.R <name> [options]

Options:
  -h --help                         Show this screen
  --version                         Show version
  --ingredientConceptId=<ids>       Comma-separated ingredient concept IDs
  --conceptSet=<json>               Optional concept set JSON for custom concept definitions
  --estimates=<json>                Optional JSON vector of estimates [default: ["mean","sd","min","max"]]
  --sampleSize=<n>                  Optional sample-size override
  --output-path=<path>              Output CSV path
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(DrugUtilisation)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseJSONOrDefault.R")
source("R/parseNumericVector.R")

arguments <- docopt(doc, version = "Summarise Dose Coverage 0.1.0")

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

estimates <- parseJSONOrDefault(arguments$estimates, c("mean", "sd", "min", "max"))

result <- DrugUtilisation::summariseDoseCoverage(
  cdm = cdm,
  ingredientConceptId = ingredient_ids,
  estimates = estimates,
  sampleSize = if (is.null(arguments$sampleSize) || !nzchar(arguments$sampleSize)) NULL else as.numeric(arguments$sampleSize)
)

if (!is.null(arguments$output_path) && nzchar(arguments$output_path)) {
  dir.create(dirname(arguments$output_path), recursive = TRUE, showWarnings = FALSE)
  write.csv(as.data.frame(result), arguments$output_path, row.names = FALSE)
}

CDMConnector::cdmDisconnect(cdm)
