#' Summarise a cohort table using the standard PatientProfiles summary API.
#' If summariseResult() is not available, this function stops with a clear error.
#'
#' This keeps feature-generation scripts focused on adding columns to a cohort table
#' and leaves the final summary step in a reusable helper.

summariseCohortTable <- function(cohort,
                                 output_path = NULL,
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

  summary_df <- as.data.frame(summary_df)

  if (!is.null(output_path)) {
    write.csv(summary_df, file = output_path, row.names = FALSE)
  }

  summary_df
}
