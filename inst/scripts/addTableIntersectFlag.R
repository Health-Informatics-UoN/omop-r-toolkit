'Add table intersection flag and summarize.

Usage:
  addTableIntersectFlag.R <name> --tableName=<table> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the output csv to [default: outputs/table_intersect_flag.csv]
  --tableName=<table>           OMOP table name (e.g. drug_exposure)
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

arguments <- docopt(doc, version = "Add Table Intersect Flag 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)
cohort <- cdm[[arguments$name]]
orig_names <- colnames(cohort)

indexDate <- if (is.null(arguments$indexDate) || !nzchar(arguments$indexDate)) "cohort_start_date" else arguments$indexDate
window <- parseWindows(arguments$window)
targetStartDate <- if (!is.null(arguments$targetStartDate) && nzchar(arguments$targetStartDate)) arguments$targetStartDate else startDateColumn(arguments$tableName)
targetEndDate <- if (!is.null(arguments$targetEndDate) && nzchar(arguments$targetEndDate)) arguments$targetEndDate else endDateColumn(arguments$tableName)
inObservation <- as.logical(arguments$inObservation)

cohort <- cohort |>
  addTableIntersectFlag(
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