'Count members of a cohort.

Usage:
  count_cohorts.R <name> [--output-path=<output_path>]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the output csv to [default: outputs/output.csv]

' -> doc

library(CohortCharacteristics)
library(docopt)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")

cdm <- connectFiveSafesTESPg("postgres_omop")

arguments <- docopt(doc, version = "Count cohorts 0.1.0")

write.table(summariseCohortCount(cdm[[arguments$name]]), arguments$output_path)

CDMConnector::cdmDisconnect(cdm)
