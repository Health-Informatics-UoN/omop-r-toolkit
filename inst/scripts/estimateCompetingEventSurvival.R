'Estimate time-to-event probabilities for one or more target cohorts when an event of interest can be precluded by a competing outcome.

Usage:
  estimateCompetingEventSurvial.R [options]

Options:
  -h --help                                  Show this screen
  --version                                  Show version
  --targetCohortTable=<table>                Name of the cohort table containing the target cohorts. The table must be present in cdm and contain standard OMOP cohort columns.
  --outcomeCohortTable=<table>               Name of the cohort table containing the outcome of interest.
  --competingOutcomeCohortTable=<table>      Name of the cohort table containing the competing outcome.
  --outputPath=<path>                 Path for saving the survival table as a csv [default: outputs/competing-event-survival.csv]
  --targetCohortId=<id>                      Target cohorts to include. It can either be a cohort_definition_id value or a cohort_name. Multiple ids are allowed. If omitted, all non-empty cohorts in targetCohortTable are used.
  --outcomeCohortId=<id>                     Outcome cohorts to include. It can either be a cohort_definition_id value or a cohort_name. Multiple ids are allowed. If omitted, all outcome cohorts in outcomeCohortTable are used.
  --outcomeDateVariable=<variable>           Variable containing the outcome event date. This is usually "cohort_start_date", but another date column in the outcome cohort can be used. [default: cohort_start_date]
  --outcomeWashout=<days>                    Number of days before target cohort entry used to exclude people with a prior outcome. Inf excludes people with any prior outcome before index; 0 applies no pre-index washout. [default: Inf]
  --competingOutcomeCohortId=<id>            Competing outcome cohorts to include. It can either be a cohort_definition_id value or a cohort_name. Multiple ids are allowed. If omitted, all competing outcome cohorts in competingOutcomeCohortTable are used.
  --competingOutcomeDateVariable=<variable>  Variable containing the competing outcome event date. [default: cohort_start_date]
  --competingOutcomeWashout=<days>           Number of days before target cohort entry used to exclude people with a prior competing outcome. Inf excludes people with any prior competing outcome before index; 0 applies no pre-index washout. [default: Inf]
  --censorOnCohortExit                       If active, an individual\'s follow up will be censored at their target cohort exit date.
  --censorOnDate=<date>                      If specified, an individual\'s follow up will be censored at the given date. This can be a scalar Date or the name of a date column in the target cohort table.
  --weight=<weight>                          If specified, the name of a numeric column in the target cohort table containing observation weights.
  --followUpDays=<days>                      Number of days to follow up individuals (lower bound 1, upper bound Inf). Follow-up is censored at this value. [default: Inf]
  --strata=<strata>                          A list of target cohort column names to stratify by. Each element can be one column name or a character vector of column names for a combined stratum, for example list("sex", c("age_group", "sex")).
  --eventGap=<gap>                           Days between time points for which to report survival events, which are grouped into the specified intervals. [default: 30]
  --estimateGap=<gap>                        Days between time points for which to report survival estimates. First day will be day zero with risk estimates provided for times up to the end of follow-up, with a gap in days equivalent to estimateGap. [default: 1]
  --restrictedMeanFollowUp=<days>            Number of days of follow-up to use when calculating restricted mean summaries. See Details.
  --minimumSurvivalDays=<days>               Minimum number of days required for the main cohort to contribute to the analysis. [default: 1]
' -> doc

source("R/postgres-connect-5s-tes.R")
source("R/parseIntList.R")
source("R/parseDateVector.R")
source("R/parseStrata.R")
source("R/cleanCohortTables.R")

arguments <- docopt::docopt(doc)

# Parse arguments and throw any errors

if (is.null(arguments$targetCohortTable)
  | is.null(arguments$outcomeCohortTable)
  | is.null(arguments$competingOutcomeCohortTable)) {
  stop("You need to specify target, outcome, and competing outcome cohort tables")
}


# If arguments are OK, connect to a database
cdm <- connectFiveSafesTESPg(
  "postgres_omop",
  cohortTables = c(
    arguments$targetCohortTable,
    arguments$outcomeCohortTable,
    arguments$competingOutcomeCohortTable
  )
)

targetCohortId = if (is.null(arguments$targetCohortId)) NULL else unlist(jsonlite::parse_json(arguments$targetCohortId)) # vector of either string or int
outcomeCohortId = if (is.null(arguments$outcomeCohortId)) NULL else unlist(jsonlite::parse_json(arguments$outcomeCohortId))
outcomeWashout = parseStringAsInts(arguments$outcomeWashout, 1, 0)
competingOutcomeCohortId = if (is.null(arguments$competingOutcomeCohortId)) NULL else unlist(jsonlite::parse_json(arguments$competingOutcomeCohortId))
competingOutcomeWashout = parseStringAsInts(arguments$competingOutcomeWashout, 1, 0)
censorOnDate <- if (is.null(arguments$censorOnDate)) NULL else parseMaybeDate(arguments$censorOnDate)
followUpDays <- parseStringAsInts(arguments$followUpDays, 1, 1, Inf)
strata <- if (is.null(arguments$strata)) NULL else parseStrata(arguments$strata)
eventGap <- parseStringAsInts(arguments$eventGap, 1, 1, Inf)
estimateGap <- parseStringAsInts(arguments$estimateGap, 1, 1, Inf)
restrictedMeanFollowUp <- if (is.null(arguments$restrictedMeanFollowUp)) NULL else parseStringAsInts(arguments$restrictedMeanFollowUp, 1, 1, Inf)
minimumSurvivalDays <- ifelse(is.null(arguments$minimumSurvivalDays), NULL, parseStringAsInts(arguments$minimumSurvivalDays, 1, 1, Inf))

surv <- CohortSurvival::estimateCompetingRiskSurvival(
  cdm,
  targetCohortTable = arguments$targetCohortTable ,
  outcomeCohortTable = arguments$outcomeCohortTable,
  competingOutcomeCohortTable = arguments$competingOutcomeCohortTabl,
  targetCohortId = targetCohortId,
  outcomeCohortId = outcomeCohortId,
  outcomeDateVariable = arguments$outcomeDateVariable,
  outcomeWashout = outcomeWashout,
  competingOutcomeCohortId = competingOutcomeCohortId,
  competingOutcomeDateVariable = arguments$competingOutcomeDateVariable,
  competingOutcomeWashout = competingOutcomeWashout,
  censorOnCohortExit = !(is.null(arguments$censorOnCohortExit)),
  censorOnDate = censorOnDate,
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