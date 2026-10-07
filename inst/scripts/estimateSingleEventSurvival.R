'Estimate survival for a single event of interest

Usage:
  estimateSingleEventSurvival.R [options]

Options:
  -h --help                           Show this screen
  --version                           Show version
  --targetCohortTable=<tableName>     Name of the cohort table containing the target cohorts. The table must be present in cdm and contain standard OMOP cohort columns.
  --outcomeCohortTable=<tableName>    Name of the cohort table containing the outcome cohorts. The table must be present in cdm and contain standard OMOP cohort columns.
  --outputPath=<path>                 Path for saving the survival table as a csv [default: outputs/single-event-survival.csv]
  --targetCohortId=<cohortId>         Target cohorts to include. It can either be a cohort_definition_id value or a cohort_name. Multiple ids are allowed. If not provided, all non-empty cohorts in targetCohortTable are used.
  --outcomeCohortId=<cohortId>        Outcome cohorts to include. It can either be a cohort_definition_id value or a cohort_name. Multiple ids are allowed. If not provided, all outcome cohorts in outcomeCohortTable are used.
  --outcomeDateVariable=<columnName>  Variable containing the outcome event date. This is usually cohort_start_date, but another date column in the outcome cohort can be used.  [default: cohort_start_date]
  --outcomeWashout=<days>             Number of days before target cohort entry used to exclude people with a prior outcome. Inf excludes people with any prior outcome before index; 0 applies no pre-index washout. [default: Inf]
  --censorOnCohortExit                If TRUE, an individual\'s follow up will be censored at their target cohort exit date.
  --censorOnDate=<date>               If provided, an individual\'s follow up will be censored at the given date. This can be a scalar Date or the name of a date column in the target cohort table.
  --weight=<columnName>               If provided, the name of a numeric column in the target cohort table containing observation weights to use in the Kaplan-Meier estimation.
  --followUpDays=<days>               Number of days to follow up individuals (lower bound 1, upper bound Inf). Follow-up is censored at this value. [default: Inf]
  --strata=<columnNames>              An optional list of target cohort column names to stratify by. Each element can be one column name or a character vector of column names for a combined stratum, for example the input could be ["sex", ["age_group", "sex"]] which will be interpreted as list("sex", c("age_group", "sex")).
  --eventGap=<days>                   Days between time points for which to report survival events, which are grouped into the specified intervals. [default: 30]
  --estimateGap=<days>                Days between time points for which to report survival estimates. First day will be day zero with risk estimates provided for times up to the end of follow-up, with a gap in days equivalent to estimateGap. [default: 1]
  --restrictedMeanFollowUp=<days>     Number of days of follow-up to use when calculating restricted mean survival. See Details.
  --minimumSurvivalDays=<days>        Minimum number of days required for the main cohort to contribute to the analysis. [default: 1]
' -> doc

source("R/postgres-connect-5s-tes.R")
source("R/parseIntList.R")
source("R/parseDateVector.R")
source("R/parseStrata.R")
source("R/cleanCohortTables.R")

arguments <- docopt::docopt(doc, version = "Estimate single event survival 0.1.0")

# Parse arguments and throw any errors

if (is.null(arguments$targetCohortTable)
  | is.null(arguments$outcomeCohortTable)) {
  stop("You need to specify both a target and an outcome cohort table")
}

outcomeWashout <- parseStringAsInts(arguments$outcomeWashout, 1, 0, Inf)
censorOnDate <- if (is.null(arguments$censorOnDate)) NULL else parseMaybeDate(arguments$censorOnDate)
followUpDays <- parseStringAsInts(arguments$followUpDays, 1, 1, Inf)
strata <- if (is.null(arguments$strata)) NULL else parseStrata(arguments$strata)
eventGap <- parseStringAsInts(arguments$eventGap, 1, 1, Inf)
estimateGap <- parseStringAsInts(arguments$estimateGap, 1, 1, Inf)
restrictedMeanFollowUp <- if (is.null(arguments$restrictedMeanFollowUp)) NULL else parseStringAsInts(arguments$restrictedMeanFollowUp, 1, 1, Inf)
minimumSurvivalDays <- ifelse(is.null(arguments$minimumSurvivalDays), NULL, parseStringAsInts(arguments$minimumSurvivalDays, 1, 1, Inf))

# If arguments are OK, connect to database
cdm <- connectFiveSafesTESPg(
  "postgres_omop",
  cohortTables = c(
    arguments$targetCohortTable,
    arguments$outcomeCohortTable
  )
)

surv <- CohortSurvival::estimateSingleEventSurvival(
  cdm = cdm,
  targetCohortTable = arguments$targetCohortTable,
  outcomeCohortTable = arguments$outcomeCohortTable,
  targetCohortId = arguments$targetCohortId,
  outcomeCohortId = arguments$outcomeCohortId,
  outcomeDateVariable = arguments$outcomeDateVariable,
  outcomeWashout = outcomeWashout,
  censorOnCohortExit = !is.null(arguments$censorOnCohortExit),
  censorOnDate = censorOnDate, # Distressingly, this can be a date, or a column name, or NULL
  weight = arguments$weight,
  followUpDays = followUpDays,
  strata = strata,
  eventGap = eventGap,
  estimateGap = estimateGap,
  restrictedMeanFollowUp = restrictedMeanFollowUp,
  minimumSurvivalDays = minimumSurvivalDays
)

omopgenerics::exportSummarisedResult(surv, fileName = arguments$outputPath)

# Estimating survival means generating lots of temporary tables beginning with the prefix og_
# At first, I thought this would be way harder, but the cdm object only keeps track of your tables, so it's not so bad
cleanPrefixTables(cdm, "og_")

CDMConnector::cdmDisconnect(cdm)