library(CDMConnector)
library(DBI)
library(dplyr)
library(RPostgresSQL)

# Use the parameters named as the default 5s-TES agent
DB_HOST <- Sys.getenv("postgresServer")
# Can't find the port config name
DB_PORT <- 5432
DB_USERNAME <- Sys.getenv("postgresUsername")
DB_PASSWORD <- Sys.getenv("postgresPassword")
DB_NAME <- Sys.getenv("postgresDatabase")
DB_SCHEMA <- Sys.getenv("postgresSchema")

drv <- DBI::dbDriver("PostgreSQL")

con <- DBI::dbConnect(
  drv,
  dbname = DB_NAME,
  host = DB_HOST,
  port = DB_PORT,
  password = DB_PASSWORD,
  user = DB_USERNAME,
)

cdm <- cdmFromCon(con = con, 
                  cdmSchema = DB_SCHEMA, 
                  cdmName = "postgres_omop")

print(names(cdm))
