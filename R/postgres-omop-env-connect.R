library(CDMConnector)
library(DBI)
library(dplyr)
library(RPostgres)
library(CohortGenerator)
library(FeatureExtraction)

# Use the parameters named as the default 5s-TES agent
DB_HOST <- Sys.getenv("postgresServer")
DB_PORT <- Sys.getenv("postgresPort")
DB_USERNAME <- Sys.getenv("postgresUsername")
DB_PASSWORD <- Sys.getenv("postgresPassword")
DB_NAME <- Sys.getenv("postgresDatabase")
DB_SCHEMA <- Sys.getenv("postgresSchema")

con <- DBI::dbConnect(
  drv = RPostgres::Postgres(),
  dbname = DB_NAME,
  host = DB_HOST,
  port = DB_PORT,
  password = DB_PASSWORD,
  user = DB_USERNAME,
)

cdm <- cdmFromCon(con = con, 
                  cdmSchema = DB_SCHEMA, 
                  writeSchema = DB_SCHEMA,
                  cdmName = "postgres_omop")

cohortsToCreate <- CohortGenerator::createEmptyCohortDefinitionSet()
cohortJson <- readChar("data/cohorts/skin-cancer-demo.json", file.info("data/cohorts/skin-cancer-demo.json")$size)
cohortExpression <- CirceR::cohortExpressionFromJson(cohortJson)
cohortSql <- CirceR::buildCohortQuery(cohortExpression, options = CirceR::createGenerateOptions(generateStats = FALSE))
cohortsToCreate <- rbind(cohortsToCreate, data.frame(cohortId = 1,
                                                     cohortName = "Skin cancer demo", 
                                                     sql = cohortSql,
                                                     stringsAsFactors = FALSE))

cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = "my_cohort_table")
CohortGenerator::createCohortTables(connectionDetails = cdmFromCon,
                                                        cohortDatabaseSchema = DB_SCHEMA,
                                                        cohortTableNames = cohortTableNames)
# Generate the cohorts
cohortsGenerated <- CohortGenerator::generateCohortSet(connectionDetails = connectionDetails,
                                                       cdmDatabaseSchema = DB_SCHEMA,
                                                       cohortDatabaseSchema = DB_SCHEMA,
                                                       cohortTableNames = cohortTableNames,
                                                       cohortDefinitionSet = cohortsToCreate)

# Get the cohort counts
cohortCounts <- CohortGenerator::getCohortCounts(connectionDetails = connectionDetails,
                                                 cohortDatabaseSchema = DB_SCHEMA,
                                                 cohortTable = cohortTableNames$cohortTable)

print(cohortCounts)
