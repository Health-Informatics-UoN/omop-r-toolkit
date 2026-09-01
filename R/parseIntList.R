#' There are a couple of places we need to parse a string as a vector of integers and check that we have the right length

#' Parse a comma-separated string of integers
#' 
#' With a supplied string of integers, check the numbers parse as integers, then check you have the right count of numbers within limits
#' @param intString A string you want to parse as integers
#' @param n The number of integers you want out. If NULL, is an unrestricted number
#' @param lowerLimit An integer specifying the lowest number you want to see at the end
#' @param upperLimit An integer specifying the highest number you want to see at the end
#' @return Returns a vector of integers if criteria are matched
parseStringAsInts <- function(
  intString,
  n = NULL,
  lowerLimit = -Inf,
  upperLimit = Inf
) {
  nums <- as.numeric(strsplit(intString, ",")[[1]])

  if (any(nums != as.integer(nums))){
    stop("Not all of these are integers!")
  }

  if (!is.null(n) & length(nums) != n) {
    stop(sprintf("Expected %d integers, got %d", n, length(nums)))
  }

  if (!all(nums >= lowerLimit)) {
    stop(sprintf("Not all of the numbers are greater than your lower limit, %d", lowerLimit))
  }

  if (!all(nums <= upperLimit)) {
    stop(sprintf("Not all of the numbers are less than your upper limit, %d", upperLimit))
  }

  nums
}