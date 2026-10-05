#' Names of a cohort table and its companion tables (_attrition, _codelist, _set), for one or more cohorts

cohortTableNames <- function(names) {
  suffixes <- c("_attrition", "_codelist", "_set")
  c(names, as.vector(outer(names, suffixes, paste0)))
}

cleanUpTables <- function(cdm, names) {
  omopgenerics::dropSourceTable(cdm = cdm, name = cohortTableNames(names))
  cdm
}