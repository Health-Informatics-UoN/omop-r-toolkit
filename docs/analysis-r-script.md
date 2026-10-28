# 5STES – OMOP R Toolkit: R Scripts and CLI Reference

## Overview

This document describes the R scripts exposed by the OMOP R Toolkit and shows how to combine them for analyses within the Five Safes TES (5STES) environment. It complements [TES Message Examples](./analysis-tes-json.md), which contains complete TES JSON tasks, and [Analysis Types](./analysis-types.md), which explains the research applications.

The toolkit wraps OMOP CDM analysis packages with command-line R scripts under `inst/scripts/`. The scripts create or enrich cohort tables in the connected TRE database, calculate aggregate results, and optionally write output files. The examples below are based on the repository source snapshot supplied on **27 October 2026**; they have not all been executed against a TRE database.

## Running the scripts

Run commands from the **repository working directory**, since the scripts load helper files using relative paths such as `R/postgres-connect-5s-tes.R`. In 5STES, place the command tokens in a TES executor's `command` array and use the OMOP R Toolkit image, `ghcr.io/health-informatics-uon/omop-r-tools:edge`.

The database connector reads `postgresServer`, `postgresPort`, `postgresUsername`, `postgresPassword`, `postgresDatabase`, and `postgresSchema` from the execution environment. The TRE deployment must provide these values securely; do not embed credentials in a TES JSON message.

### CLI conventions

- Run an R script with `Rscript inst/scripts/<script>.R ...`.
- A switch such as `--addAge` is passed without a value; an option such as `--gapEra=7` takes a value. Where an option is declared as `<logical>`, use an explicit `TRUE` or `FALSE`.
- Quote JSON and windows when invoking a shell: `--conceptSet='{"skin_cancer":[139750]}'`, `--window='[-365,-1]'`, and `--ageGroup='[[0,17],[18,64],[65,150]]'`.
- Time windows are relative to the chosen index date. For example, `[-365,-1]` means 365 through one day before the index date; `[0,30]` covers index day through day 30. The parser supports `-Inf,Inf`, bracketed pairs, lists of pairs, and named windows.
- Use `--outputPath=/outputs/<file>.csv` (or an output subdirectory) inside 5STES so results fall under the TES output directory. For a non-TES local run, replace this with a writable local path.
- Script names and option names are case-sensitive. The current implementation uses **`--outputPath`**, not `--output-path`.
- The notation `<study_cohort>`, `<target_cohort>`, `<script>`, and similar tokens indicates a placeholder to replace before running a command; do not execute those placeholders literally.
- `defineConceptCohortSet.R` uses the supplied concept IDs; it does **not** automatically expand them to descendant concepts. Select the concept set required by the study.
- R scripts that enrich a cohort write patient-level features back to TRE cohort tables. **They do not automatically create export CSVs**. Use an appropriate summary script for aggregate output, and clean up study tables after they are no longer needed.

For individual script help:

```bash
Rscript inst/scripts/<script>.R --help
```

## 1. Shared cohort utilities

The following scripts are used by several analysis workflows.

| Script | Purpose | Main arguments |
|---|---|---|
| `defineConceptCohortSet.R` | Generate OMOP concept-based cohorts | `<name>`, `--conceptSet`, `--alloccurrences`, `--end`, `--requiredObservation` |
| `count-cohorts.R` | Count cohort members and write a table | `<name>`, `--outputPath` |
| `cleanUpCohortTables.R` | Remove one or more study cohort tables | `<name> ...` |

### Create, count and clean up a cohort

```bash
Rscript inst/scripts/defineConceptCohortSet.R skin_cancer_demo \
  --conceptSet='{"skin_cancer":[139750]}'

Rscript inst/scripts/count-cohorts.R skin_cancer_demo \
  --outputPath=/outputs/skin_cancer_count.csv

Rscript inst/scripts/cleanUpCohortTables.R skin_cancer_demo
```

Optional cohort settings include `--alloccurrences` (all matching occurrences instead of the first), `--end=event_end_date` or `--end=observation_period_end_date`, and `--requiredObservation=365,0` (days before and after the index event).

**Output note:** `count-cohorts.R` currently writes with `write.table()` rather than `write.csv()`. Its `.csv` path therefore does not guarantee comma-separated content; change the implementation if a standard CSV is required.

---

## 2. Incidence and Prevalence

`incidencePrevalence.R` creates a denominator cohort, then estimates incidence, point prevalence, and/or period prevalence for an existing outcome cohort. Provide at least one output-path option to select the required estimator.

### Example: incidence and both prevalence estimates

```bash
Rscript inst/scripts/defineConceptCohortSet.R ip_skin_cancer_outcome \
  --conceptSet='{"skin_cancer":[139750]}'

Rscript inst/scripts/incidencePrevalence.R ip_skin_cancer_denominator \
  --outcomeCohortName=ip_skin_cancer_outcome \
  --denominatorAgeGroup='[[0,150]]' \
  --denominatorDaysPriorObservation=365 \
  --estimateIncidenceOutputPath=/outputs/incidence.csv \
  --incidenceInterval=years \
  --estimatePointPrevalenceOutputPath=/outputs/point_prevalence.csv \
  --pointPrevalenceInterval=years \
  --pointPrevalenceTimePoint=start \
  --estimatePeriodPrevalenceOutputPath=/outputs/period_prevalence.csv \
  --periodPrevalenceInterval=years

Rscript inst/scripts/cleanUpCohortTables.R \
  ip_skin_cancer_outcome ip_skin_cancer_denominator
```

