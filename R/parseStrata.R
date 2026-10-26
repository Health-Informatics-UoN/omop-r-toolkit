#' Strata are defined as:
#' An optional list of target cohort column names to stratify by. Each element can be one column name or a character vector of column names for a combined stratum, for example list("sex", c("age_group", "sex")).
#' 
#' So we want to be able to get list("sex", c("age_group", "sex")) from some JSON.
#' This would be something like ["sex", ["age_group", "sex"]]

checkAllChar <- function(x) {
  all(purrr::map(x, class) == "character")
}

checkStrataAreChar <- function(maybeStrata) {
  if(!checkAllChar(maybeStrata)) {
    stop("Not all of the strata are either a character or a vector of characters")
  }
  maybeStrata
}

checkStrataDepth <- function(maybeStrata) {
  if (!all(purrr::map(maybeStrata, checkAllChar))) {
    stop("Only one level of nesting allowed in strata definitions")
  }
  maybeStrata
}

parseStrata <- function(strataJSON) {
  jsonlite::fromJSON(strataJSON, simplifyVector=FALSE) |>
    checkStrataDepth() |>
    # This part is tricky because the default flattens everything to a vector
    # The strata require a list of vectors, so you have to turn of the simplification to a vector
    # Then you have a list of lists, which is fair enough, but you have to simplify the lists inside to vectors
    purrr::map(unlist) |>
    checkStrataAreChar()  
}