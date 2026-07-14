'Count members of a cohort.

Usage:
  count_cohorts.R <name> --conceptSet=<json> [--alloccurrences] [--end=<end>] [--requiredObservation=<days>] [--output-path=<output_path>]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --alloccurrences              Include all occurrences of events in the cohort. Otherwise, only includes the first
  --end=<end>                   How the cohort end date should be defined. One of "observation_period_end_date", a numeric scalar for the number of days, or "event_end_date" [default: observation_period_end_date]
  --requiredObservation=<days>  Comma-separated pair of days of required observation time prior,post index, e.g. "0,0" [default: 0,0]
  --conceptSet=<json>           JSON string describing the concept set for the cohort ({"someName": [1234, 5678],...})
  --output-path=<output_path>   Path to write the output csv to [default: outputs/output.csv]

' -> doc

library(dplyr, warn.conflicts = FALSE)
library(CodelistGenerator)
library(CohortCharacteristics)
library(docopt)
library(jsonlite)
source("R/postgres-connect-5s-tes.R")

arguments <- docopt(doc, version = "Count cohorts 0.1.0")

# requiredObservation arrives as a string like "0,0" - split into a numeric vector of length 2
requiredObservation <- as.numeric(strsplit(arguments$requiredObservation, ",")[[1]])

# conceptSet arrives as a JSON string - parse it into an R list
conceptSet <- fromJSON(arguments$conceptSet)

cdm <- connectFiveSafesTESPg("postgres_omop")

cdm_cohorts <- generateConceptCohortSet(
  cdm = cdm,
  name = arguments$name,
  limit = if (arguments$alloccurrences) "all" else "first",
  conceptSet = conceptSet,
  end = arguments$end,
  requiredObservation = requiredObservation
)

write.table(summariseCohortCount(cdm_cohorts[[arguments$name]]), arguments$output_path)

cdmDisconnect(cdm)
