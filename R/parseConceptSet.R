#' Concept sets defined in a command are JSON strings. This checks that the JSON provided can be used to define a concept set.

checkConceptSetList <- function(maybeConceptSetList) {
  if (!all(purrr::map(maybeConceptSetList, class) == "integer")){
    stop("Not all of the conceptSet fields are integer vectors")
  }
  maybeConceptSetList
}

parseJSONConceptSet <- function(conceptSetJSON) {
  jsonlite::fromJSON(conceptSetJSON) |> checkConceptSetList()
}