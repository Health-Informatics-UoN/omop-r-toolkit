#' Parse a comma-separated numeric vector from CLI input.

parseNumericVector <- function(x) {
  if (is.null(x) || identical(x, "") || identical(x, "NULL") || identical(x, "[]")) {
    return(NULL)
  }

  value <- trimws(as.character(x))
  if (!nzchar(value)) {
    return(NULL)
  }

  values <- strsplit(value, ",", fixed = TRUE)[[1]]
  values <- trimws(values)
  values <- values[nzchar(values)]

  if (length(values) == 0) {
    return(NULL)
  }

  as.numeric(values)
}

parseLogical <- function(x, default = FALSE) {
  if (is.null(x) || identical(x, "") || identical(x, "NULL")) {
    return(default)
  }
  if (is.logical(x)) {
    return(x)
  }
  if (is.character(x)) {
    x <- trimws(x)
    if (tolower(x) %in% c("true", "t", "1", "yes", "y")) return(TRUE)
    if (tolower(x) %in% c("false", "f", "0", "no", "n")) return(FALSE)
  }
  default
}
