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

CDMConnector::cdmDisconnect(cdm)