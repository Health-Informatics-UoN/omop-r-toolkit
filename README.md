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
                           "image": "ghcr.io/health-informatics-uon/omop-r-tools:sha-e96408f",
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
                           "image": "ghcr.io/health-informatics-uon/omop-r-tools:sha-e96408f",
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
                           "image": "ghcr.io/health-informatics-uon/omop-r-tools:sha-e96408f",
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

### Drug utilisation

The following scripts provide cohort generation, patient-level variables, and summarised analyses using the [DrugUtilisation package](https://darwin-eu.github.io/DrugUtilisation/). Logical options accept explicit values such as `TRUE` or `FALSE`; when omitted, the DrugUtilisation package default is used.

#### Generate an ingredient or ATC cohort set

```sh
Usage:
  generateIngredientCohortSet.R <name> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --ingredient=<names>          Comma-separated ingredient names (e.g. acetaminophen,metformin)
  --atc=<name>                  ATC name to use instead of ingredient names
  --gapEra=<n>                  Gap era in days [default: 1]
  --subsetCohort=<name>         Optional cohort table to subset from
  --subsetCohortId=<ids>        Optional cohort IDs to subset
  --numberExposures=<logical>   Add number of exposures to the output cohort
  --daysPrescribed=<logical>    Add days prescribed to the output cohort
  --output-path=<path>          Optional path to write cohort settings summary csv
```

Example:

```sh
Rscript inst/scripts/generateIngredientCohortSet.R metformin_users \
  --ingredient=metformin \
  --gapEra=7 \
  --numberExposures=TRUE \
  --output-path=outputs/metformin-cohort-settings.csv
```

#### Add drug utilisation variables

```sh
Usage:
  addDrugUtilisation.R <name> [options]

Options:
  -h --help                           Show this screen
  --version                           Show version
  --ingredientConceptId=<ids>         Comma-separated ingredient concept IDs
  --conceptSet=<json>                 Optional concept set JSON for custom concept definitions
  --gapEra=<n>                        Gap era in days [default: 7]
  --indexDate=<date_col>              Index date column [default: cohort_start_date]
  --censorDate=<date_col>             Optional censor date column
  --restrictIncident=<logical>        Restrict to incident exposures
  --numberExposures=<logical>         Include number of exposures
  --numberEras=<logical>              Include number of eras
  --daysExposed=<logical>             Include days exposed
  --daysPrescribed=<logical>          Include days prescribed
  --timeToExposure=<logical>          Include time to exposure
  --initialExposureDuration=<logical> Include initial exposure duration
  --initialQuantity=<logical>         Include initial quantity
  --cumulativeQuantity=<logical>      Include cumulative quantity
  --initialDailyDose=<logical>        Include initial daily dose
  --cumulativeDose=<logical>          Include cumulative dose
  --nameStyle=<style>                 Name style for added columns [default: {variable}]
```

Example:

```sh
Rscript inst/scripts/addDrugUtilisation.R study_cohort \
  --ingredientConceptId=1503297 \
  --restrictIncident=FALSE \
  --daysExposed=TRUE \
  --cumulativeDose=TRUE
```

#### Summarise drug utilisation

```sh
Usage:
  summariseDrugUtilisation.R <name> [options]

Options:
  -h --help                           Show this screen
  --version                           Show version
  --ingredientConceptId=<ids>         Comma-separated ingredient concept IDs
  --conceptSet=<json>                 Optional concept set JSON for custom concepts
  --strata=<json>                     Optional JSON list of strata variables [default: []]
  --estimates=<json>                  JSON vector of estimates [default: ["mean","sd","count_missing","percentage_missing"]]
  --indexDate=<date_col>              Index date column [default: cohort_start_date]
  --censorDate=<date_col>             Optional censor date column
  --restrictIncident=<logical>        Restrict to incident exposures
  --gapEra=<n>                        Gap era in days [default: 7]
  --numberExposures=<logical>         Include number of exposures
  --numberEras=<logical>              Include number of eras
  --daysExposed=<logical>             Include days exposed
  --daysPrescribed=<logical>          Include days prescribed
  --timeToExposure=<logical>          Include time to exposure
  --initialExposureDuration=<logical> Include initial exposure duration
  --initialQuantity=<logical>         Include initial quantity
  --cumulativeQuantity=<logical>      Include cumulative quantity
  --initialDailyDose=<logical>        Include initial daily dose
  --cumulativeDose=<logical>          Include cumulative dose
  --output-path=<path>                Output CSV path
```

Example:

```sh
Rscript inst/scripts/summariseDrugUtilisation.R study_cohort \
  --ingredientConceptId=1503297 \
  --strata='["age_group","sex"]' \
  --numberExposures=TRUE \
  --daysExposed=TRUE \
  --output-path=outputs/drug-utilisation.csv
```

#### Add indications

```sh
Usage:
  addIndication.R <name> --indicationCohortName=<table> [options]

Options:
  -h --help                         Show this screen
  --version                         Show version
  --indicationCohortName=<table>    Indication cohort table name in the cdm
  --indicationCohortId=<ids>        Optional indication cohort IDs
  --window=<windows>                Indication window(s), e.g. [-30,0] or [[-30,0],[0,0]] [default: [-30,0]]
  --unknownIndicationTable=<table>  Optional table for unknown indications
  --indexDate=<date_col>            Index date column [default: cohort_start_date]
  --censorDate=<date_col>           Optional censor date column
  --mutuallyExclusive=<logical>     Consider mutually exclusive indication labels
  --restrictIncident=<logical>      Restrict to incident indication events
  --nameStyle=<style>               Naming style for the added columns [default: {window_name}]
```

Example:

```sh
Rscript inst/scripts/addIndication.R drug_cohort \
  --indicationCohortName=condition_cohort \
  --indicationCohortId=1,2 \
  --window='[[-30,0],[0,0]]' \
  --mutuallyExclusive=FALSE
```

#### Summarise indications

```sh
Usage:
  summariseIndication.R <name> --indicationCohortName=<table> [options]

Options:
  -h --help                         Show this screen
  --version                         Show version
  --indicationCohortName=<table>    Indication cohort table name in the cdm
  --indicationCohortId=<ids>        Optional indication cohort IDs
  --window=<windows>                Indication window(s), e.g. [-30,0] or [[-30,0],[0,0]] [default: [-30,0]]
  --unknownIndicationTable=<table>  Optional table for unknown indications
  --strata=<json>                   Optional JSON list of strata variables [default: []]
  --indexDate=<date_col>            Index date column [default: cohort_start_date]
  --censorDate=<date_col>           Optional censor date column
  --mutuallyExclusive=<logical>     Consider mutually exclusive indication labels
  --restrictIncident=<logical>      Restrict to incident indication events
  --output-path=<path>              Path to write output csv
```

Example:

```sh
Rscript inst/scripts/summariseIndication.R drug_cohort \
  --indicationCohortName=condition_cohort \
  --window='[-30,0]' \
  --restrictIncident=TRUE \
  --output-path=outputs/indications.csv
```

#### Summarise dose coverage

```sh
Usage:
  summariseDoseCoverage.R <name> [options]
### Drug Exposure Diagnostics
```sh
Usage:
  drugExposureDiagnostics.R --ingredients=<ids> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --ingredientConceptId=<ids>   Comma-separated ingredient concept IDs
  --conceptSet=<json>           Optional concept set JSON for custom concept definitions
  --estimates=<json>            Optional JSON vector of estimates [default: ["mean","sd","min","max"]]
  --sampleSize=<n>              Optional sample-size override
  --output-path=<path>          Output CSV path
```

Example:

```sh
Rscript inst/scripts/summariseDoseCoverage.R drug_cohort \
  --ingredientConceptId=1503297 \
  --estimates='["mean","sd","min","max"]' \
  --output-path=outputs/dose-coverage.csv
```

#### Summarise drug restarts

```sh
Usage:
  summariseDrugRestart.R <name> --switchCohortTable=<table> [options]

Options:
  -h --help                                  Show this screen
  --version                                  Show version
  --switchCohortTable=<table>                Switch cohort table in the cdm
  --switchCohortId=<ids>                     Optional switch cohort IDs
  --strata=<json>                            Optional JSON list of strata variables [default: []]
  --followUpDays=<n>                         Follow-up window in days [default: 365]
  --censorDate=<date_col>                    Optional censor date column
  --incident=<logical>                       Restrict to incident restarts
  --restrictToFirstDiscontinuation=<logical> Restrict to first discontinuation only
  --output-path=<path>                       Output CSV path
```

Example:

```sh
Rscript inst/scripts/summariseDrugRestart.R drug_cohort \
  --switchCohortTable=switch_cohort \
  --switchCohortId=1 \
  --followUpDays=365 \
  --incident=TRUE \
  --output-path=outputs/drug-restarts.csv
```

#### Finalise DrugUtilisation results

```sh
Usage:
  finaliseDrugUtilisationResults.R <result1> [<result2> ...] [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --suppressCounts              Suppress counts in the final output
  --suppressGroup               Suppress group columns
  --output-path=<path>          Output CSV path
```
  --ingredients=<ids>           Comma-separated ingredient concept IDs (e.g. 1125315,161)
  --checks=<checks>             Comma-separated checks to run [default: missing,exposureDuration,type,route,sourceConcept,daysSupply,verbatimEndDate,dose,sig,quantity,daysBetween,diagnosticsSummary]
  --output-path=<path>          Directory to write output csvs to [default: outputs/ded/]
  --databaseId=<id>             Database identifier [default: OMOP_DB]
  --sample=<n>                  Number of records to sample (0 = all) [default: 10000]
  --minCellCount=<n>            Minimum cell count for disclosure control [default: 5]
  --earliestStartDate=<date>    Earliest drug exposure start date [default: 1900-01-01]
  --byConcept                   Return results broken down by drug concept
  --subsetToConceptId=<ids>     Comma-separated concept IDs to include (+) or exclude (-)
  --exposureTypeId=<id>         Drug exposure type concept ID to filter on
  --tablePrefix=<prefix>        Prefix for temporary database tables
```

This script runs drug exposure diagnostics for a list of ingredient concept IDs and writes the package-standard result files to the chosen output folder.

Example:

```sh
Rscript inst/scripts/finaliseDrugUtilisationResults.R \
  outputs/drug-utilisation.csv \
  outputs/indications.csv \
  --suppressCounts \
  --output-path=outputs/final-drug-utilisation.csv
```