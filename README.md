# OMOP R toolkit

Packaging OMOP CDM R tools for use in [Five Safes TES](https://docs.federated-analytics.ac.uk/five_safes_tes)

## Functions
### Count a cohort

```sh
Usage:
  count_cohorts.R <name> --conceptSet=<json> [--alloccurrences] [--end=<end>] [--requiredObservation=<days>]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --alloccurrences              Include all occurrences of events in the cohort. Otherwise, only includes the first
  --end=<end>                   How the cohort end date should be defined. One of "observation_end_date", a numeric scalar for the number of days, or "event_end_date" [default: observation_end_date]
  --requiredObservation=<days>  Comma-separated pair of days of required observation time prior,post index, e.g. "0,0" [default: 0,0]
  --conceptSet=<json>           JSON string describing the concept set for the cohort ({"someName": [1234, 5678],...}) 
```
