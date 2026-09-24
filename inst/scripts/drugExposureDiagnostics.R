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

arguments <- docopt(doc, version = "Drug Exposure Diagnostics 0.1.0")

ingredients <- parseIntegerVector(arguments$ingredients)
checks <- trimws(strsplit(arguments$checks, ",")[[1]])
checks <- checks[nzchar(checks)]

allowed_checks <- get("getAllCheckOptions", envir = asNamespace("DrugExposureDiagnostics"))()
invalid_checks <- setdiff(checks, allowed_checks)
if (length(invalid_checks) > 0) {
  stop(
    paste0(
      "Invalid check(s) requested: ",
      paste(invalid_checks, collapse = ", "),
      ". Allowed options are: ",
      paste(allowed_checks, collapse = ", ")
    )
  )
}

output_dir <- arguments$output_path
database_id <- arguments$database_id
sample_n <- as.numeric(arguments$sample)
min_cell <- as.numeric(arguments$min_cell_count)
earliest_start <- as.Date(arguments$earliest_start_date)
by_concept <- arguments$byConcept

subset_ids <- if (is.null(arguments$subset_to_concept_id)) NULL else parseIntegerVector(arguments$subset_to_concept_id)
exposure_type <- if (is.null(arguments$exposure_type_id)) NULL else as.numeric(arguments$exposure_type_id)
table_prefix <- arguments$table_prefix

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