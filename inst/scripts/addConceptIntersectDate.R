'Add concept intersection date and summarize.

Usage:
  addConceptIntersectDate.R <name> --conceptSet=<json> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the output csv to [default: outputs/concept_intersect_date.csv]
  --conceptSet=<json>           JSON concept set
  --window=<window>             Window [default: [[-Inf,Inf]]]
  --order=<order>               first or last [default: first]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --nameStyle=<style>           Naming pattern [default: {concept_name}_{window_name}]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(PatientProfiles)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseConceptSet.R")
source("R/parseWindows.R")

arguments <- docopt(doc, version = "Add Concept Intersect Date 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)
cohort <- cdm[[arguments$name]]

conceptSet <- parseJSONConceptSet(arguments$conceptSet)
window <- parseWindows(arguments$window)

cohort <- cohort |>
  addConceptIntersectDate(
    conceptSet = conceptSet,
    window = window,
    order = arguments$order,
    indexDate = arguments$indexDate,
    nameStyle = arguments$nameStyle
  )

CDMConnector::cdmDisconnect(cdm)