library(CDMConnector)

cleanUpTables <- function(cdm, prefix) {
  names <- c("_attrition", "_codelist", "_set")
  tables <- sprintf("%s%s", prefix, names)
  CDMConnector::dropTable(cdm, prefix)
  CDMConnector::dropTable(cdm, tables)
  cdm
}
