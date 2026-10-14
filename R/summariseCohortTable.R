#' Summarise a cohort table using the standard PatientProfiles summary API.

summariseCohortTable <- function(cohort,
                                 outputPath = NULL,
                                 group = list(),
                                 includeOverallGroup = FALSE,
                                 strata = list(),
                                 includeOverallStrata = TRUE,
                                 variables = NULL,
                                 estimates = NULL,
                                 counts = TRUE,
                                 weights = NULL,
                                 customEstimates = list()) {
  if (!exists("summariseResult", mode = "function")) {
    stop("summariseResult() is not available in the installed PatientProfiles version.")
  }

  summary_df <- cohort |>
    summariseResult(
      group = group,
      includeOverallGroup = includeOverallGroup,
      strata = strata,
      includeOverallStrata = includeOverallStrata,
      variables = variables,
      estimates = estimates,
      counts = counts,
      weights = weights,
      customEstimates = customEstimates
    )

  if (!is.null(outputPath)) {
    dir.create(dirname(outputPath), recursive = TRUE, showWarnings = FALSE)
    omopgenerics::exportSummarisedResult(
      summary_df,
      minCellCount = 5,
      fileName = basename(outputPath),
      path = dirname(outputPath)
    )
  }

  summary_df
}
