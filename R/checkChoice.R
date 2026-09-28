#' Check that CLI values are among the allowed options, with an error listing the allowed options.
#' Works for a single value (e.g. --filterTreatments) or several (e.g. --checks).

checkChoice <- function(values, choices, argName) {
  if (length(values) == 0) {
    stop(sprintf(
      "--%s needs at least one value. Allowed options are: %s",
      argName,
      paste(choices, collapse = ", ")
    ))
  }
  invalid <- setdiff(values, choices)
  if (length(invalid) > 0) {
    stop(sprintf(
      "Invalid --%s value(s): %s. Allowed options are: %s",
      argName,
      paste(invalid, collapse = ", "),
      paste(choices, collapse = ", ")
    ))
  }
  values
}