| Options | Meaning |
|---|---|
| `--denominatorCohortDateRange=YYYY-MM-DD,YYYY-MM-DD` | Earliest and latest denominator cohort dates |
| `--denominatorAgeGroup='[[0,17],[18,64],[65,150]]'` | Denominator age bands |
| `--denominatorMale`, `--denominatorFemale`, `--denominatorBothOff` | Sex-cohort selection |
| `--denominatorDaysPriorObservation=365` | Required prior observation days |
| `--outcomeCohortName=<name>` | Existing outcome cohort table |
| `--estimateIncidenceOutputPath=<path>` | Enable incidence estimate and export |
| `--incidenceInterval=years`, `--incidenceOutcomeWashout=0`, `--incidenceRepeatedEvents` | Incidence interval, washout and repeated-event behaviour |
| `--estimatePointPrevalenceOutputPath=<path>`, `--pointPrevalenceInterval=years`, `--pointPrevalenceTimePoint=start` | Point-prevalence output, period and time point |
| `--estimatePeriodPrevalenceOutputPath=<path>`, `--periodPrevalenceInterval=years` | Period-prevalence output and interval |

**Source-code caveat:** The supplied `incidencePrevalence.R` has a trailing comma after `interval = arguments$periodPrevalenceInterval` in `estimatePeriodPrevalence()`. Correct that call before relying on the period-prevalence branch. The example documents the exposed CLI; it is not a claim that all three estimators succeed without that fix.

---

## 3. PatientProfiles

`PatientProfiles` scripts add demographic, observation, cohort-event, concept-event, or OMOP-table features to an existing cohort. Most scripts follow a common workflow: create a cohort, enrich it, summarise selected columns, and clean up. Use `summariseCohort.R` for aggregate output.

### 3.1. Cohort characteristics

Calculate age, age groups, sex, prior/future observation days, and an in-observation flag. This example uses `cohort_end_date` as the index date and the combined `addDemographics()` path.

```bash
Rscript inst/scripts/defineConceptCohortSet.R pp_characteristics_01 \
  --conceptSet='{"skin_cancer":[139750]}'

Rscript inst/scripts/addCharacteristics.R pp_characteristics_01 \
  --indexDate=cohort_end_date \
  --addAge \
  --ageGroup='[[0,17],[18,64],[65,150]]' \
  --ageMissingMonth=6 --ageMissingDay=15 \
  --ageImposeMonth --ageImposeDay \
  --addSex --addPriorObservation --addFutureObservation \
  --addInObservation --inObservationWindow='[0,30]' \
  --completeInterval --useDemographics

Rscript inst/scripts/summariseCohort.R pp_characteristics_01 \
  --variables='["age","sex","prior_observation","future_observation","in_observation"]' \
  --estimates='["count","percentage","median","q25","q75"]' \
  --outputPath=/outputs/patient_characteristics.csv

Rscript inst/scripts/cleanUpCohortTables.R pp_characteristics_01
```

Other relevant characteristics options: `--ageName=<column>`, `--indexDate=<date_column>`, and the individual `--addAge`, `--addSex`, `--addPriorObservation`, `--addFutureObservation`, and `--addInObservation` switches. `--useDemographics` combines supported demographic features; the observation flag is added separately by the wrapper.

### 3.2. Cohort intersections

Cohort intersections compare a study cohort with another existing cohort table. The target cohort must exist before running these commands. The example creates both cohorts so it does not depend on a previous TES task.

```bash
Rscript inst/scripts/defineConceptCohortSet.R pp_skin_cancer_01 \
  --conceptSet='{"skin_cancer":[139750]}'

Rscript inst/scripts/defineConceptCohortSet.R pp_headache_01 \
  --conceptSet='{"headache":[378253]}' \
  --alloccurrences --end=event_end_date

Rscript inst/scripts/addCohortIntersectCount.R pp_skin_cancer_01 \
  --targetCohortTable=pp_headache_01 --targetCohortId=1 \
  --window='[-365,-1]' \
  --nameStyle='{cohort_name}_count_{window_name}'

Rscript inst/scripts/summariseCohort.R pp_skin_cancer_01 \
  --variables='["headache_count_m365_to_m1"]' \
  --estimates='["mean","median","q25","q75"]' \
  --outputPath=/outputs/cohort_intersections.csv

Rscript inst/scripts/cleanUpCohortTables.R pp_skin_cancer_01 pp_headache_01
```

Other cohort-intersection scripts use the same source and target cohort tables:

```bash
# First/last matching cohort date
Rscript inst/scripts/addCohortIntersectDate.R <study_cohort> \
  --targetCohortTable=<target_cohort> --targetCohortId=1 \
  --window='[-365,0]' --order=first

# Days between index date and first/last matching cohort event
Rscript inst/scripts/addCohortIntersectDays.R <study_cohort> \
  --targetCohortTable=<target_cohort> --targetCohortId=1 \
  --window='[-365,0]' --order=last

# True/false: any matching cohort event in the lookback window
Rscript inst/scripts/addCohortIntersectFlag.R <study_cohort> \
  --targetCohortTable=<target_cohort> --targetCohortId=1 \
  --window='[-365,-1]'

# Event occurrence plus date or days to the event
Rscript inst/scripts/addCohortEventDate.R <study_cohort> \
  --targetCohortTable=<target_cohort> --targetCohortId=1 \
  --window='[[0,365]]' --order=first

Rscript inst/scripts/addCohortEventDays.R <study_cohort> \
  --targetCohortTable=<target_cohort> --targetCohortId=1 \
  --window='[[0,365]]' --order=first
```

