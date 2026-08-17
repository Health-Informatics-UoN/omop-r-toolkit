#' Takes conditional statements and returns a list of strings for sex cohorts

cohortGenders <- function(both, female, male) {
  c(
    if (both) {"Both"},
    if (female) {"Female"},
    if(male) {"Male"}
  )
}