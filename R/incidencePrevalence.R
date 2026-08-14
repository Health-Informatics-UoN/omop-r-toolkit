# This script runs a basic workflow of using the [IncidencePrevalence](https://darwin-eu.github.io/IncidencePrevalence/) package
# The CLI options are designed to supply the arguments to the central functions of the package
# 1. estimateIncidence
# 2. estimatePointPrevalence
# 3. estimatePeriodPrevalence


'Calculate incidence or prevalence in a cohort.

Usage:
  incidencePrevalence.R <denominatorCohortName> [options]

Options:
  -h --help                             Show this screen
  --version                             Show version
  --denominatorCohortDateRange=<dates>  Optional comma-separated pair of dates ("YYYY-MM-DD").The first indicating the earliest cohort start date and the second indicating the latest possible cohort end date.
  --denominatorAgeGroup=<groups>        A list of age groups for which cohorts will be generated.
  --denominatorBoth                     Whether to have a cohort of people assigned either Male or Female. True by default
  --denominatorMale                     Whether to have a cohort of people assigned Male. False by default
  --denominatorFemale                   Whether to have a cohort of people assigned Female. False by default
  --denominatorDaysPriorObservation     The number of days of prior observation observed in the database required for an individual to start contributing time in a cohort.
  
' -> doc