The cohort intersection wrappers also support `--indexDate`, matching date-column options (`--targetDate` for Date/Days, `--targetStartDate` and `--targetEndDate` for Count/Flag), and `--nameStyle`. Event Date/Days additionally support `--censorDate`.

### 3.3. Concept intersections and concept events

Use concept intersections to count occurrences, find event dates, or set an event flag for a selected OMOP concept set. The following example counts selected skin cancer concept events within the defined window.

```bash
Rscript inst/scripts/defineConceptCohortSet.R pp_concept_01 \
  --conceptSet='{"skin_cancer":[139750]}'

Rscript inst/scripts/addConceptIntersectCount.R pp_concept_01 \
  --conceptSet='{"skin_cancer":[139750]}' \
  --window='[[-Inf,Inf]]' \
  --nameStyle='{concept_name}_count_{window_name}'

Rscript inst/scripts/summariseCohort.R pp_concept_01 \
  --variables='["skin_cancer_count_minf_to_inf"]' \
  --estimates='["mean","median","q25","q75"]' \
  --outputPath=/outputs/concept_intersections.csv

Rscript inst/scripts/cleanUpCohortTables.R pp_concept_01
```

Alternative concept-based operations:

```bash
# Date of first/last matching concept occurrence
Rscript inst/scripts/addConceptIntersectDate.R <study_cohort> \
  --conceptSet='{"headache":[378253]}' \
  --window='[[-365,-1]]' --order=last

# Binary flag for a matching concept before index
Rscript inst/scripts/addConceptIntersectFlag.R <study_cohort> \
  --conceptSet='{"headache":[378253]}' \
  --window='[[-365,-1]]' \
  --nameStyle='{concept_name}_flag_{window_name}'

# Event occurrence and first matching event date after index
Rscript inst/scripts/addConceptEventDate.R <study_cohort> \
  --conceptSet='{"headache":[378253]}' \
  --window='[[1,365]]' --order=first

# Event occurrence and days until first matching event
Rscript inst/scripts/addConceptEventDays.R <study_cohort> \
  --conceptSet='{"headache":[378253]}' \
  --window='[[1,365]]' --order=first
```

For concept-event scripts, additional options include `--indexDate`, `--targetDate=event_start_date` (or `event_end_date`), `--censorDate`, `--multipleEvents`, and `--nameStyle`.

**Not implemented in this snapshot:** `addConceptIntersectDays.R` does not exist under `inst/scripts/`. Use the available concept Date/Count/Flag scripts or concept Event Days functionality instead; do not reference a nonexistent executor.

### 3.4. OMOP table intersections

These scripts intersect cohort records with a standard OMOP CDM table such as `visit_occurrence`, `drug_exposure`, or `condition_occurrence`. The example counts visits for the study cohort.

```bash
Rscript inst/scripts/defineConceptCohortSet.R pp_visits_01 \
  --conceptSet='{"skin_cancer":[139750]}'

Rscript inst/scripts/addTableIntersectCount.R pp_visits_01 \
  --tableName=visit_occurrence \
  --window='[-Inf,Inf]' \
  --nameStyle='{table_name}_count_{window_name}'

Rscript inst/scripts/summariseCohort.R pp_visits_01 \
  --variables='["visit_occurrence_count_minf_to_inf"]' \
  --estimates='["mean","median","q25","q75"]' \
  --outputPath=/outputs/visit_counts.csv

Rscript inst/scripts/cleanUpCohortTables.R pp_visits_01
```

Alternatives:

```bash
Rscript inst/scripts/addTableIntersectDate.R <study_cohort> \
  --tableName=visit_occurrence --window='[-365,-1]' \
  --order=last

Rscript inst/scripts/addTableIntersectDays.R <study_cohort> \
  --tableName=visit_occurrence --window='[-365,-1]' \
  --order=last

Rscript inst/scripts/addTableIntersectFlag.R <study_cohort> \
  --tableName=visit_occurrence --window='[-365,-1]'
```

Table-intersection wrappers support `--indexDate`, `--inObservation=TRUE|FALSE`, `--nameStyle`, and table-specific date columns (`--targetDate`, `--targetStartDate`, or `--targetEndDate`, according to the script).

### 3.5. Aggregate cohort summaries

`summariseCohort.R` can be run after any of the feature-generation scripts above. It accepts `--variables` and `--estimates` as JSON arrays, plus optional `--group`, `--strata`, `--includeOverallGroup`, `--includeOverallStrata`, `--counts`, `--weights`, and `--customEstimates`.

```bash
Rscript inst/scripts/summariseCohort.R <enriched_cohort> \
  --variables='["age","sex"]' \
  --estimates='["count","percentage","median","q25","q75"]' \
  --outputPath=/outputs/cohort_summary.csv
```

The wrapper exports with `minCellCount = 5`. Feature column names depend on the concept/cohort labels and `--nameStyle`; **check the generated columns before reusing a `--variables` selection**. Do not export patient-level tables directly from an eyes-off TRE.

---

## 4. DrugExposureDiagnostics

