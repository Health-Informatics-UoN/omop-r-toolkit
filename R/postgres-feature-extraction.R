library("FeatureExtraction")
library("DatabaseConnector")

# Use the parameters named as the default 5s-TES agent
DB_HOST <- Sys.getenv("postgresServer")
DB_PORT <- Sys.getenv("postgresPort")
DB_USERNAME <- Sys.getenv("postgresUsername")
DB_PASSWORD <- Sys.getenv("postgresPassword")
DB_NAME <- Sys.getenv("postgresDatabase")
DB_SCHEMA <- Sys.getenv("postgresSchema")

jdbc_string = sprintf("jdbc:postgresql://%s:%s/%s", DB_HOST, DB_PORT, DB_NAME)

connectionDetails <- createConnectionDetails(
  dbms="postgresql",
  connectionString=jdbc_string,
  user=DB_USERNAME,
  password=DB_PASSWORD
)

settings <- createDefaultCovariateSettings()


