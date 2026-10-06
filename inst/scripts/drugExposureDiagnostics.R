'Run Drug Exposure Diagnostics on OMOP CDM drug records.

Usage:
  drugExposureDiagnostics.R --ingredients=<ids> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --ingredients=<ids>           Comma-separated ingredient concept IDs (e.g. 1125315,161)
  --checks=<checks>             Comma-separated checks to run [default: missing,exposureDuration,type,route,sourceConcept,daysSupply,verbatimEndDate,dose,sig,quantity,daysBetween,diagnosticsSummary]
  --output-path=<path>          Directory to write output csvs to [default: outputs/ded/]
  --databaseId=<id>             Database identifier [default: OMOP_DB]
  --sample=<n>                  Number of records to sample (0 = all) [default: 10000]
  --minCellCount=<n>            Minimum cell count for disclosure control [default: 5]
  --earliestStartDate=<date>    Earliest drug exposure start date [default: 1900-01-01]
  --byConcept                   Return results broken down by drug concept
  --subsetToConceptId=<ids>     Comma-separated concept IDs to include (+) or exclude (-)
  --exposureTypeId=<id>         Drug exposure type concept ID to filter on
  --tablePrefix=<prefix>        Prefix for temporary database tables
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(DrugExposureDiagnostics)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseIntList.R")
source("R/parseStringVector.R")
source("R/checkChoice.R")

arguments <- docopt(doc, version = "Drug Exposure Diagnostics 0.1.0")

ingredients <- parseIntegerVector(arguments$ingredients)
checks <- parseStringVector(arguments$checks)
allowed_checks <- get("getAllCheckOptions", envir = asNamespace("DrugExposureDiagnostics"))()
checkChoice(checks, allowed_checks, "checks")

output_dir <- arguments$output_path
database_id <- arguments$databaseId
sample_n <- as.numeric(arguments$sample)
min_cell <- as.numeric(arguments$minCellCount)
earliest_start <- as.Date(arguments$earliestStartDate)
by_concept <- arguments$byConcept

subset_ids <- if (is.null(arguments$subsetToConceptId)) NULL else parseIntegerVector(arguments$subsetToConceptId)
exposure_type <- if (is.null(arguments$exposureTypeId)) NULL else as.numeric(arguments$exposureTypeId)
table_prefix <- arguments$tablePrefix

if (length(ingredients) == 0) {
  stop("You must specify at least one ingredient concept ID")
}

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cdm <- connectFiveSafesTESPg("postgres_omop")

results <- DrugExposureDiagnostics::executeChecks(
  cdm = cdm,
  ingredients = ingredients,
  checks = checks,
  sample = if (sample_n > 0) sample_n else NULL,
  minCellCount = min_cell,
  earliestStartDate = earliest_start,
  byConcept = by_concept,
  subsetToConceptId = subset_ids,
  exposureTypeId = exposure_type,
  tablePrefix = table_prefix,
  verbose = FALSE
)

DrugExposureDiagnostics::writeResultToDisk(
  resultList = results,
  databaseId = database_id,
  outputFolder = output_dir,
  filename = "drug_exposure_diagnostics"
)

CDMConnector::cdmDisconnect(cdm)