`drugExposureDiagnostics.R` evaluates drug exposure records for ingredient concept IDs. Its default checks are missingness, exposure duration, and quantity. It writes a directory of diagnostic results rather than a single predetermined CSV file.

```bash
Rscript inst/scripts/drugExposureDiagnostics.R \
  --ingredients=1125315 \
  --checks=missing,exposureDuration,quantity \
  --byConcept \
  --sample=10000 \
  --minCellCount=5 \
  --outputPath=/outputs/drug_exposure_diagnostics
```

| Option | Purpose |
|---|---|
| `--ingredients=1125315,161` | Comma-separated ingredient concept IDs |
| `--checks=missing,exposureDuration,quantity` | Checks to run; these are the wrapper's defaults |
| `--sample=10000` | Limit sampling; use `0` for all records |
| `--byConcept` | Include breakdown by drug concept |
| `--minCellCount=5` | Disclosure-control threshold |
| `--earliestStartDate=YYYY-MM-DD` | Earliest drug exposure start date |
| `--subsetToConceptId=<ids>` | Include or exclude selected concept IDs |
| `--exposureTypeId=<id>` | Restrict to a drug exposure type |
| `--tablePrefix=<prefix>`, `--databaseId=<id>` | Temporary-table and output database identifiers |

---

## 5. DrugUtilisation

These scripts support drug-cohort creation, exposure metrics, indications, restart analysis, dose coverage, and combining aggregate results. Ingredient **names** are used for `generateIngredientCohortSet.R --ingredient`; ingredient **concept IDs** are used for `--ingredientConceptId` in the metric and summarisation wrappers.

### 5.1. Generate an ingredient cohort

```bash
Rscript inst/scripts/generateIngredientCohortSet.R du_acetaminophen_01 \
  --ingredient=acetaminophen \
  --gapEra=7 \
  --numberExposures=TRUE \
  --daysPrescribed=TRUE \
  --outputPath=/outputs/ingredient_cohort_settings.csv
```

Alternatively, define a cohort using `--atc=<ATC_name>` instead of `--ingredient`. The script also accepts `--subsetCohort` and `--subsetCohortId` to restrict the source population. `--outputPath` here saves **cohort settings**, not a patient-level cohort export.

### 5.2. Summarise drug utilisation

```bash
Rscript inst/scripts/summariseDrugUtilisation.R du_acetaminophen_01 \
  --ingredientConceptId=1125315 \
  --gapEra=7 \
  --strata='[]' \
  --estimates='["mean","sd","count_missing","percentage_missing"]' \
  --outputPath=/outputs/drug_utilisation.csv
```

Use the `--numberExposures`, `--numberEras`, `--daysExposed`, `--daysPrescribed`, `--timeToExposure`, `--initialExposureDuration`, `--initialQuantity`, `--cumulativeQuantity`, `--initialDailyDose`, and `--cumulativeDose` options with explicit `TRUE`/`FALSE` values to select metrics. Other supported options include `--conceptSet`, `--indexDate`, `--censorDate`, and `--restrictIncident`.

### 5.3. Add drug utilisation variables to a cohort

```bash
Rscript inst/scripts/addDrugUtilisation.R du_acetaminophen_01 \
  --ingredientConceptId=1125315 \
  --gapEra=7 \
  --nameStyle='{value}_{concept_name}'

# First inspect the generated variable names, then summarise a selected metric.
Rscript inst/scripts/summariseCohort.R du_acetaminophen_01 \
  --variables='["days_exposed_ingredient_1125315_descendants"]' \
  --estimates='["mean","median","q25","q75"]' \
  --outputPath=/outputs/drug_utilisation_metrics.csv
```

`addDrugUtilisation.R` uses the same metric switches as the summary wrapper and also accepts `--nameStyle`. It enriches the database cohort; it does not itself export aggregate results. The variable name in the second command is an example and **must match the resulting column**.

### 5.4. Add and summarise indications

```bash
Rscript inst/scripts/defineConceptCohortSet.R du_headache_01 \
  --conceptSet='{"headache":[378253]}'

Rscript inst/scripts/addIndication.R du_acetaminophen_01 \
  --indicationCohortName=du_headache_01 \
  --indicationCohortId=1 \
  --window='[-30,0]' \
  --mutuallyExclusive=FALSE

Rscript inst/scripts/summariseIndication.R du_acetaminophen_01 \
  --indicationCohortName=du_headache_01 \
  --indicationCohortId=1 \
  --window='[-30,0]' \
  --mutuallyExclusive=FALSE \
  --outputPath=/outputs/indication_summary.csv
```

Both indication scripts support `--unknownIndicationTable`, `--indexDate`, `--censorDate`, and `--restrictIncident`. `addIndication.R` supports `--nameStyle`, while `summariseIndication.R` supports `--strata`. A recorded condition near an index drug exposure indicates temporal proximity, not proof of the prescribing indication.

### 5.5. Summarise dose coverage

```bash
Rscript inst/scripts/summariseDoseCoverage.R du_acetaminophen_01 \
  --ingredientConceptId=1125315 \
  --estimates='["mean","sd","min","max"]' \
  --outputPath=/outputs/dose_coverage.csv
```

The script also exposes `--sampleSize=<n>` and `--conceptSet=<json>`. In the supplied implementation, `--conceptSet` is parsed but is **not passed** to `DrugUtilisation::summariseDoseCoverage()`. Do not imply that option changes this computation without a code fix.

### 5.6. Summarise subsequent drug use / restarts

