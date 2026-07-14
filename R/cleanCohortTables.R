library(CDMConnector)

cleanUpTables <- function(cdm, prefix) {
  names <- c("_attrition", "_codelist", "_set")
  tables <- sprintf("%s%s", prefix, names)
  dropTable(cdm, prefix)
  dropTable(cdm, tables)
  cdm
}

