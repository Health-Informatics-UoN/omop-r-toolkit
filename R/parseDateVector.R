#' Takes a comma-separated string listing dates and turns them into a vector of dates.
#' Optionally checks whether a specified number of dates are returned

parseDates <- function(dateString) {
  as.Date(strsplit(dateString, ",")[[1]])
}

parseNDates <- function(dateString, n) {
  dates <- parseDates(dateString)
  if (length(dates) != n) {
    stop(sprintf(
      "When parsing dates %s, expected %d dates, instead got %d",
      dateString,
      n,
      length(dateString)
    ))
  }
  dates
}