```bash
Rscript inst/scripts/generateIngredientCohortSet.R du_metformin_01 \
  --ingredient=metformin --gapEra=7

Rscript inst/scripts/summariseDrugRestart.R du_acetaminophen_01 \
  --switchCohortTable=du_metformin_01 \
  --followUpDays=365 \
  --incident=FALSE \
  --outputPath=/outputs/drug_restart.csv
```

Optional settings include `--switchCohortId`, `--strata`, `--censorDate`, and `--restrictToFirstDiscontinuation`. Acetaminophen and metformin are illustrative test inputs, not clinically equivalent or interchangeable treatments.

### 5.7. Combine summarised results

```bash
Rscript inst/scripts/finaliseDrugUtilisationResults.R \
  /outputs/drug_utilisation.csv \
  /outputs/indication_summary.csv \
  --outputPath=/outputs/final_drug_utilisation.csv
```

Optional switches: `--suppressCounts` and `--suppressGroup`. Only combine **compatible summarised-result structures**; this wrapper reads each path as RDS or CSV and uses `omopgenerics::bind()`. A generic CSV from another wrapper is not necessarily compatible. Validate this integration against your actual files.

### 5.8. Clean up study tables

```bash
Rscript inst/scripts/cleanUpCohortTables.R \
  du_acetaminophen_01 du_headache_01 du_metformin_01
```

---

## 6. TreatmentPatterns

`treatmentPatterns.R` computes aggregate pathways from separate **target** (e.g. disease) and **event** (e.g. treatment) cohort tables, optionally with an **exit** cohort. Its `--combinedCohortTable` is an intermediate table dropped by the script. The study cohorts should be cleaned up separately.

```bash
Rscript inst/scripts/defineConceptCohortSet.R tp_skin_cancer_01 \
  --conceptSet='{"skin_cancer":[139750]}'

Rscript inst/scripts/generateIngredientCohortSet.R tp_treatments_01 \
  --ingredient=acetaminophen,amoxicillin --gapEra=1

Rscript inst/scripts/treatmentPatterns.R \
  --targetCohortTable=tp_skin_cancer_01 \
  --eventCohortTable=tp_treatments_01 \
  --combinedCohortTable=tp_combined_01 \
  --minEraDuration=7 \
  --combinationWindow=7 \
  --minPostCombinationDuration=7 \
  --filterTreatments=First \
  --maxPathLength=5 \
  --minCellCount=5 \
  --outputPath=/outputs/treatment_patterns

Rscript inst/scripts/cleanUpCohortTables.R \
  tp_skin_cancer_01 tp_treatments_01
```

### Alternative pathway configurations

| Options | Analysis behaviour |
|---|---|
| `--filterTreatments=First`, `Changes`, or `All` | Choose which treatment events enter a pathway |
| `--startAnchor`, `--windowStart`, `--endAnchor`, `--windowEnd` | Define the analysis window relative to the target cohort |
| `--splitEventCohorts=<names>` and `--splitTime=<days>` | Split named event cohorts into acute/therapy phases; supply both together |
| `--minEraDuration`, `--eraCollapseSize` | Minimum treatment-era duration and same-treatment era collapse gap |
| `--combinationWindow`, `--minPostCombinationDuration`, `--overlapWithKeep` | Define overlapping-treatment combinations and handling of short overlaps |
| `--maxPathLength`, `--concatTargets=TRUE|FALSE`, `--nonePaths` | Control pathway structure and inclusion of event-free paths |
| `--exitCohortTable=<table>` | Add an exit cohort (for example, a generated death cohort) |
| `--censorType=minCellCount|remove|mean`, `--minCellCount` | Aggregate small-cell disclosure control |
| `--ageWindow=<years_or_breaks>` | Age-group width or explicit breaks |
| `--analysisId`, `--description`, `--archiveName` | Results metadata and optional ZIP archive |

The wrapper uses `computePathways()` and exports aggregate results only. It does not export individual patient pathways or produce plots. `minPostCombinationDuration <= minEraDuration` and `combinationWindow >= minEraDuration` are the package's recommended settings; the wrapper warns for combinations that violate them.

---

## 7. CohortSurvival

The toolkit provides cohort-level survival feature generation and aggregate survival estimation. These operations require study and outcome cohorts that are defined in the OMOP database.

### 7.1. Prepare target, outcome and optional death cohorts

```bash
Rscript inst/scripts/defineConceptCohortSet.R surv_target_01 \
  --conceptSet='{"skin_cancer":[139750]}'

Rscript inst/scripts/defineConceptCohortSet.R surv_outcome_01 \
  --conceptSet='{"headache":[378253]}' \
  --alloccurrences --end=event_end_date

# Optional: generate a death cohort for competing-outcome analyses.
Rscript inst/scripts/createDeathCohort.R surv_death_01 \
  --subsetCohort=surv_target_01
```

### 7.2. Estimate single-event survival

```bash
Rscript inst/scripts/estimateSingleEventSurvival.R \
  --targetCohortTable=surv_target_01 \
  --outcomeCohortTable=surv_outcome_01 \
  --outcomeWashout=0 \
  --followUpDays=365 \
  --eventGap=30 \
  --estimateGap=30 \
  --outputPath=/outputs/single_event_survival.csv
```

Other options: `--targetCohortId`, `--outcomeCohortId`, `--outcomeDateVariable`, `--censorOnCohortExit`, `--censorOnDate`, `--weight`, `--strata`, `--restrictedMeanFollowUp`, and `--minimumSurvivalDays`. This wrapper computes the aggregate estimate and exports it; it does not produce a patient-level CSV.

