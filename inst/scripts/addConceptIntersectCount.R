'Add concept intersection count and summarize.

Usage:
  addConceptIntersectCount.R <name> --conceptSet=<json> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the output csv to [default: outputs/concept_intersect_count.csv]
  --conceptSet=<json>           JSON concept set
  --window=<window>             Window [default: [[-Inf,Inf]]]
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

arguments <- docopt(doc, version = "Add Concept Intersect Count 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)
cohort <- cdm[[arguments$name]]
orig_names <- colnames(cohort)

conceptSet <- parseJSONConceptSet(arguments$conceptSet)
window <- parseWindows(arguments$window)

cohort <- cohort |>
  addConceptIntersectCount(
    conceptSet = conceptSet,
    window = window,
    indexDate = arguments$indexDate,
    nameStyle = arguments$nameStyle
  )

new_names <- setdiff(colnames(cohort), orig_names)

summaries <- lapply(new_names, function(col) {
  stats <- cohort |>
    summarise(total = as.numeric(n()),
              non_missing = as.numeric(sum(as.integer(!is.na(!!sym(col))))),
              mean = mean(!!sym(col), na.rm = TRUE),
              min = min(!!sym(col), na.rm = TRUE),
              max = max(!!sym(col), na.rm = TRUE)) |>
    collect()
  data.frame(column = col, total = stats$total, non_missing = stats$non_missing,
             mean = round(stats$mean, 2), min = stats$min, max = stats$max,
             stringsAsFactors = FALSE)
})

write.csv(do.call(rbind, summaries), file = arguments$output_path, row.names = FALSE)
CDMConnector::cdmDisconnect(cdm)