'Add cohort intersection date and summarize.

Usage:
  addCohortIntersectDate.R <name> --targetCohortTable=<target> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the output csv to [default: outputs/intersect_date.csv]
  --targetCohortTable=<target>  Name of the target cohort table
  --targetCohortId=<id>         Specific cohort definition ID (optional)
  --window=<window>             Window [default: -Inf,Inf]
  --order=<order>               first or last occurrence [default: first]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --targetDate=<col>            Date column in target cohort [default: cohort_start_date]
  --nameStyle=<style>           Naming pattern [default: {cohort_name}_{window_name}]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(PatientProfiles)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseWindows.R")

arguments <- docopt(doc, version = "Add Cohort Intersect Date 0.2.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = c(arguments$name, arguments$targetCohortTable))
cohort <- cdm[[arguments$name]]
orig_names <- colnames(cohort)

window <- parseWindows(arguments$window)
targetCohortId <- if (!is.null(arguments$targetCohortId)) as.numeric(arguments$targetCohortId) else NULL

cohort <- cohort |>
  addCohortIntersectDate(
    targetCohortTable = arguments$targetCohortTable,
    targetCohortId = targetCohortId,
    window = window,
    order = arguments$order,
    indexDate = arguments$indexDate,
    targetDate = arguments$targetDate,
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