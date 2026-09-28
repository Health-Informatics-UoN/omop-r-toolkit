#' Parse a comma-separated CLI string into a character vector, dropping blanks.

parseStringVector <- function(string) {
  values <- trimws(strsplit(string, ",")[[1]])
  values[nzchar(values)]
}