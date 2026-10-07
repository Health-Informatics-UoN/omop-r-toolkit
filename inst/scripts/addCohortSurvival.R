'Add time and event status to a cohort table

Usage:
  addCohortSurvival.R <tableName> [options]

Options:
  -h --help                           Show this screen
  --version                           Show version
  --name=<tableName>                  Name of the new table. In the library this is optional, but must be specified to use the output.
  --outcomeCohortTable=<table>        Name of the cohort table containing the outcome of interest
  --outcomeCohortId=<id>              IDs of event cohorts to include. Values can be cohort definition IDs or cohort names [default: 1]
  --outcomeDateVariable=<variable>    Variable containing date of outcome event. [default: cohort_start_date]
  --outcomeWashout=<days>             Washout time in days for the outcome. If an individual has an outcome during the washout period before target cohort entry, status and time will be set to NA. Use Inf for any prior outcome and 0 for no pre-index washout. [default: Inf]
  --censorOnCohortExit                If active, an individual\'s follow up will be censored at their target cohort exit.
  --censorOnDate=<date>               If specified, an individual\'s follow up will be censored at the given date. This can be a scalar Date or the name of a date column
  --followUpDays=<days>               Number of days to follow up individuals (lower bound 1, upper bound Inf). Follow-up is censored at this value. [default: Inf]
' -> doc

source("R/postgres-connect-5s-tes.R")
source("R/parseIntList.R")
source("R/parseDateVector.R")

arguments = docopt::docopt(doc, version="Add cohort survival version 0.1.0")

if (is.null(arguments$name)) {
  stop("The output table name (--name) must be specified to use the output later.")
}

outcomeCohortId <- parseStringAsInts(arguments$outcomeCohortId, 1, 0)
outcomeWashout <- parseStringAsInts(arguments$outcomeWashout, 1, 0, Inf)
censorOnDate <- if (is.null(arguments$censorOnDate)) NULL else parseMaybeDate(arguments$censorOnDate)
followUpDays <- parseStringAsInts(arguments$followUpDays, 1, 1, Inf)

# If arguments are OK, connect to database
cdm <- connectFiveSafesTESPg(
  "postgres_omop",
  cohortTables = c(
    arguments$tableName,
    arguments$outcomeCohortTable
  )
)

cohort <- CohortSurvival::addCohortSurvival(
  x = cdm[[arguments$tableName]],
  cdm = cdm,
  outcomeCohortTable = arguments$outcomeCohortTable,
  outcomeCohortId = outcomeCohortId,
  outcomeDateVariable = arguments$outcomeDateVariable,
  outcomeWashout = outcomeWashout,
  censorOnCohortExit = !is.null(arguments$censorOnCohortExit),
  censorOnDate = censorOnDate,
  followUpDays = followUpDays,
  name = arguments$name
)

cdm[[arguments$name]] <- cohort |>
  dplyr::compute(name = arguments$name, temporary = FALSE, overwrite = TRUE)