### 7.3. Add survival time and event status to a cohort

```bash
Rscript inst/scripts/addCohortSurvival.R surv_target_01 \
  --name=surv_target_with_survival_01 \
  --outcomeCohortTable=surv_outcome_01 \
  --outcomeCohortId=1 \
  --outcomeWashout=0 \
  --followUpDays=365
```

This wrapper adds survival-related variables to a new TRE cohort table, not an aggregate results file. `--name` is required by the implementation. Options include `--outcomeDateVariable`, `--censorOnCohortExit`, and `--censorOnDate`.

### 7.4. Competing-event survival — implementation warning

The repository includes `estimateCompetingEventSurvival.R`, intended to estimate the event of interest while accounting for a competing outcome cohort. Its CLI declares `--targetCohortTable`, `--outcomeCohortTable`, `--competingOutcomeCohortTable`, `--followUpDays`, `--eventGap`, `--estimateGap`, `--strata`, `--outputPath`, and the corresponding outcome/censoring options.

**Do not treat this script as executable without repair:** the current source passes `arguments$competingOutcomeCohortTabl` (missing final `e`) to `estimateCompetingRiskSurvival()`. Its usage line also misspells the script name as `estimateCompetingEventSurvial.R`. Fix and retest the wrapper before adding it to an operational TES workflow.

### 7.5. Clean up survival cohorts

```bash
Rscript inst/scripts/cleanUpCohortTables.R \
  surv_target_01 surv_outcome_01 surv_death_01 surv_target_with_survival_01
```

Run cleanup only for tables that were actually created by your workflow.

---


## 8. Script index and supported CLI options

The following index is derived from the **actual `Usage` and `Options` definitions in the supplied `inst/scripts/*.R` files**. Use it to confirm script names and flags when adapting the examples. `[options]` means that a script accepts the flags listed in its own help text. `-h`/`--help` and `--version` are available in the documented interfaces and are omitted below for brevity.

### `addCharacteristics.R`

**Usage:** `addCharacteristics.R <name> [options]`

**Options:**

```text
--indexDate=<date_col>
--addAge
--ageGroup=<json>
--ageName=<name>
--ageMissingMonth=<m>
--ageMissingDay=<d>
--ageImposeMonth
--ageImposeDay
--addSex
--addPriorObservation
--addFutureObservation
--addInObservation
--inObservationWindow=<win>
--completeInterval
--useDemographics
```

### `addCohortEventDate.R`

**Usage:** `addCohortEventDate.R <name> --targetCohortTable=<target> [options]`

**Options:**

```text
--targetCohortTable=<target>
--targetCohortId=<id>
--window=<window>
--order=<order>
--indexDate=<date_col>
--targetDate=<col>
--censorDate=<col>
--nameStyle=<style>
```

### `addCohortEventDays.R`

**Usage:** `addCohortEventDays.R <name> --targetCohortTable=<target> [options]`

**Options:**

```text
--targetCohortTable=<target>
--targetCohortId=<id>
--window=<window>
--order=<order>
--indexDate=<date_col>
--targetDate=<col>
--censorDate=<col>
--nameStyle=<style>
```

### `addCohortIntersectCount.R`

**Usage:** `addCohortIntersectCount.R <name> --targetCohortTable=<target> [options]`

**Options:**

```text
--targetCohortTable=<target>
--targetCohortId=<id>
--window=<window>
--indexDate=<date_col>
--targetStartDate=<col>
--targetEndDate=<col>
--nameStyle=<style>
```

### `addCohortIntersectDate.R`

**Usage:** `addCohortIntersectDate.R <name> --targetCohortTable=<target> [options]`

**Options:**

```text
--targetCohortTable=<target>
--targetCohortId=<id>
--window=<window>
--order=<order>
--indexDate=<date_col>
--targetDate=<col>
--nameStyle=<style>
```

### `addCohortIntersectDays.R`

**Usage:** `addCohortIntersectDays.R <name> --targetCohortTable=<target> [options]`

**Options:**

```text
--targetCohortTable=<target>
--targetCohortId=<id>
--window=<window>
--order=<order>
--indexDate=<date_col>
--targetDate=<col>
--nameStyle=<style>
```

### `addCohortIntersectFlag.R`

**Usage:** `addCohortIntersectFlag.R <name> --targetCohortTable=<target> [options]`

**Options:**

```text
--targetCohortTable=<target>
--targetCohortId=<id>
--window=<window>
--indexDate=<date_col>
--targetStartDate=<col>
--targetEndDate=<col>
--nameStyle=<style>
```

### `addCohortSurvival.R`

**Usage:** `addCohortSurvival.R <tableName> [options]`

**Options:**

```text
--name=<tableName>
--outcomeCohortTable=<table>
--outcomeCohortId=<id>
--outcomeDateVariable=<variable>
--outcomeWashout=<days>
--censorOnCohortExit
--censorOnDate=<date>
--followUpDays=<days>
```

### `addConceptEventDate.R`

**Usage:** `addConceptEventDate.R <name> --conceptSet=<json> [options]`

**Options:**

```text
--conceptSet=<json>
--window=<window>
--order=<order>
--indexDate=<date_col>
--targetDate=<type>
--censorDate=<col>
--multipleEvents=<mode>
--nameStyle=<style>
```

