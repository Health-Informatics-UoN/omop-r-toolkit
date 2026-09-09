#' Parse multipleEvents CLI argument.
#' "null" or omitted -> NULL
#' "true"            -> TRUE
#' "a,b,c"           -> c("a", "b", "c")

parseMultipleEvents <- function(val) {
  if (is.null(val) || tolower(val) == "null") {
    return(NULL)
  }
  if (tolower(val) == "true") {
    return(TRUE)
  }
  strsplit(val, ",")[[1]]
}