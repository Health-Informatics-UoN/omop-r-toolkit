# OMOP R toolkit

Packaging OMOP CDM R tools for use in [Five Safes TES](https://docs.federated-analytics.ac.uk/five_safes_tes)(5s-TES)

[Skip to the scripts](#scripts)

## How the tools are packaged

### Overview

The tools are made to run as containers, designed for eyes-off analysis using 5s-TES.
5s-TES works by a [Task Execution Service (TES)](https://www.ga4gh.org/product/task-execution-service-tes/) engine picking up a task.
A task is some computation carried out by "executors": containers that run some program, then write an output, and are defined with a JSON string following the schema for the TES "Create task" API.
To make a reusable executor, this toolkit has a series of scripts in `/inst/scripts` which can be run using `Rscript`.
This means users can pass commands to the container when it is running in 5s-TES to control how the container executes inside a Trusted Research Environment (TRE).

### Commands

For example, [defining a concept set cohort](#define-a-concept-cohort-set) can be done locally using the command line like so:

```bash
Rscript inst/scripts/defineConceptCohortSet.R skin_cancer_20260713 --conceptSet="{'neoplasm': [139750]}"
```

This will run the `inst/scripts/defineConceptCohortSet.R` script with the command-line arguments specified.
Running this as a TES task is similar, except the tokens have to be passed as an array:

```json
[
    "Rscript",
    "inst/scripts/defineConceptCohortSet.R",
    "skin_cancer_20260713",
    "--conceptSet={\"neoplasm\": [139750]}",
]
```

One "gotcha" here is that where you would use quotes to wrap JSON on the command-line, you don't when specifying a command to a TES executor.

### Running as a TES executor

To fit with this, all the scripts are written to run in three steps:

1. Parse command-line arguments
2. Do something, hopefully useful
3. Maybe write the output somewhere

#### Parse command-line arguments

The scripts have a string at the beginning which defines the help message for the CLI tool, then use [docopt](https://github.com/docopt/docopt.R) so this can be used as arguments to the script's functions.

#### Do something, hopefully useful

The scripts use [Darwin-EU](github.com/darwin-eu/) libraries to interact with the OMOP-CDM, following examples in their excellent documentation.
They all assume you are using a PostgreSQL database to hold your OMOP-CDM.
The utility script [for database connection](./R/postgres-connect-5s-tes.R) uses environment variables matching the 5s-TES defaults to define your database credentials.

#### Write the output somewhere

When writing the output the scripts have a CLI argument specifying at least one output path.
A TES message allows you to specify where you can collect your outputs from, for example a directory in an s3 bucket.
If you want to use your outputs afterwards, make sure these match!

### Running an analysis
In the example above, all that happens is that a cohort is created in the database.
This is not a complete example of an analysis, which requires something to be done with that cohort.
There are multiple ways of creating a cohort and multiple analyses that can be performed on created cohorts, the combinations of which would be complicated to support as single scripts, so the workflow for using these is:

1. Define cohort(s) with a script (or scripts)
2. Perform analyses with separate scripts
3. Clean up your tables if necessary

For example, you could run the container once, running the `defineConceptCohortSet` script, then run the container again with the `incidencePrevalence` script to estimate incidence, then run the container a final time with `cleanUpCohortTables` to tidy up.
This might seem strange, running the same container three times, but this allows for a flexible, mix-and-match setup.

### All together, now

This means a basic example of running this using a TES message looks like this:

<details>
  <summary>Show TES JSON</summary>


```json
{
         "id": "1489",
         "state": 0,
         "name": "R tools on both this time",
         "description": "Federated analysis task",
         "inputs": null,
         "outputs": [
                  {
                           "name": "Query Results",
                           "description": "Results from the requested query execution",
                           "url": "s3://",
                           "path": "/outputs",
                           "type": "DIRECTORY"
                  }
         ],
         "resources": null,
         "executors": [
                  {
                           "image": "ghcr.io/health-informatics-uon/omop-r-tools:sha-8071279",
                           "command": [
                                    "Rscript",
                                    "inst/scripts/defineConceptCohortSet.R",
                                    "skin_cancer_20260713",
                                    "--conceptSet={\"neoplasm\": [139750]}",
                           ],
                           "workdir": null,
                           "stdin": null,
                           "stdout": null,
                           "stderr": null,
                           "env": {}
                  },
                  {
                           "image": "ghcr.io/health-informatics-uon/omop-r-tools:sha-8071279",
                           "command": [
                                    "Rscript",
                                    "inst/scripts/count-cohorts.R",
                                    "skin_cancer_20260713",
                                    "--output-path=outputs/output.csv"
                           ],
                           "workdir": null,
                           "stdin": null,
                           "stdout": null,
                           "stderr": null,
                           "env": {}
                  },
                  {
                           "image": "ghcr.io/health-informatics-uon/omop-r-tools:sha-8071279",
                           "command": [
                                    "Rscript",
                                    "inst/scripts/cleanUpCohortTables.R",
                                    "skin_cancer_20260713",
                           ],
                           "workdir": null,
                           "stdin": null,
                           "stdout": null,
                           "stderr": null,
                           "env": {}
                  }

         ],
         "volumes": null,
         "tags": {
                  "Project": "DelphiDemo",
                  "tres": "Nottingham TRE 01|Nottingham TRE 02"
         },
         "logs": null,
         "creation_time": null
}
```
</details>

This starts the version of the container with the hash specified, passing it the command to run `defineConceptCohortSet.R` to create a cohort, `count-cohorts.R` to count the members of the cohort, then `cleanUpCohortTables.R` to remove the cohort table, and configuring the files written to the container's `/outputs` to be passed to an s3 bucket after.
Most of the rest is descriptive, refer to [5s-TES docs](https://docs.federated-analytics.ac.uk/) for more details

## Scripts
### Define a concept cohort set
```sh
Usage:
  defineConceptCohortSet.R <name> --conceptSet=<json> [--alloccurrences] [--end=<end>] [--requiredObservation=<days>]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --alloccurrences              Include all occurrences of events in the cohort. Otherwise, only includes the first
  --end=<end>                   How the cohort end date should be defined. One of "observation_period_end_date", a numeric scalar for the number of days, or "event_end_date" [default: observation_period_end_date]
  --requiredObservation=<days>  Comma-separated pair of days of required observation time prior,post index, e.g. "0,0" [default: 0,0]
  --conceptSet=<json>           JSON string describing the concept set for the cohort ({"someName": [1234, 5678],...})
```

### Count a cohort
```sh
Usage:
  count-cohorts.R <name> [--output-path=<output_path>]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --output-path=<output_path>   Path to write the output csv to [default: outputs/output.csv]
```

### Clean up cohort tables
```sh
Usage:
  cleanUpCohortTables.R <name> ...

Options:
  -h --help                     Show this screen
  --version                     Show version
```

### Incidence and Prevalence
```sh
Calculate incidence or prevalence in a cohort.

Usage:
  incidencePrevalence.R <denominatorCohortName> [options]

Options:
  -h --help                                           Show this screen
  --version                                           Show version
  --denominatorCohortDateRange=<dates>                Optional comma-separated pair of dates ("YYYY-MM-DD").The first indicating the earliest cohort start date and the second indicating the latest possible cohort end date. [default: 1900-01-01,2100-01-01]
  --denominatorAgeGroup=<groups>                      A list of age groups for which cohorts will be generated. [default: [[0,150]]]
  --denominatorBothOff                                Do not have a cohort of people assigned either Male or Female
  --denominatorMale                                   Have a cohort of people assigned Male
  --denominatorFemale                                 Have a cohort of people assigned Female
  --denominatorDaysPriorObservation=<days>            The number of days of prior observation observed in the database required for an individual to start contributing time in a cohort. [default: 0]
  --requirementInteractions                           If TRUE, cohorts will be created for all combinations of ageGroup, sex, and daysPriorObservation. If FALSE, only the first value specified for the other factors will be used. Consequently, order of values matters when requirementInteractions is FALSE. [default: TRUE]
  --outcomeCohortName=<cohortName>                    Name of the outcome cohort in the cdm database
  --estimateIncidenceOutputPath=<output_path>         A path to which the output of estimateIncidence is saved. [default: ]
  --incidenceInterval=<interval>                      The interval for incidence, if estimating incidence. [default: years]
  --incidenceOutcomeWashout=<washout>                 The washout for incidence, if estimating incidence. [default: 0]
  --incidenceRepeatedEvents                           Whether to measure repeated events if estimating incidence
  --estimatePointPrevalenceOutputPath=<output_path>   A path to which the output of estimatePointPrevalence is saved. [default: ]
  --pointPrevalenceInterval=<interval>                The interval for point prevalence, if estimating point prevalence [default: Years]
  --pointPrevalenceTimePoint=<timePoint>              The time point for point prevalence, if estimating point prevalence [default: start]
  --estimatePeriodPrevalenceOutputPath=<output_path>  A path to which the output of estimatePeriodPrevalence is saved. [default: ]
  --periodPrevalenceInterval=<interval>               The interval for period prevalence, if estimating period prevalence [default: Years]
```

The output from this is in the [omopgenerics summarised result format](https://darwin-eu.github.io/omopgenerics/articles/summarised_result.html), so you can use it for plots with e.g.:

```R
omopgenerics::importSummarisedResult("my-incidence-file.csv") |> plotIncidence()
```