### `addConceptEventDays.R`

**Usage:** `addConceptEventDays.R <name> --conceptSet=<json> [options]`

**Options:**

```text
--conceptSet=<json>
--window=<window>
--order=<order>
--indexDate=<date_col>
--targetDate=<type>
--censorDate=<col>
--multipleEvents=<mode>
--nameStyle=<style>
```

### `addConceptIntersectCount.R`

**Usage:** `addConceptIntersectCount.R <name> --conceptSet=<json> [options]`

**Options:**

```text
--conceptSet=<json>
--window=<window>
--indexDate=<date_col>
--nameStyle=<style>
```

### `addConceptIntersectDate.R`

**Usage:** `addConceptIntersectDate.R <name> --conceptSet=<json> [options]`

**Options:**

```text
--conceptSet=<json>
--window=<window>
--order=<order>
--indexDate=<date_col>
--nameStyle=<style>
```

### `addConceptIntersectFlag.R`

**Usage:** `addConceptIntersectFlag.R <name> --conceptSet=<json> [options]`

**Options:**

```text
--conceptSet=<json>
--window=<window>
--indexDate=<date_col>
--nameStyle=<style>
```

### `addDrugUtilisation.R`

**Usage:** `addDrugUtilisation.R <name> [options]`

**Options:**

```text
--ingredientConceptId=<ids>
--conceptSet=<json>
--gapEra=<n>
--indexDate=<date_col>
--censorDate=<date_col>
--restrictIncident=<logical>
--numberExposures=<logical>
--numberEras=<logical>
--daysExposed=<logical>
--daysPrescribed=<logical>
--timeToExposure=<logical>
--initialQuantity=<logical>
--cumulativeQuantity=<logical>
--initialDailyDose=<logical>
--cumulativeDose=<logical>
--nameStyle=<style>
```

### `addIndication.R`

**Usage:** `addIndication.R <name> --indicationCohortName=<table> [options]`

**Options:**

```text
--indicationCohortName=<table>
--indicationCohortId=<ids>
--window=<windows>
--unknownIndicationTable=<table>
--indexDate=<date_col>
--censorDate=<date_col>
--mutuallyExclusive=<logical>
--restrictIncident=<logical>
--nameStyle=<style>
```

### `addTableIntersectCount.R`

**Usage:** `addTableIntersectCount.R <name> --tableName=<table> [options]`

**Options:**

```text
--tableName=<table>
--window=<window>
--indexDate=<date_col>
--targetStartDate=<col>
--targetEndDate=<col>
--inObservation=<logical>
--nameStyle=<style>
```

### `addTableIntersectDate.R`

**Usage:** `addTableIntersectDate.R <name> --tableName=<table> [options]`

**Options:**

```text
--tableName=<table>
--window=<window>
--order=<order>
--indexDate=<date_col>
--targetDate=<col>
--inObservation=<logical>
--nameStyle=<style>
```

### `addTableIntersectDays.R`

**Usage:** `addTableIntersectDays.R <name> --tableName=<table> [options]`

**Options:**

```text
--tableName=<table>
--window=<window>
--order=<order>
--indexDate=<date_col>
--targetDate=<col>
--inObservation=<logical>
--nameStyle=<style>
```

### `addTableIntersectFlag.R`

**Usage:** `addTableIntersectFlag.R <name> --tableName=<table> [options]`

**Options:**

```text
--tableName=<table>
--window=<window>
--indexDate=<date_col>
--targetStartDate=<col>
--targetEndDate=<col>
--inObservation=<logical>
--nameStyle=<style>
```

### `cleanUpCohortTables.R`

**Usage:** `cleanUpCohortTables.R <name> ...`

**Options:** None (positional arguments only).

### `count-cohorts.R`

**Usage:** `count_cohorts.R <name> [--outputPath=<outputPath>]`

**Options:**

```text
--outputPath=<outputPath>
```

### `createDeathCohort.R`

**Usage:** `createDeathCohort.R <name> [options]`

**Options:**

```text
--subsetCohort=<table_name>
--subsetCohortId=<ids>
```

### `defineConceptCohortSet.R`

**Usage:** `defineConceptCohortSet.R <name> --conceptSet=<json> [--alloccurrences] [--end=<end>] [--requiredObservation=<days>]`

**Options:**

```text
--alloccurrences
--end=<end>
--requiredObservation=<days>
--conceptSet=<json>
```

### `drugExposureDiagnostics.R`

**Usage:** `drugExposureDiagnostics.R --ingredients=<ids> [options]`

**Options:**

```text
--ingredients=<ids>
--checks=<checks>
--outputPath=<path>
--databaseId=<id>
--sample=<n>
--minCellCount=<n>
--earliestStartDate=<date>
--byConcept
--subsetToConceptId=<ids>
--exposureTypeId=<id>
--tablePrefix=<prefix>
```

### `estimateCompetingEventSurvival.R`

**Usage:** `estimateCompetingEventSurvial.R [options]`

**Options:**

```text
--targetCohortTable=<table>
--outcomeCohortTable=<table>
--competingOutcomeCohortTable=<table>
--outputPath=<path>
--targetCohortId=<id>
--outcomeCohortId=<id>
--outcomeDateVariable=<variable>
--outcomeWashout=<days>
--competingOutcomeCohortId=<id>
--competingOutcomeDateVariable=<variable>
--competingOutcomeWashout=<days>
--censorOnCohortExit
--censorOnDate=<date>
--weight=<weight>
--followUpDays=<days>
--strata=<strata>
--eventGap=<gap>
--estimateGap=<gap>
--restrictedMeanFollowUp=<days>
--minimumSurvivalDays=<days>
```

