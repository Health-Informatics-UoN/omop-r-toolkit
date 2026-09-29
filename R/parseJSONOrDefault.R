#' Parse JSON CLI arguments and return a default value when the input is empty or null-like.

parseJSONOrDefault <- function(x, default) {
  if (is.null(x) || identical(x, "") || identical(x, "NULL") || identical(x, "[]") || identical(x, "{}")) {
    return(default)
  }

  jsonlite::fromJSON(x)
}
