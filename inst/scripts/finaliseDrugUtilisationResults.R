'Bind and suppress final DrugUtilisation results.

Usage:
  finaliseDrugUtilisationResults.R <result1> [<result2> ...] [options]

Options:
  -h --help                         Show this screen
  --version                         Show version
  --suppressCounts                  Suppress counts in the final output
  --suppressGroup                  Suppress group columns
  --output-path=<path>             Output CSV path
' -> doc

library(docopt)
library(omopgenerics)

arguments <- docopt(doc, version = "Finalise Drug Utilisation Results 0.1.0")

results <- list()
for (nm in arguments$result1) {
  if (!is.null(nm) && nzchar(nm)) {
    x <- try(readRDS(nm), silent = TRUE)
    if (inherits(x, "try-error")) {
      x <- try(read.csv(nm), silent = TRUE)
    }
    if (!inherits(x, "try-error")) {
      results[[length(results) + 1L]] <- x
    }
  }
}

if (length(results) == 0) {
  stop("No result files were supplied")
}

final_result <- omopgenerics::bind(results)

if (arguments$suppressCounts) {
  final_result <- omopgenerics::suppressCounts(final_result)
}
if (arguments$suppressGroup) {
  final_result <- omopgenerics::suppressGroup(final_result)
}

if (!is.null(arguments$output_path) && nzchar(arguments$output_path)) {
  dir.create(dirname(arguments$output_path), recursive = TRUE, showWarnings = FALSE)
  write.csv(as.data.frame(final_result), arguments$output_path, row.names = FALSE)
}

final_result
