library(CDMConnector)
library(DBI)
library(RPostgres)

#' Uses the default postgres connection environment variables for Five Safes TES to connect to an OMOP database
#' Returns a cdm using CDMConnector
connectFiveSafesTESPg <- function(cdmName, writePrefix) {
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
  
  cdmFromCon(
    con = con,
    cdmSchema = DB_SCHEMA, 
    writeSchema = DB_SCHEMA,
    cdmName = cdmName,
    writePrefix = writePrefix
  )
}
