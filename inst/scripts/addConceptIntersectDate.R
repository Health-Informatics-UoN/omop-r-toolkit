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
orig_names <- colnames(cohort)

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

new_names <- setdiff(colnames(cohort), orig_names)

summaries <- lapply(new_names, function(col) {
  stats <- cohort |>
    summarise(total = as.numeric(n()),
              non_missing = as.numeric(sum(as.integer(!is.na(!!sym(col))))),
              earliest = min(!!sym(col), na.rm = TRUE),
              latest = max(!!sym(col), na.rm = TRUE)) |>
    collect()
  data.frame(column = col, total = stats$total, non_missing = stats$non_missing,
             earliest = as.character(stats$earliest), latest = as.character(stats$latest),
             stringsAsFactors = FALSE)
})

write.csv(do.call(rbind, summaries), file = arguments$output_path, row.names = FALSE)
CDMConnector::cdmDisconnect(cdm)