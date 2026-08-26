#' There are a couple of places we need to parse a string as a vector of integers and check that we have the right length

parseIntegerVector <- function(intString) {
  as.numeric(strsplit(intString, ",")[[1]])
}

parseNInts <- function(intString, n) {
  ints <- parseIntegerVector(intString)

  if (length(ints) != n) {
    stop(sprintf("Expected %d integers, got %d", n, length(ints)))
  }

  ints
}