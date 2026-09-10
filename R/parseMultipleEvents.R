#' Parse multipleEvents CLI argument.
#' "null" or omitted -> NULL
#' "true"            -> TRUE
#' "a,b,c"           -> c("a", "b", "c")

parseMultipleEvents <- function(val) {
  if (is.null(val) || length(val) == 0L || is.na(val) || identical(tolower(val), "null")) {
    return(NULL)
  }

  bool_val <- suppressWarnings(as.logical(val))
  if (!is.na(bool_val)) {
    return(bool_val)
  }

  trimws(strsplit(val, ",", fixed = TRUE)[[1]])
}