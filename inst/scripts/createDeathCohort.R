'Create a death cohort

Usage:
  createDeathCohort.R <name> [options]

Options:
  -h --help   Show this screen
  --version   Show version
  --subsetCohort=<table_name>    Optional. A character refering to a cohort table containing individuals for whom cohorts will be generated. Only individuals in this table will appear in the generated cohort.
  --subsetCohortId=<ids>          Optional. Specifies cohort IDs from the subsetCohort table to include. If none are provided, all cohorts from the subsetCohort are included.
' -> doc

source("R/postgres-connect-5s-tes.R")
source("R/parseIntList.R")

arguments <- docopt::docopt(doc, version = "Cohort Survival 0.1.0")
# In the documentation for deathCohort they only ever supply a single subsetCohort, so let's assume that behaviour until someone complains
cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$subsetCohort) 

deathCohort <- CohortConstructor::deathCohort(
    cdm,
    name = arguments$name,
    subsetCohort = arguments$subsetCohort,
    subsetCohortId = if (is.null(arguments$subsetCohortId)) NULL else parseStringAsInts(arguments$subsetCohortId)
  )

CDMConnector::cdmDisconnect(cdm)
