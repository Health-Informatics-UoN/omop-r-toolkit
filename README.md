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

- [Define a concept cohort set](#define-a-concept-cohort-set)
- [Count a cohort](#count-a-cohort)
- [Clean up cohort tables](#clean-up-cohort-tables)
- [Incidence and Prevalence](#incidence-and-prevalence)
- [Drug utilisation](#drug-utilisation)
- [Treatment patterns](#treatment-patterns)
- [Patient Profiles](#patientprofiles)
- [Cohort survival](#cohortsurvival)

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

The following scripts provide cohort generation, patient-level variables, and summarised analyses using the [DrugUtilisation package](https://darwin-eu.github.io/DrugUtilisation/).
Logical options take an explicit value such as `TRUE` or `FALSE`; invalid values cause the task to fail. When an option is omitted, the default shown in `[default: ...]` is used.

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
  --numberExposures=<logical>   Add number of exposures to the output cohort [default: FALSE]
  --daysPrescribed=<logical>    Add days prescribed to the output cohort [default: FALSE]
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
  --restrictIncident=<logical>        Restrict to incident exposures [default: TRUE]
  --numberExposures=<logical>         Include number of exposures [default: TRUE]
  --numberEras=<logical>              Include number of eras [default: TRUE]
  --daysExposed=<logical>             Include days exposed [default: TRUE]
  --daysPrescribed=<logical>          Include days prescribed [default: TRUE]
  --timeToExposure=<logical>          Include time to exposure [default: TRUE]
  --initialExposureDuration=<logical> Include initial exposure duration [default: TRUE]
  --initialQuantity=<logical>         Include initial quantity [default: TRUE]
  --cumulativeQuantity=<logical>      Include cumulative quantity [default: TRUE]
  --initialDailyDose=<logical>        Include initial daily dose [default: TRUE]
  --cumulativeDose=<logical>          Include cumulative dose [default: TRUE]
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
  --restrictIncident=<logical>        Restrict to incident exposures [default: TRUE]
  --gapEra=<n>                        Gap era in days [default: 7]
  --numberExposures=<logical>         Include number of exposures [default: TRUE]
  --numberEras=<logical>              Include number of eras [default: TRUE]
  --daysExposed=<logical>             Include days exposed [default: TRUE]
  --daysPrescribed=<logical>          Include days prescribed [default: TRUE]
  --timeToExposure=<logical>          Include time to exposure [default: TRUE]
  --initialExposureDuration=<logical> Include initial exposure duration [default: TRUE]
  --initialQuantity=<logical>         Include initial quantity [default: TRUE]
  --cumulativeQuantity=<logical>      Include cumulative quantity [default: TRUE]
  --initialDailyDose=<logical>        Include initial daily dose [default: TRUE]
  --cumulativeDose=<logical>          Include cumulative dose [default: TRUE]
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
  --mutuallyExclusive=<logical>     Consider mutually exclusive indication labels [default: FALSE]
  --restrictIncident=<logical>      Restrict to incident indication events [default: TRUE]
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
  --mutuallyExclusive=<logical>     Consider mutually exclusive indication labels [default: FALSE]
  --restrictIncident=<logical>      Restrict to incident indication events [default: TRUE]
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
  --incident=<logical>                       Restrict to incident restarts [default: FALSE]
  --restrictToFirstDiscontinuation=<logical> Restrict to first discontinuation only [default: TRUE]
  --output-path=<path>                       Output CSV path
```

Example:

```sh
Rscript inst/scripts/drugExposureDiagnostics.R \
  --ingredients=1125315 \
  --byConcept \
  --output-path=outputs/ded/
```

### Treatment Patterns

TreatmentPatterns builds pathways of *event* cohorts (usually treatments) occurring during a *target* cohort (usually a disease), optionally ending with an *exit* cohort (e.g. death).

The target, event and exit cohorts are defined in separate tables, so each can use different settings: typically the first occurrence until observation end for the target, and all occurrences until the event end for treatments.
The script binds them into one temporary table (`--combinedCohortTable`), labels each cohort with its type, runs `computePathways()`, exports the results and drops the temporary table.

Because cohort IDs are reassigned when the tables are combined, cohorts are referred to by name, e.g. in `--splitEventCohorts`, and cohort names must be unique across the tables.

```sh
Compute treatment pathways with TreatmentPatterns and export aggregate results.

Usage:
  treatmentPatterns.R --targetCohortTable=<table> --eventCohortTable=<table> [options]

Options:
  -h --help                                Show this screen
  --version                                Show version
  --targetCohortTable=<table>              Cohort table holding the target cohort(s), e.g. a disease
  --eventCohortTable=<table>               Cohort table holding the event cohorts, e.g. treatments
  --exitCohortTable=<table>                Optional cohort table holding exit cohorts, e.g. death
  --combinedCohortTable=<table>            Name of the table the cohorts are combined into. Dropped at the end [default: tp_cohorts]
  --output-path=<path>                     Directory to write output csvs to [default: outputs/treatment_patterns/]
  --archiveName=<name>                     Optional name of a zip file (in the output directory) to bundle the csvs into
  --analysisId=<id>                        Analysis identifier [default: 1]
  --description=<text>                     Analysis description [default: Treatment Patterns analysis]
  --startAnchor=<anchor>                   Anchor for the window start. One of startDate, endDate [default: startDate]
  --windowStart=<days>                     Offset in days from startAnchor [default: 0]
  --endAnchor=<anchor>                     Anchor for the window end. One of startDate, endDate [default: endDate]
  --windowEnd=<days>                       Offset in days from endAnchor [default: 0]
  --splitEventCohorts=<names>              Optional comma-separated event cohort names to split into acute and therapy
  --splitTime=<days>                       Days classified as acute before therapy. One value, or one per split cohort
  --minEraDuration=<days>                  Minimum duration of an event era [default: 30]
  --filterTreatments=<method>              One of First, Changes, All [default: First]
  --eraCollapseSize=<days>                 Gap within which repeated eras of the same event are collapsed [default: 30]
  --combinationWindow=<days>               Minimum overlap for two events to count as a combination [default: 30]
  --minPostCombinationDuration=<days>      Minimum duration of eras left after splitting out a combination [default: 30]
  --overlapWithKeep=<method>               Keep both records dates for non-significant overlap (overlapMethod = "keep"). Otherwise the first record is truncated.
  --maxPathLength=<n>                      Maximum number of steps in a pathway [default: 5]
  --concatTargets=<logical>                Concatenate multiple target cohort entries per person [default: TRUE]
  --minCellCount=<n>                       Minimum cell count for disclosure control [default: 5]
  --censorType=<type>                      How to censor counts below minCellCount. One of minCellCount, remove, mean [default: minCellCount]
  --ageWindow=<ages>                       Age group width in years, or comma-separated age breaks (e.g. 0,18,65,150) [default: 10]
  --nonePaths                              Include pathways where no events occurred
```


The defaults for `minEraDuration`, `combinationWindow` and `minPostCombinationDuration` are all 30, following the [TreatmentPatterns best practices](https://darwin-eu-dev.github.io/TreatmentPatterns/articles/a000_bestPractices.html) (`minPostCombinationDuration <= minEraDuration`, `combinationWindow >= minEraDuration`). The script warns if you choose settings outside these suggestions.

Only aggregate results are written, with counts below `--minCellCount` censored. Patient-level export and plots are not supported; plot the exported csvs outside the TRE.

`defineConceptCohortSet.R` does not include descendant concepts. Drug exposures are usually recorded as clinical drug concepts, so listing only an ingredient concept ID will match few or no records; list the drug concepts themselves.

Example executors:

```sh
Rscript inst/scripts/defineConceptCohortSet.R sinusitis_target \
  --conceptSet='{"viral_sinusitis": [40481087]}'

Rscript inst/scripts/defineConceptCohortSet.R sinusitis_treatments \
  --conceptSet='{"amoxicillin": [19073183, 19073188], "acetaminophen": [1127433, 1127078]}' \
  --alloccurrences \
  --end=event_end_date

Rscript inst/scripts/treatmentPatterns.R \
  --targetCohortTable=sinusitis_target \
  --eventCohortTable=sinusitis_treatments \
  --minEraDuration=7 \
  --combinationWindow=7 \
  --minPostCombinationDuration=7 \
  --output-path=outputs/treatment_patterns/

Rscript inst/scripts/cleanUpCohortTables.R sinusitis_target sinusitis_treatments
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

Example:

```sh
Rscript inst/scripts/finaliseDrugUtilisationResults.R \
  outputs/drug-utilisation.csv \
  outputs/indications.csv \
  --suppressCounts \
  --output-path=outputs/final-drug-utilisation.csv
```

### PatientProfiles
```sh
Add patient-level cohort features using PatientProfiles.

Usage:
  addCharacteristics.R <name> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --addAge                      Add age at index date
  --ageGroup=<json>             JSON list of age groups [default: [[0,150]]]
  --ageName=<name>              Name for the age column [default: age]
  --ageMissingMonth=<m>         Month assumed if missing [default: NULL]
  --ageMissingDay=<d>           Day assumed if missing [default: NULL]
  --ageImposeMonth              Impose missing month to ageMissingMonth
  --ageImposeDay                Impose missing day to ageMissingDay
  --addSex                      Add sex
  --addPriorObservation         Add days of prior observation
  --addFutureObservation        Add days of future observation
  --addInObservation            Add in-observation flag
  --inObservationWindow=<win>   Window for in-observation [default: 0,0]
  --completeInterval            Require complete interval for in-observation
  --useDemographics             Use addDemographics() (more efficient, combines selected)
```

**Example:**
```R
Rscript inst/scripts/addCharacteristics.R skin_cancer \
  --addAge \
  --ageGroup='[[0,17],[18,64],[65,150]]' \
  --addSex \
  --addPriorObservation \
  --addFutureObservation \
  --addInObservation \
  --inObservationWindow='[0,0]' \
  --useDemographics
```

#### Add table intersections
```sh
Add table intersection counts, dates, days, or flags using PatientProfiles.

Usage:
  addTableIntersectCount.R <name> --tableName=<table> [options]
  addTableIntersectDate.R <name> --tableName=<table> [options]
  addTableIntersectDays.R <name> --tableName=<table> [options]
  addTableIntersectFlag.R <name> --tableName=<table> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --tableName=<table>           OMOP table name
  --window=<window>             Window [default: [-Inf,Inf]]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --targetStartDate=<col>       Start date column in target table
  --targetEndDate=<col>         End date column in target table
  --targetDate=<col>            Date column in target table
  --order=<order>               first or last [default: first]
  --inObservation=<logical>     Keep only records in observation [default: TRUE]
  --nameStyle=<style>           Naming pattern [default: {table_name}_{window_name}]
```

**Example:**
```R
Rscript inst/scripts/addTableIntersectCount.R skin_cancer \
  --tableName='drug_exposure' \
  --window='[-365,0]' \
  --inObservation='TRUE' \
  --nameStyle='{table_name}_{window_name}'
```

#### Add cohort intersections
```sh
Add cohort intersection counts, dates, days, or flags using PatientProfiles.

Usage:
  addCohortIntersectCount.R <name> --targetCohortTable=<target> [options]
  addCohortIntersectDate.R <name> --targetCohortTable=<target> [options]
  addCohortIntersectDays.R <name> --targetCohortTable=<target> [options]
  addCohortIntersectFlag.R <name> --targetCohortTable=<target> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --targetCohortTable=<target>  Name of the target cohort table
  --targetCohortId=<id>         Specific cohort definition ID (optional)
  --window=<window>             Window [default: -Inf,Inf]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --targetStartDate=<col>       Start date column in target cohort [default: cohort_start_date]
  --targetEndDate=<col>         End date column in target cohort [default: cohort_end_date]
  --nameStyle=<style>           Naming pattern [default: {cohort_name}_{window_name}]
```

**Example:**
```R
Rscript inst/scripts/addCohortIntersectCount.R skin_cancer \
  --targetCohortTable='target_cohort' \
  --targetCohortId='1' \
  --window='[-365,0]' \
  --nameStyle='{cohort_name}_{window_name}'
```

#### Add concept intersections
```sh
Add concept intersection counts, dates, or flags using PatientProfiles.

Usage:
  addConceptIntersectCount.R <name> --conceptSet=<json> [options]
  addConceptIntersectDate.R <name> --conceptSet=<json> [options]
  addConceptIntersectDays.R <name> --conceptSet=<json> [options]
  addConceptIntersectFlag.R <name> --conceptSet=<json> [options]

Options:
  -h --help                     Show this screen
  --version                     Show version
  --conceptSet=<json>           JSON concept set
  --window=<window>             Window [default: [[-Inf,Inf]]]
  --indexDate=<date_col>        Date column to use as index [default: cohort_start_date]
  --nameStyle=<style>           Naming pattern [default: {concept_name}_{window_name}]
```

**Example:**
```R
Rscript inst/scripts/addConceptIntersectCount.R skin_cancer \
  --conceptSet='[{"concept_id": 1118084, "concept_name": "metformin"}]' \
  --window='[[0,30],[31,365]]' \
  --nameStyle='{concept_name}_{window_name}'
```

### CohortSurvival
#### `estimateSingleEventSurvival`
Estimate survival for a single event of interest

```sh
Usage:
  estimateSingleEventSurvival.R [options]

Options:
  -h --help                           Show this screen
  --version                           Show version
  --targetCohortTable=<tableName>     Name of the cohort table containing the target cohorts. The table must be present in cdm and contain standard OMOP cohort columns.
  --outcomeCohortTable=<tableName>    Name of the cohort table containing the outcome cohorts. The table must be present in cdm and contain standard OMOP cohort columns.
  --outputPath=<path>                 Path for saving the survival table as a csv [default: outputs/single-event-survival.csv]
  --targetCohortId=<cohortId>         Target cohorts to include. It can either be a cohort_definition_id value or a cohort_name. Multiple ids are allowed. If not provided, all non-empty cohorts in targetCohortTable are used.
  --outcomeCohortId=<cohortId>        Outcome cohorts to include. It can either be a cohort_definition_id value or a cohort_name. Multiple ids are allowed. If not provided, all outcome cohorts in outcomeCohortTable are used.
  --outcomeDateVariable=<columnName>  Variable containing the outcome event date. This is usually cohort_start_date, but another date column in the outcome cohort can be used.  [default: cohort_start_date]
  --outcomeWashout=<days>             Number of days before target cohort entry used to exclude people with a prior outcome. Inf excludes people with any prior outcome before index; 0 applies no pre-index washout. [default: Inf]
  --censorOnCohortExit                If TRUE, an individual\'s follow up will be censored at their target cohort exit date.
  --censorOnDate=<date>               If provided, an individual\'s follow up will be censored at the given date. This can be a scalar Date or the name of a date column in the target cohort table.
  --weight=<columnName>               If provided, the name of a numeric column in the target cohort table containing observation weights to use in the Kaplan-Meier estimation.
  --followUpDays=<days>               Number of days to follow up individuals (lower bound 1, upper bound Inf). Follow-up is censored at this value. [default: Inf]
  --strata=<columnNames>              An optional list of target cohort column names to stratify by. Each element can be one column name or a character vector of column names for a combined stratum, for example the input could be ["sex", ["age_group", "sex"]] which will be interpreted as list("sex", c("age_group", "sex")).
  --eventGap=<days>                   Days between time points for which to report survival events, which are grouped into the specified intervals. [default: 30]
  --estimateGap=<days>                Days between time points for which to report survival estimates. First day will be day zero with risk estimates provided for times up to the end of follow-up, with a gap in days equivalent to estimateGap. [default: 1]
  --restrictedMeanFollowUp=<days>     Number of days of follow-up to use when calculating restricted mean survival. See Details.
  --minimumSurvivalDays=<days>        Minimum number of days required for the main cohort to contribute to the analysis. [default: 1]
```
#### `estimateCompetingEventSurvival`
Estimate time-to-event probabilities for one or more target cohorts when an event of interest can be precluded by a competing outcome.

```sh
Usage:
  estimateCompetingEventSurvial.R [options]

Options:
  -h --help                                  Show this screen
  --version                                  Show version
  --targetCohortTable=<table>                Name of the cohort table containing the target cohorts. The table must be present in cdm and contain standard OMOP cohort columns.
  --outcomeCohortTable=<table>               Name of the cohort table containing the outcome of interest.
  --competingOutcomeCohortTable=<table>      Name of the cohort table containing the competing outcome.
  --outputPath=<path>                 Path for saving the survival table as a csv [default: outputs/competing-event-survival.csv]
  --targetCohortId=<id>                      Target cohorts to include. It can either be a cohort_definition_id value or a cohort_name. Multiple ids are allowed. If omitted, all non-empty cohorts in targetCohortTable are used.
  --outcomeCohortId=<id>                     Outcome cohorts to include. It can either be a cohort_definition_id value or a cohort_name. Multiple ids are allowed. If omitted, all outcome cohorts in outcomeCohortTable are used.
  --outcomeDateVariable=<variable>           Variable containing the outcome event date. This is usually "cohort_start_date", but another date column in the outcome cohort can be used. [default: cohort_start_date]
  --outcomeWashout=<days>                    Number of days before target cohort entry used to exclude people with a prior outcome. Inf excludes people with any prior outcome before index; 0 applies no pre-index washout. [default: Inf]
  --competingOutcomeCohortId=<id>            Competing outcome cohorts to include. It can either be a cohort_definition_id value or a cohort_name. Multiple ids are allowed. If omitted, all competing outcome cohorts in competingOutcomeCohortTable are used.
  --competingOutcomeDateVariable=<variable>  Variable containing the competing outcome event date. [default: cohort_start_date]
  --competingOutcomeWashout=<days>           Number of days before target cohort entry used to exclude people with a prior competing outcome. Inf excludes people with any prior competing outcome before index; 0 applies no pre-index washout. [default: Inf]
  --censorOnCohortExit                       If active, an individual\'s follow up will be censored at their target cohort exit date.
  --censorOnDate=<date>                      If specified, an individual\'s follow up will be censored at the given date. This can be a scalar Date or the name of a date column in the target cohort table.
  --weight=<weight>                          If specified, the name of a numeric column in the target cohort table containing observation weights.
  --followUpDays=<days>                      Number of days to follow up individuals (lower bound 1, upper bound Inf). Follow-up is censored at this value. [default: Inf]
  --strata=<strata>                          A list of target cohort column names to stratify by. Each element can be one column name or a character vector of column names for a combined stratum, for example list("sex", c("age_group", "sex")).
  --eventGap=<gap>                           Days between time points for which to report survival events, which are grouped into the specified intervals. [default: 30]
  --estimateGap=<gap>                        Days between time points for which to report survival estimates. First day will be day zero with risk estimates provided for times up to the end of follow-up, with a gap in days equivalent to estimateGap. [default: 1]
  --restrictedMeanFollowUp=<days>            Number of days of follow-up to use when calculating restricted mean summaries. See Details.
  --minimumSurvivalDays=<days>               Minimum number of days required for the main cohort to contribute to the analysis. [default: 1]
```

#### addCohortSurvival
Add time and event status to a cohort table.
Scripts to analyse these variables are not included in this package, see the source library's [vignette](https://darwin-eu.github.io/CohortSurvival/articles/a03_Further_survival_analyses.html) for details.

```sh
Usage:
  addCohortSurvival.R <tableName> [options]

Options:
  -h --help                           Show this screen
  --version                           Show version
  --name=<tableName>                  Name of the new table. In the library this is optional, but must be specified to use the output.
  --outcomeCohortTable=<table>        Name of the cohort table containing the outcome of interest
  --outcomeCohortId=<id>              IDs of event cohorts to include. Values can be cohort definition IDs or cohort names [default: 1]
  --outcomeDateVariable=<variable>    Variable containing date of outcome event. [default: cohort_start_date]
  --outcomeWashout=<days>             Washout time in days for the outcome. If an individual has an outcome during the washout period before target cohort entry, status and time will be set to NA. Use Inf for any prior outcome and 0 for no pre-index washout. [default: Inf]
  --censorOnCohortExit                If active, an individual\'s follow up will be censored at their target cohort exit.
  --censorOnDate=<date>               If specified, an individual\'s follow up will be censored at the given date. This can be a scalar Date or the name of a date column
  --followUpDays=<days>               Number of days to follow up individuals (lower bound 1, upper bound Inf). Follow-up is censored at this value. [default: Inf]
```