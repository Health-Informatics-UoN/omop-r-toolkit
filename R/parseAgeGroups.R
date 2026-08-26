#' Cohort age groups expect a list of 2-vectors of integers.
#' Parsing this from the command-line is non-trivial, so we're parsing JSON
#' The json needs to be like [[0,17], [18,30]]], which will be passed to the cohort definition function as list(c(0,17), c(18,30))

parseAgeGroups <- function(jsonString) {
  # we have to use asplit here, because if you pass fromJSON the example, you will get a matrix, e.g.
  #      [,1] [,2]
  #[1,]    0   17
  #[2,]   18   30

  ageMatrix <- jsonlite::fromJSON(jsonString)
  
  if (!any(class(ageMatrix) == "matrix")) {
    stop("Age groups need to be pairs")
  }
  
  if (dim(ageMatrix)[[2]] != 2) {
    stop("Age groups need to be pairs")
  }

  if (class(ageMatrix[[1]]) != "integer") {
    stop("Age group values need to be integer")
  }

  as.list(as.data.frame(t(ageMatrix))) |> unname()
}