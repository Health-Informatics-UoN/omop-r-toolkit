'Add concept intersection flag and summarize.

Usage:
  addConceptIntersectFlag.R <name> --conceptSet=<json> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the output csv to [default: outputs/concept_intersect_flag.csv]
  --conceptSet=<json>           JSON concept set
  --window=<window>             Window [default: [[-Inf,-1]]]
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

arguments <- docopt(doc, version = "Add Concept Intersect Flag 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)
cohort <- cdm[[arguments$name]]
orig_names <- colnames(cohort)

conceptSet <- parseJSONConceptSet(arguments$conceptSet)
window <- parseWindows(arguments$window)

cohort <- cohort |>
  addConceptIntersectFlag(
    conceptSet = conceptSet,
    window = window,
    indexDate = arguments$indexDate,
    nameStyle = arguments$nameStyle
  )

new_names <- setdiff(colnames(cohort), orig_names)

summaries <- lapply(new_names, function(col) {
  dist <- cohort |>
    group_by(!!sym(col)) |>
    summarise(count = as.numeric(n()), .groups = "drop") |>
    collect()
  total <- sum(dist$count)
  with_val <- dist$count[dist[[col]] == 1]
  without_val <- dist$count[dist[[col]] == 0]
  na_val <- dist$count[is.na(dist[[col]])]
  data.frame(
    column = col, total = total,
    with_intersection = ifelse(length(with_val) > 0, with_val, 0),
    without_intersection = ifelse(length(without_val) > 0, without_val, 0),
    missing = ifelse(length(na_val) > 0, na_val, 0),
    percentage_with = round(100 * ifelse(length(with_val) > 0, with_val, 0) / total, 2),
    stringsAsFactors = FALSE
  )
})

write.csv(do.call(rbind, summaries), file = arguments$output_path, row.names = FALSE)
CDMConnector::cdmDisconnect(cdm)