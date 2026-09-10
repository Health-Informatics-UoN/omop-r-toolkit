'Add table intersection count and summarize.

Usage:
  addTableIntersectCount.R <name> --tableName=<table> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the output csv to [default: outputs/table_intersect_count.csv]
  --tableName=<table>           OMOP table name
  --window=<window>             Window [default: [-Inf,Inf]]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --targetStartDate=<col>       Start date column in target table
  --targetEndDate=<col>         End date column in target table
  --inObservation=<logical>     Keep only records in observation [default: TRUE]
  --nameStyle=<style>           Naming pattern [default: {table_name}_{window_name}]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(PatientProfiles)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseWindows.R")

arguments <- docopt(doc, version = "Add Table Intersect Count 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)
cohort <- cdm[[arguments$name]]
orig_names <- colnames(cohort)

indexDate <- if (is.null(arguments$indexDate) || !nzchar(arguments$indexDate)) "cohort_start_date" else arguments$indexDate
window <- parseWindows(arguments$window)
targetStartDate <- if (!is.null(arguments$targetStartDate) && nzchar(arguments$targetStartDate)) arguments$targetStartDate else startDateColumn(arguments$tableName)
targetEndDate <- if (!is.null(arguments$targetEndDate) && nzchar(arguments$targetEndDate)) arguments$targetEndDate else endDateColumn(arguments$tableName)
inObservation <- as.logical(arguments$inObservation)

cohort <- cohort |>
  addTableIntersectCount(
    tableName = arguments$tableName,
    window = window,
    indexDate = indexDate,
    targetStartDate = targetStartDate,
    targetEndDate = targetEndDate,
    inObservation = inObservation,
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