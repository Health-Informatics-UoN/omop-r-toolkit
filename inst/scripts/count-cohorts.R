'Count members of a cohort.

Usage:
  count_cohorts.R <name> [--outputPath=<outputPath>]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --outputPath=<outputPath>   Path to write the output csv to [default: outputs/output.csv]

' -> doc

library(CohortCharacteristics)
library(docopt)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")

arguments <- docopt(doc, version = "Count cohorts 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)

write.table(summariseCohortCount(cdm[[arguments$name]]), arguments$outputPath)

CDMConnector::cdmDisconnect(cdm)