### `estimateSingleEventSurvival.R`

**Usage:** `estimateSingleEventSurvival.R [options]`

**Options:**

```text
--targetCohortTable=<tableName>
--outcomeCohortTable=<tableName>
--outputPath=<path>
--targetCohortId=<cohortId>
--outcomeCohortId=<cohortId>
--outcomeDateVariable=<columnName>
--outcomeWashout=<days>
--censorOnCohortExit
--censorOnDate=<date>
--weight=<columnName>
--followUpDays=<days>
--strata=<columnNames>
--eventGap=<days>
--estimateGap=<days>
--restrictedMeanFollowUp=<days>
--minimumSurvivalDays=<days>
```

### `finaliseDrugUtilisationResults.R`

**Usage:** `finaliseDrugUtilisationResults.R <result1> [<result2> ...] [options]`

**Options:**

```text
--suppressCounts
--suppressGroup
--outputPath=<path>
```

### `generateIngredientCohortSet.R`

**Usage:** `generateIngredientCohortSet.R <name> [options]`

**Options:**

```text
--ingredient=<names>
--atc=<name>
--gapEra=<n>
--subsetCohort=<name>
--subsetCohortId=<ids>
--numberExposures=<logical>
--daysPrescribed=<logical>
--outputPath=<path>
```

### `incidencePrevalence.R`

**Usage:** `incidencePrevalence.R <denominatorCohortName> [options]`

**Options:**

```text
--denominatorCohortDateRange=<dates>
--denominatorAgeGroup=<groups>
--denominatorBothOff
--denominatorMale
--denominatorFemale
--denominatorDaysPriorObservation=<days>
--requirementInteractions
--outcomeCohortName=<cohortName>
--estimateIncidenceOutputPath=<outputPath>
--incidenceInterval=<interval>
--incidenceOutcomeWashout=<washout>
--incidenceRepeatedEvents
--estimatePointPrevalenceOutputPath=<outputPath>
--pointPrevalenceInterval=<interval>
--pointPrevalenceTimePoint=<timePoint>
--estimatePeriodPrevalenceOutputPath=<outputPath>
--periodPrevalenceInterval=<interval>
```

### `summariseCohort.R`

**Usage:** `summariseCohort.R <name> [options]`

**Options:**

```text
--outputPath=<outputPath>
--group=<group>
--includeOverallGroup=<logical>
--strata=<json>
--variables=<json>
--estimates=<json>
--counts=<logical>
--weights=<json>
--customEstimates=<json>
```

### `summariseDoseCoverage.R`

**Usage:** `summariseDoseCoverage.R <name> [options]`

**Options:**

```text
--ingredientConceptId=<ids>
--conceptSet=<json>
--estimates=<json>
--sampleSize=<n>
--outputPath=<path>
```

### `summariseDrugRestart.R`

**Usage:** `summariseDrugRestart.R <name> --switchCohortTable=<table> [options]`

**Options:**

```text
--switchCohortTable=<table>
--switchCohortId=<ids>
--strata=<json>
--followUpDays=<n>
--censorDate=<date_col>
--incident=<logical>
--outputPath=<path>
```

### `summariseDrugUtilisation.R`

**Usage:** `summariseDrugUtilisation.R <name> [options]`

**Options:**

```text
--ingredientConceptId=<ids>
--conceptSet=<json>
--strata=<json>
--estimates=<json>
--indexDate=<date_col>
--censorDate=<date_col>
--restrictIncident=<logical>
--gapEra=<n>
--numberExposures=<logical>
--numberEras=<logical>
--daysExposed=<logical>
--daysPrescribed=<logical>
--timeToExposure=<logical>
--initialQuantity=<logical>
--cumulativeQuantity=<logical>
--initialDailyDose=<logical>
--cumulativeDose=<logical>
--outputPath=<path>
```

### `summariseIndication.R`

**Usage:** `summariseIndication.R <name> --indicationCohortName=<table> [options]`

**Options:**

```text
--indicationCohortName=<table>
--indicationCohortId=<ids>
--window=<windows>
--unknownIndicationTable=<table>
--strata=<json>
--indexDate=<date_col>
--censorDate=<date_col>
--mutuallyExclusive=<logical>
--restrictIncident=<logical>
--outputPath=<path>
```

### `treatmentPatterns.R`

**Usage:** `treatmentPatterns.R --targetCohortTable=<table> --eventCohortTable=<table> [options]`

**Options:**

```text
--targetCohortTable=<table>
--eventCohortTable=<table>
--exitCohortTable=<table>
--combinedCohortTable=<table>
--outputPath=<path>
--archiveName=<name>
--analysisId=<id>
--description=<text>
--startAnchor=<anchor>
--windowStart=<days>
--endAnchor=<anchor>
--windowEnd=<days>
--splitEventCohorts=<names>
--splitTime=<days>
--minEraDuration=<days>
--filterTreatments=<method>
--eraCollapseSize=<days>
--combinationWindow=<days>
--minPostCombinationDuration=<days>
--overlapWithKeep
--maxPathLength=<n>
--concatTargets=<logical>
--minCellCount=<n>
--censorType=<type>
--ageWindow=<ages>
--nonePaths
```
