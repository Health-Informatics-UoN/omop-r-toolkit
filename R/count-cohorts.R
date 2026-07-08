'Count members of a cohort.

Usage:
  count_cohorts.R <name> [--conceptSet=<json>]

Options:
  -h --help             Show this screen
  --version             Show version
  --alloccurrences      Include all occurrences of events in the cohort. Otherwise, only includes the first
  --end                 How the cohort end date should be defined. One of "observation_end_date", a numeric scalar for the number of days or "event_end_date"
  --requiredObservation A numeric vector of length 2 that specifies the number of days of required observation time prior/post index
  --conceptSet          JSON string describing the concept set for the cohort ({"someName": [1234, 5678],...})

' -> doc

library(dplyr, warn.conflicts = FALSE)
library(CodelistGenerator)
library(CohortCharacteristics)
library(docopt)
source("R/postgres-connect-5s-tes.R")

arguments <- docopt(doc, version="Count cohorts 0.1.0")

cdm <- connectFiveSafesTESPg("postgres_omop")
cdm <- generateConceptCohortSet(
      cdm = cdm,
      name = arguments$name,
      limit = if(arguments$alloccurrences) "all" else "first",
      conceptSet = fromJSON(json_str = arguments$conceptSet),
      end = arguments$end,
      requiredObservation = arguments$requiredObservation
    )

print(cohortCount(cdm$skin_cancer))
