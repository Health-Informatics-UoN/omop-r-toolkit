#' There are a couple of places we need to parse a string as a vector of integers and check that we have the right length

#' Check that every value is whole (no fractional part) and not NA
#' @param nums A numeric vector
#' @return The input vector, unchanged, if all values are whole numbers
checkInts <- function(nums) {
  if (any(is.na(nums))) {
    stop("Couldn't parse one or more values as numbers")
  }
  if (any(nums %% 1 != 0 & nums != Inf)){
    stop("Not all of these are integers!")
  }
  nums
}

#' Check that a vector has an expected length
#' @param nums A vector
#' @param n The expected length, or NULL to allow any length
#' @return The input vector, unchanged, if the length matches
checkLength <- function(nums, n) {
  if (!is.null(n) && length(nums) != n) {
    stop(sprintf("Expected %d integers, got %d", n, length(nums)))
  }
  nums
}

#' Check that every value is at or above a lower limit
#' @param nums A numeric vector
#' @param lowerLimit The minimum allowed value
#' @return The input vector, unchanged, if all values satisfy the limit
checkLowerLimit <- function(nums, lowerLimit) {
  if (!all(nums >= lowerLimit)) {
    stop(sprintf("Not all of the numbers are greater than your lower limit, %s", lowerLimit))
  }
  nums
}

#' Check that every value is at or below an upper limit
#' @param nums A numeric vector
#' @param upperLimit The maximum allowed value
#' @return The input vector, unchanged, if all values satisfy the limit
checkUpperLimit <- function(nums, upperLimit) {
  if (!all(nums <= upperLimit)) {
    stop(sprintf("Not all of the numbers are less than your upper limit, %s", upperLimit))
  }
  nums
}

#' Parse a comma-separated string of integers
#' 
#' With a supplied string of integers, check the numbers parse as integers, then check you have the right count of numbers within limits
#' @param intString A string you want to parse as integers
#' @param n The number of integers you want out. If NULL, is an unrestricted number
#' @param lowerLimit An integer specifying the lowest number you want to see at the end
#' @param upperLimit An integer specifying the highest number you want to see at the end
#' @return Returns a vector of whole numbers if criteria are matched
parseStringAsInts <- function(
  intString,
  n = NULL,
  lowerLimit = -Inf,
  upperLimit = Inf
) {
  strsplit(intString, ",")[[1]] |>
    as.numeric() |>
    checkInts() |>
    checkLength(n) |>
    checkLowerLimit(lowerLimit) |>
    checkUpperLimit(upperLimit)
}