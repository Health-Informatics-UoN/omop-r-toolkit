#' Takes a comma-separated string listing dates and turns them into a vector of dates.
#' Optionally checks whether a specified number of dates are returned

parseDates <- function(dateString) {
  as.date(strsplit(dateString, ",")[[1]])
}
