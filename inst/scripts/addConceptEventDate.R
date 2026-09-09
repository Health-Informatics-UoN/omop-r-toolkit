'Find first or last concept event date and summarize.

Usage:
  addConceptEventDate.R <name> --conceptSet=<json> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the output csv to [default: outputs/concept_event_date.csv]
  --conceptSet=<json>           JSON concept set ({"name": [concept_id, ...]})
  --window=<window>             Window [default: [[-Inf,Inf]]]
  --order=<order>               first or last [default: first]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --targetDate=<type>           event_start_date or event_end_date [default: event_start_date]
  --censorDate=<col>            Optional censor date column
  --multipleEvents=<mode>       null, true, or comma-separated priority list [default: null]
  --nameStyle=<style>           Naming pattern [default: {value}_{window_name}]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(PatientProfiles)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseConceptSet.R")
source("R/parseWindows.R")
source("R/parseMultipleEvents.R")

arguments <- docopt(doc, version = "Add Concept Event Date 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = arguments$name)
cohort <- cdm[[arguments$name]]
orig_names <- colnames(cohort)

conceptSet <- parseJSONConceptSet(arguments$conceptSet)
window <- parseWindows(arguments$window)
censorDate <- if (!is.null(arguments$censorDate)) arguments$censorDate else NULL
multipleEvents <- parseMultipleEvents(arguments$multipleEvents)

cohort <- cohort |>
  addConceptEventDate(
    conceptSet = conceptSet,
    window = window,
    order = arguments$order,
    indexDate = arguments$indexDate,
    targetDate = arguments$targetDate,
    censorDate = censorDate,
    multipleEvents = multipleEvents,
    nameStyle = arguments$nameStyle
  )

new_names <- setdiff(colnames(cohort), orig_names)
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