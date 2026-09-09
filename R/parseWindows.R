#' Parse a window specification into a list of numeric vectors.
#' Supports:
#'   "-365,-1"                    -> list(c(-365, -1))
#'   "[-365,0]"                   -> list(c(-365, 0))
#'   "[[-365,0],[0,365]]"        -> list(c(-365, 0), c(0, 365))
#'   '{"before": [-365,0], ...}' -> list("before" = c(-365, 0), ...)

parseWindows <- function(windowString) {
  windowString <- trimws(windowString)

  normalize_window_value <- function(x) {
    x <- trimws(as.character(x))
    if (length(x) == 0L || is.na(x)) return(NA_real_)
    lower <- tolower(x)
    if (lower %in% c("inf", "infinity")) return(Inf)
    if (lower %in% c("-inf", "-infinity")) return(-Inf)
    v <- suppressWarnings(as.numeric(x))
    if (is.na(v)) stop(sprintf("Cannot parse window value: %s", x))
    v
  }

  restore_infinite_tokens <- function(x) {
    if (is.null(x)) return(x)
    if (is.list(x)) {
      return(lapply(x, restore_infinite_tokens))
    }
    if (is.numeric(x)) {
      out <- x
      out[is.finite(out) & abs(out) >= 1e300] <- ifelse(out[is.finite(out) & abs(out) >= 1e300] < 0, -Inf, Inf)
      return(out)
    }
    x
  }

  # ---- Case 1: Simple comma-separated pair ----
  if (!grepl("^\\[|^\\{", windowString)) {
    parts <- strsplit(windowString, ",")[[1]]
    if (length(parts) != 2) {
      stop(sprintf("Window must be a comma-separated pair, got: %s", windowString))
    }
    vals <- sapply(parts, normalize_window_value)
    return(list(unname(vals)))
  }

  # ---- Case 2: JSON array or object ----
  normalized_json <- windowString
  normalized_json <- gsub("-Inf", "-1e308", normalized_json, perl = TRUE)
  normalized_json <- gsub("Inf", "1e308", normalized_json, perl = TRUE)
  parsed <- jsonlite::fromJSON(normalized_json)

  # Single array: [-365, 0]
  if (is.vector(parsed) && !is.list(parsed) && length(parsed) == 2) {
    return(list(restore_infinite_tokens(as.numeric(parsed))))
  }

  # Matrix: [[-365,0],[0,365]]
  if (is.matrix(parsed)) {
    if (ncol(parsed) != 2) stop("Each window must be a pair of numbers")
    result <- lapply(seq_len(nrow(parsed)), function(i) {
      restore_infinite_tokens(as.numeric(parsed[i, ]))
    })
    return(result)
  }

  # Named list or list of vectors: {"before": [-365,0], "after": [0,365]}
  if (is.list(parsed) && !is.data.frame(parsed)) {
    result <- lapply(names(parsed), function(nm) {
      v <- unlist(parsed[[nm]])
      if (length(v) != 2) stop(sprintf("Window '%s' must be a pair", nm))
      restore_infinite_tokens(as.numeric(v))
    })
    names(result) <- names(parsed)
    return(result)
  }

  stop(sprintf("Unrecognized window format: %s", windowString))
}