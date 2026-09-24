'Create a drug cohort using ingredient-based DrugUtilisation functions.

Usage:
  generateIngredientCohortSet.R <name> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --ingredient=<names>          Comma-separated ingredient names (e.g. acetaminophen,metformin)
  --atc=<name>                 ATC name to use instead of ingredient names
  --gapEra=<n>                 Gap era in days [default: 1]
  --subsetCohort=<name>        Optional cohort table to subset from
  --subsetCohortId=<ids>       Optional cohort IDs to subset
  --numberExposures=<logical>  Add number of exposures to the output cohort
  --daysPrescribed=<logical>   Add days prescribed to the output cohort
  --output-path=<path>         Optional path to write cohort settings summary csv
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(DrugUtilisation)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseNumericVector.R")

arguments <- docopt(doc, version = "Generate Drug Ingredient Cohort Set 0.1.0")

if (is.null(arguments$ingredient) || !nzchar(arguments$ingredient)) {
  if (is.null(arguments$atc) || !nzchar(arguments$atc)) {
    stop("You must provide --ingredient or --atc")
  }
}

cdm <- connectFiveSafesTESPg("postgres_omop")

cohort_arguments <- Filter(Negate(is.null), list(
  numberExposures = parseLogical(arguments$numberExposures),
  daysPrescribed = parseLogical(arguments$daysPrescribed)
))

if (!is.null(arguments$atc) && nzchar(arguments$atc)) {
  cohort_arguments <- c(list(
    cdm = cdm,
    name = arguments$name,
    atcName = arguments$atc,
    gapEra = as.numeric(arguments$gapEra),
    subsetCohort = if (is.null(arguments$subsetCohort) || !nzchar(arguments$subsetCohort)) NULL else arguments$subsetCohort,
    subsetCohortId = if (is.null(arguments$subsetCohortId) || !nzchar(arguments$subsetCohortId)) NULL else parseNumericVector(arguments$subsetCohortId)
  ), cohort_arguments)
  cdm <- do.call(DrugUtilisation::generateAtcCohortSet, cohort_arguments)
} else {
  ingredients <- strsplit(arguments$ingredient, ",", fixed = TRUE)[[1]]
  ingredients <- trimws(ingredients)
  ingredients <- ingredients[nzchar(ingredients)]

  if (length(ingredients) == 0) {
    stop("No valid ingredient names were supplied")
  }

  cohort_arguments <- c(list(
    cdm = cdm,
    name = arguments$name,
    ingredient = ingredients,
    gapEra = as.numeric(arguments$gapEra),
    subsetCohort = if (is.null(arguments$subsetCohort) || !nzchar(arguments$subsetCohort)) NULL else arguments$subsetCohort,
    subsetCohortId = if (is.null(arguments$subsetCohortId) || !nzchar(arguments$subsetCohortId)) NULL else parseNumericVector(arguments$subsetCohortId)
  ), cohort_arguments)
  cdm <- do.call(DrugUtilisation::generateIngredientCohortSet, cohort_arguments)
}

if (!is.null(arguments$output_path) && nzchar(arguments$output_path)) {
  settings_out <- as.data.frame(settings(cdm[[arguments$name]]))
  if (nrow(settings_out) > 0) {
    dir.create(dirname(arguments$output_path), recursive = TRUE, showWarnings = FALSE)
    write.csv(settings_out, arguments$output_path, row.names = FALSE)
  }
}

CDMConnector::cdmDisconnect(cdm)
