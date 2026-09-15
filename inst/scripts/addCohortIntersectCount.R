'Add cohort intersection count and summarize.

Usage:
  addCohortIntersectCount.R <name> --targetCohortTable=<target> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --targetCohortTable=<target>  Name of the target cohort table
  --targetCohortId=<id>         Specific cohort definition ID (optional)
  --window=<window>             Window [default: -Inf,Inf]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --targetStartDate=<col>       Start date column in target cohort [default: cohort_start_date]
  --targetEndDate=<col>         End date column in target cohort [default: cohort_end_date]
  --nameStyle=<style>           Naming pattern [default: {cohort_name}_{window_name}]
' -> doc

library(dplyr, warn.conflicts = FALSE)
library(docopt)
library(PatientProfiles)
library(CDMConnector)
source("R/postgres-connect-5s-tes.R")
source("R/parseWindows.R")

arguments <- docopt(doc, version = "Add Cohort Intersect Count 0.2.0")

cdm <- connectFiveSafesTESPg("postgres_omop", cohortTables = c(arguments$name, arguments$targetCohortTable))
cohort <- cdm[[arguments$name]]

window <- parseWindows(arguments$window)

cohort <- cohort |>
  addCohortIntersectCount(
    targetCohortTable = arguments$targetCohortTable,
    targetCohortId = if (!is.null(arguments$targetCohortId)) as.numeric(arguments$targetCohortId) else NULL,
    window = window,
    indexDate = arguments$indexDate,
    targetStartDate = arguments$targetStartDate,
    targetEndDate = arguments$targetEndDate,
    nameStyle = arguments$nameStyle
  )

CDMConnector::cdmDisconnect(cdm)