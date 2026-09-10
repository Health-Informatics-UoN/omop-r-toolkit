'Add cohort intersection flag and summarize.

Usage:
  addCohortIntersectFlag.R <name> --targetCohortTable=<target> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the output csv to [default: outputs/intersect_flag.csv]
  --targetCohortTable=<target>  Name of the target cohort table
  --targetCohortId=<id>         Specific cohort definition ID (optional)
  --window=<window>             Window relative to index date [default: -Inf,-1]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --targetStartDate=<col>       Start date column in target cohort [default: cohort_start_date]
  --targetEndDate=<col>         End date column in target cohort [default: cohort_end_date]
  --nameStyle=<style>           Naming pattern for new columns [default: {cohort_name}_{window_name}]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(PatientProfiles)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseWindows.R")

arguments <- docopt(doc, version = "Add Cohort Intersect Flag 0.2.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = c(arguments$name, arguments$targetCohortTable))
cohort <- cdm[[arguments$name]]
orig_names <- colnames(cohort)

window <- parseWindows(arguments$window)
targetCohortId <- if (!is.null(arguments$targetCohortId)) as.numeric(arguments$targetCohortId) else NULL

cohort <- cohort |>
  addCohortIntersectFlag(
    targetCohortTable = arguments$targetCohortTable,
    targetCohortId = targetCohortId,
    window = window,
    indexDate = arguments$indexDate,
    targetStartDate = arguments$targetStartDate,
    targetEndDate = arguments$targetEndDate,
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