'Clean up cohort tables

Usage:
  cleanUpCohortTables.R <name> ...

Options:
  -h --help                     Show this screen
  --version                     Show version
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/cleanCohortTables.R")
source("R/parseIntList.R")

arguments <- docopt(doc, version = "Clean up cohort tables 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)

cdm <- cleanUpTables(cdm, arguments$name)

CDMConnector::cdmDisconnect(cdm)