source("R/parseWindows.R")

parseWindow <- function(windowString) {
  result <- parseWindows(windowString)
  if (length(result) != 1) {
    stop("parseWindow expects exactly one window; use parseWindows for multiple")
  }
  result[[1]]
}
