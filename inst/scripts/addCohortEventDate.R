'Find first or last cohort event date and summarize.

Usage:
  addCohortEventDate.R <name> --targetCohortTable=<target> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the output csv to [default: outputs/event_date.csv]
  --targetCohortTable=<target>  Name of the target cohort table
  --targetCohortId=<id>         Specific cohort definition ID (optional)
  --window=<window>             Window [default: [[-Inf,Inf]]]
  --order=<order>               first or last [default: first]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --targetDate=<col>            Date column in target cohort [default: cohort_start_date]
  --censorDate=<col>            Optional censor date column
  --nameStyle=<style>           Naming pattern [default: {value}_{window_name}]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(PatientProfiles)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseWindows.R")

arguments <- docopt(doc, version = "Add Cohort Event Date 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = c(arguments$name, arguments$targetCohortTable))
cohort <- cdm[[arguments$name]]
orig_names <- colnames(cohort)

window <- parseWindows(arguments$window)
targetCohortId <- if (!is.null(arguments$targetCohortId)) as.numeric(arguments$targetCohortId) else NULL
censorDate <- if (!is.null(arguments$censorDate)) arguments$censorDate else NULL

cohort <- cohort |>
  addCohortEventDate(
    targetCohortTable = arguments$targetCohortTable,
    targetCohortId = targetCohortId,
    window = window,
    order = arguments$order,
    indexDate = arguments$indexDate,
    targetDate = arguments$targetDate,
    censorDate = censorDate,
    nameStyle = arguments$nameStyle
  )

new_names <- setdiff(colnames(cohort), orig_names)

# Infer types from sample
sample_df <- cohort |> head(10) |> collect()

summaries <- list()
for (col in new_names) {
  if (is.character(sample_df[[col]])) {
    dist <- cohort |>
      group_by(!!sym(col)) |>
      summarise(estimate = as.numeric(n()), .groups = "drop") |>
      collect() |>
      mutate(column = col, metric = "frequency", value = !!sym(col)) |>
      select(column, metric, value, estimate)
    summaries[[length(summaries) + 1]] <- dist
  } else if (inherits(sample_df[[col]], "Date")) {
    stats <- cohort |>
      summarise(non_missing = as.numeric(sum(as.integer(!is.na(!!sym(col))))),
                earliest = min(!!sym(col), na.rm = TRUE),
                latest = max(!!sym(col), na.rm = TRUE)) |>
      collect()
    summaries[[length(summaries) + 1]] <- data.frame(
      column = col, metric = c("non_missing", "earliest", "latest"),
      value = c(NA, as.character(stats$earliest), as.character(stats$latest)),
      estimate = c(stats$non_missing, NA, NA), stringsAsFactors = FALSE
    )
  }
}

write.csv(do.call(rbind, summaries), file = arguments$output_path, row.names = FALSE)
CDMConnector::cdmDisconnect(cdm)