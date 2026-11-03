# 5STES – OMOP R Toolkit: TES Message Examples

## Overview

This document provides example Task Execution Service (TES) JSON messages for running analyses using the OMOP R Toolkit within the Five Safes TES framework.

Each section describes the purpose of an analysis and provides an example TES JSON message showing how the relevant R scripts are configured and executed inside a Five Safes TES (5STES) environment within a Trusted Research Environment (TRE).

The examples demonstrate how to define cohorts, execute analyses, export results, and clean up temporary cohort tables where required.

For a detailed explanation of the supported analysis types and their research applications, refer to [Analysis Types](./analysis-types.md).


## What This Document Covers

For each analysis, the documentation includes:

- **Analysis Overview:** What the analysis does and the research question it addresses.

- **TES JSON Message:** A complete example that can be adapted for execution.


## TES Message Structure

A TES message defines how the analysis is executed, including the container image, commands, inputs, outputs, and TRE configuration.

A single TES task can contain multiple executors to perform sequential steps such as cohort creation, analysis, and cleanup.

The examples use the OMOP R Toolkit container image: `ghcr.io/health-informatics-uon/omop-r-tools:edge`

Analysis results are generally written to `/outputs`, which is configured as a TES output directory for result collection.

---

## Example TES JSON Message

The following TES JSON messages are designed to be submitted through a running Five Safes TES (5STES) stack, configured with access to a Trusted Research Environment (TRE) containing an OMOP CDM database.

Before running the examples, ensure that the 5STES deployment is available, the TRE database connection is configured, and the OMOP R Toolkit container image is accessible.

**The examples use:**

- **Project:** DelphiDemo, an example project identifier.

- **TREs:** Nottingham TRE 01|Nottingham TRE 02, the target TREs configured in the example deployment.

- **Container Image:** ghcr.io/health-informatics-uon/omop-r-tools:edge.

- **Output Directory:** /outputs, where analysis results are written for collection by TES.

Update the project and TRE tags, cohort names, and analysis parameters to match your deployment and research requirements.

Each TES task executes its configured R scripts sequentially, allowing cohort creation, analysis, result export, and cleanup within a single task.


### IncidencePrevalence

This example demonstrates how to execute incidence and prevalence analyses using the OMOP R Toolkit through Five Safes TES.

The analysis uses a skin cancer cohort to calculate:

- **Incidence:** New cases occurring within a specified time period.

- **Point Prevalence:** The proportion of the eligible population with the condition at a specific point in time.

- **Period Prevalence:** The proportion of the eligible population with the condition during a specified period.

The analysis uses the IncidencePrevalence package and exports the results as CSV files.

```json

{
  "state": 0,
  "name": "Incidence and Prevalence - Skin Cancer",
  "description": "Calculate incidence, point prevalence and period prevalence for skin cancer",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Incidence and prevalence analysis results",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/defineConceptCohortSet.R",
        "skin_cancer_outcome_1",
        "--conceptSet={\"skin_cancer\":[139750]}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/incidencePrevalence.R",
        "skin_cancer_denominator_1",
        "--outcomeCohortName=skin_cancer_outcome_1",
        "--denominatorAgeGroup=[[0,150]]",
        "--denominatorDaysPriorObservation=365",
        "--estimateIncidenceOutputPath=outputs/incidence.csv",
        "--incidenceInterval=years",
        "--estimatePointPrevalenceOutputPath=outputs/point_prevalence.csv",
        "--pointPrevalenceInterval=years",
        "--pointPrevalenceTimePoint=start",
        "--estimatePeriodPrevalenceOutputPath=outputs/period_prevalence.csv",
        "--periodPrevalenceInterval=years"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "skin_cancer_outcome_1"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "skin_cancer_denominator_1"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}

```

---

### PatientProfiles

The `PatientProfiles` package supports patient-level characterisation and event-based analyses using OMOP CDM data.

It allows researchers to enrich patient cohorts with demographic characteristics, observation history, clinical event counts, event dates, time intervals, and binary indicators.

The toolkit supports several types of analysis, including cohort characteristics, cohort intersections, concept intersections, table intersections, and event-based analysis.

#### Supported Analyses

| Analysis Type | R Script | What It Does |
|---------------|----------|--------------|
| Cohort Characteristics | `addCharacteristics.R` | Adds patient demographic and observation characteristics, including age, sex, prior observation, future observation, and observation status. |
| Cohort Intersections | `addCohortIntersectCount.R` | Counts how many events from another cohort intersect with each patient's specified observation window. |
| Cohort Intersections | `addCohortIntersectDate.R` | Identifies the first or last matching cohort event date within a specified time window. |
| Cohort Intersections | `addCohortIntersectDays.R` | Calculates the number of days between the cohort index date and a matching cohort event. |
| Cohort Intersections | `addCohortIntersectFlag.R` | Adds a binary indicator showing whether a matching cohort event occurred within a specified time window. |
| Cohort Event Analysis | `addCohortEventDate.R` | Adds event occurrence information and the first or last matching cohort event date. |
| Cohort Event Analysis | `addCohortEventDays.R` | Adds event occurrence information and the number of days between the cohort index date and a matching event. |
| Concept Intersections | `addConceptIntersectCount.R` | Counts clinical events matching a specified OMOP concept set within a time window. |
| Concept Intersections | `addConceptIntersectDate.R` | Identifies the first or last date of a matching clinical concept event. |
| Concept Intersections | `addConceptIntersectDays.R` | Calculates the number of days between the cohort index date and a matching concept event. |
| Concept Intersections | `addConceptIntersectFlag.R` | Adds a binary indicator showing whether a clinical concept event occurred within a specified time window. |
| Concept Event Analysis | `addConceptEventDate.R` | Adds event occurrence information and the first or last date of a matching concept event. |
| Concept Event Analysis | `addConceptEventDays.R` | Adds event occurrence information and the number of days to a matching concept event. |
| Table Intersections | `addTableIntersectCount.R` | Counts matching records from an OMOP CDM table, such as `visit_occurrence` or `drug_exposure`. |
| Table Intersections | `addTableIntersectDate.R` | Identifies the first or last matching event date from an OMOP CDM table. |
| Table Intersections | `addTableIntersectDays.R` | Calculates the number of days between the cohort index date and an event recorded in an OMOP CDM table. |
| Table Intersections | `addTableIntersectFlag.R` | Adds a binary indicator showing whether an event exists in an OMOP CDM table within a specified time window. |
| Result Summarisation | `summariseCohort.R` | Calculates aggregate statistics such as counts, percentages, means, medians, and percentiles for selected cohort variables. |

#### Alternative Analyses

The scripts can be combined to answer different research questions depending on the selected cohorts, concepts, OMOP tables, and observation windows.

For example:

- **Cohort Characteristics:** Compare age distribution, sex distribution, and observation history within a patient cohort.
- **Cohort Intersections:** Count how many times a patient has a recorded condition, identify the first or last occurrence, or determine whether it occurred before or after another condition.
- **Concept Intersections:** Examine the frequency and timing of specific clinical concepts, such as diagnoses, procedures, or medications.
- **Table Intersections:** Calculate healthcare visit frequencies, identify previous drug exposures, or determine the time since a recorded clinical event.
- **Event Analysis:** Investigate whether an event occurred and calculate its date or time difference relative to the cohort index date.
- **Flag-Based Analysis:** Calculate the proportion of patients with a specified clinical event within a defined observation window.

#### TES Execution

A typical PatientProfiles TES workflow includes:

1. Create one or more patient cohorts using the appropriate cohort generation scripts.
2. Enrich the cohort using one or more PatientProfiles scripts.
3. Generate aggregate statistics using `summariseCohort.R`.
4. Export the results as CSV files.
5. Remove temporary cohort tables using `cleanUpCohortTables.R`.

Patient-level data remains within the Trusted Research Environment (TRE). The provided TES examples export aggregate summaries with small-cell suppression.

The following sections demonstrate five representative TES workflows:

1. **Cohort Characteristics** — Patient demographics and observation history.
2. **Cohort Intersections** — Counts of matching events across cohorts.
3. **Concept Intersections** — Counts of selected OMOP concept events.
4. **Table Intersections** — Counts of records from OMOP CDM tables.
5. **Intersection Flags** — Binary indicators for the presence or absence of clinical events.

The examples illustrate common analysis workflows. Other supported analyses can be configured using the corresponding scripts listed above.


#### 1. Cohort Characteristics

This example demonstrates how to perform cohort characterisation using the OMOP R Toolkit through Five Safes TES.

The analysis uses a skin cancer cohort to examine patient demographics and observation characteristics:

- **Age Distribution:** Calculates patient age and categorises patients into age groups (0–17, 18–64, and 65–150).
- **Sex Distribution:** Examines the distribution of patients by sex.
- **Prior Observation:** Calculates how long patients were observed in the database before the index date.
- **Future Observation:** Calculates the available observation time after the index date.
- **Observation Status:** Identifies whether patients were continuously under observation during the specified 30-day window.

The analysis uses the `PatientProfiles` package to enrich the cohort with patient-level characteristics and summarise the results into an aggregate CSV file.

```json
{
  "state": 0,
  "name": "PatientProfiles addCharacteristics",
  "description": "Exercise all addCharacteristics options through the useDemographics path",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Patient characteristics summary",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/defineConceptCohortSet.R",
        "pp_characteristics_test_01",
        "--conceptSet={\"skin_cancer\": [139750]}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/addCharacteristics.R",
        "pp_characteristics_test_01",
        "--indexDate=cohort_end_date",
        "--addAge",
        "--ageGroup=[[0,17],[18,64],[65,150]]",
        "--ageMissingMonth=6",
        "--ageMissingDay=15",
        "--ageImposeMonth",
        "--ageImposeDay",
        "--addSex",
        "--addPriorObservation",
        "--addFutureObservation",
        "--addInObservation",
        "--inObservationWindow=[0,30]",
        "--completeInterval",
        "--useDemographics"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/summariseCohort.R",
        "pp_characteristics_test_01",
        "--variables=[\"age\",\"sex\",\"prior_observation\",\"future_observation\",\"in_observation\"]",
        "--estimates=[\"count\",\"percentage\",\"median\",\"q25\",\"q75\"]",
        "--outputPath=/outputs/patient-characteristics.csv"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "pp_characteristics_test_01"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```


#### 2. Cohort Intersections

This example demonstrates how to identify and summarise overlapping records between two patient cohorts using the OMOP R Toolkit through Five Safes TES.

The analysis uses a skin cancer cohort and a headache cohort to investigate:

- **Cohort Intersections:** Counts headache cohort records intersecting with a skin cancer patient's observation window.
- **Historical Events:** Examines headache records within 365 days before the skin cancer cohort index date.
- **Aggregate Statistics:** Calculates the mean, median, and interquartile range of the intersection counts.

The example uses `addCohortIntersectCount.R`. The toolkit also supports cohort intersection dates, days between events, presence/absence flags, and first or last cohort event measurements through other PatientProfiles scripts.

The analysis creates both cohorts, adds the intersection counts, exports a summary CSV, and removes the generated cohort tables.

```json
{
  "state": 0,
  "name": "PatientProfiles - Cohort Intersection Count",
  "description": "Count headache cohort intersections in the year before skin cancer cohort entry",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Cohort intersection count summary",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/defineConceptCohortSet.R",
        "pp_cohort_count_skin_cancer_01",
        "--conceptSet={\"skin_cancer\":[139750]}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/defineConceptCohortSet.R",
        "pp_cohort_count_headache_01",
        "--conceptSet={\"headache\":[378253]}",
        "--alloccurrences",
        "--end=event_end_date"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/addCohortIntersectCount.R",
        "pp_cohort_count_skin_cancer_01",
        "--targetCohortTable=pp_cohort_count_headache_01",
        "--targetCohortId=1",
        "--window=-365,-1",
        "--nameStyle={cohort_name}_count_{window_name}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/summariseCohort.R",
        "pp_cohort_count_skin_cancer_01",
        "--variables=[\"headache_count_m365_to_m1\"]",
        "--estimates=[\"mean\",\"median\",\"q25\",\"q75\"]",
        "--outputPath=/outputs/cohort_intersection_count.csv"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "pp_cohort_count_skin_cancer_01",
        "pp_cohort_count_headache_01"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```

#### 3. Concept Intersections

This example demonstrates how to count matching clinical concept events within a patient cohort using the OMOP R Toolkit through Five Safes TES.

The analysis uses a skin cancer cohort and an OMOP concept set to investigate:

- **Concept Intersections:** Counts recorded clinical events matching the selected skin cancer concept.
- **Observation Window:** Examines matching concept events across the specified observation window.
- **Event Frequency:** Calculates aggregate statistics describing how frequently the concept occurs within the cohort.

The example uses `addConceptIntersectCount.R`. The toolkit also provides concept intersection dates, flags, and first or last concept event date/day measurements through separate scripts.

The analysis creates the cohort, adds concept intersection counts, exports aggregate statistics, and removes the cohort tables.

```json
{
  "state": 0,
  "name": "PatientProfiles - Concept Intersection Count",
  "description": "Count skin cancer concept occurrences within a patient cohort",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Concept intersection count summary",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/defineConceptCohortSet.R",
        "skin_cancer_concept_count_test",
        "--conceptSet={\"skin_cancer\":[139750]}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/addConceptIntersectCount.R",
        "skin_cancer_concept_count_test",
        "--conceptSet={\"skin_cancer\":[139750]}",
        "--window=[[-Inf,Inf]]",
        "--nameStyle={concept_name}_count_{window_name}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/summariseCohort.R",
        "skin_cancer_concept_count_test",
        "--variables=[\"skin_cancer_count_minf_to_inf\"]",
        "--estimates=[\"mean\",\"median\",\"q25\",\"q75\"]",
        "--outputPath=/outputs/concept_intersection_count.csv"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "skin_cancer_concept_count_test"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```

#### 4. Table Intersections

This example demonstrates how to analyse intersections between a patient cohort and records from an OMOP CDM table using Five Safes TES.

The analysis uses a skin cancer cohort and the `visit_occurrence` table to investigate:

- **Healthcare Visits:** Identifies visit records associated with patients in the skin cancer cohort.
- **Visit Frequency:** Counts visit records intersecting with the selected cohort observation window.
- **Aggregate Statistics:** Calculates the mean, median, and interquartile range of visit counts.

The example uses `addTableIntersectCount.R`. Other supported table intersection operations can calculate event dates, days between events, and presence/absence flags.

The analysis creates a skin cancer cohort, calculates visit occurrence intersections, exports aggregate results, and removes the cohort tables.

```json
{
  "state": 0,
  "name": "PatientProfiles - Table Intersection Count",
  "description": "Count visit occurrence records for patients in a skin cancer cohort",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Table intersection count summary",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/defineConceptCohortSet.R",
        "skin_cancer_table_count_test",
        "--conceptSet={\"skin_cancer\":[139750]}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/addTableIntersectCount.R",
        "skin_cancer_table_count_test",
        "--tableName=visit_occurrence",
        "--window=[-Inf,Inf]",
        "--nameStyle={table_name}_count_{window_name}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/summariseCohort.R",
        "skin_cancer_table_count_test",
        "--variables=[\"visit_occurrence_count_minf_to_inf\"]",
        "--estimates=[\"mean\",\"median\",\"q25\",\"q75\"]",
        "--outputPath=/outputs/table_intersection_count.csv"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "skin_cancer_table_count_test"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```

#### 5. Intersection Flags

This example demonstrates how to identify whether patients have a matching clinical event within a specified time window using the OMOP R Toolkit through Five Safes TES.

The analysis uses a skin cancer cohort and a headache concept to investigate:

- **Prior Clinical Events:** Identifies whether a headache event was recorded within 365 days before the skin cancer cohort index date.
- **Binary Indicators:** Adds a flag indicating the presence or absence of a matching event.
- **Aggregate Distribution:** Calculates counts and percentages for the generated flag.

The example uses `addConceptIntersectFlag.R`. Equivalent flag-based analyses can also be performed using `addCohortIntersectFlag.R` and `addTableIntersectFlag.R`.

The analysis creates the cohort, adds the clinical event flag, exports aggregate results, and removes the cohort tables.

```json
{
  "state": 0,
  "name": "PatientProfiles - Concept Intersection Flag",
  "description": "Identify headache events in the year before skin cancer cohort entry",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Concept intersection flag summary",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/defineConceptCohortSet.R",
        "skin_cancer_concept_flag_test",
        "--conceptSet={\"skin_cancer\":[139750]}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/addConceptIntersectFlag.R",
        "skin_cancer_concept_flag_test",
        "--conceptSet={\"headache\":[378253]}",
        "--window=[[-365,-1]]",
        "--nameStyle={concept_name}_flag_{window_name}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/summariseCohort.R",
        "skin_cancer_concept_flag_test",
        "--variables=[\"headache_flag_m365_to_m1\"]",
        "--estimates=[\"count\",\"percentage\"]",
        "--outputPath=/outputs/concept_intersection_flag.csv"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "skin_cancer_concept_flag_test"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```


---

### DrugExposureDiagnostics

This example demonstrates how to assess drug exposure data quality using the OMOP R Toolkit through Five Safes TES.

The analysis uses the `DrugExposureDiagnostics` package to examine drug exposure records for a selected ingredient (acetaminophen, concept ID `1125315`).

By default, the analysis performs three diagnostic checks:

- **Missing Values:** Identifies missing information in drug exposure records, such as quantity and days supplied.
- **Exposure Duration:** Examines the duration of recorded drug exposures to identify potential inconsistencies.
- **Quantity:** Analyses the recorded quantities of drug exposures.

The analysis uses `drugExposureDiagnostics.R` to execute the diagnostic checks, with results broken down by drug concept using `--byConcept` and a minimum cell count of 5 for disclosure control.

The results are exported as CSV files to `/outputs/drug-exposure-diagnostics-test`. The files generated depend on the selected diagnostic checks.

```json
{
  "state": 0,
  "name": "Test - Drug Exposure Diagnostics",
  "description": "Run DrugExposureDiagnostics checks for an ingredient",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Drug exposure diagnostic results",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/drugExposureDiagnostics.R",
        "--ingredients=1125315",
        "--outputPath=/outputs/drug-exposure-diagnostics-test",
        "--minCellCount=5",
        "--byConcept"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```

---

### DrugUtilisation

This section demonstrates how to execute drug utilisation analyses using the OMOP R Toolkit through Five Safes TES.

The `DrugUtilisation` package supports analyses of drug exposure records, including cohort generation, exposure duration, treatment quantities, indications, and subsequent drug use.

The following examples demonstrate five different workflows using acetaminophen and other selected drug concepts.

#### 1. Ingredient Cohort Generation

This example demonstrates how to generate a drug exposure cohort for acetaminophen and calculate the number of patients in the cohort.

The analysis:

- **Generates an ingredient cohort:** Identifies acetaminophen drug exposure records and groups exposure eras using a seven-day gap.
- **Includes exposure information:** Adds the number of exposures and days prescribed to the generated cohort.
- **Counts cohort members:** Produces a summary of the generated drug cohort.
- **Cleans up:** Removes the cohort tables after the analysis.

```json
{
  "state": 0,
  "name": "Test - DrugUtilisation ingredient cohort",
  "description": "Generate an acetaminophen cohort, count it, then clean up",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Ingredient cohort count",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/generateIngredientCohortSet.R",
        "ingredient_cohort_test_1",
        "--ingredient=acetaminophen",
        "--gapEra=7",
        "--numberExposures=TRUE",
        "--daysPrescribed=TRUE"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/count-cohorts.R",
        "ingredient_cohort_test_1",
        "--outputPath=/outputs/ingredient_cohort_count.csv"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "ingredient_cohort_test_1"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```

#### 2. Drug Utilisation Summary

This example demonstrates how to summarise drug utilisation for patients with recorded acetaminophen exposure.

The analysis uses the `DrugUtilisation` package to calculate:

- **Drug Exposure:** Number of exposures, exposure eras, and days exposed or prescribed.
- **Treatment Duration:** Time to exposure and initial exposure duration.
- **Quantity and Dose:** Recorded quantities and dose-related measurements where data is available.

The analysis generates an acetaminophen cohort, computes aggregate drug utilisation statistics, and exports the results as a CSV file.

```json
{
  "state": 0,
  "name": "Test - DrugUtilisation summary",
  "description": "Generate an acetaminophen cohort, summarise drug utilisation, then clean up",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Drug utilisation summary",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/generateIngredientCohortSet.R",
        "ingredient_du_test_2",
        "--ingredient=acetaminophen",
        "--gapEra=7"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/summariseDrugUtilisation.R",
        "ingredient_du_test_2",
        "--ingredientConceptId=1125315",
        "--gapEra=7",
        "--outputPath=/outputs/drug_utilisation.csv"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "ingredient_du_test_2"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```

#### 3. Adding Drug Utilisation Metrics

This example demonstrates how to enrich an existing drug cohort with drug utilisation measurements and calculate aggregate statistics for selected variables.

The analysis:

- **Generates a drug cohort:** Creates an acetaminophen cohort from OMOP drug exposure records.
- **Adds utilisation metrics:** Enriches the cohort with measurements such as exposure counts, exposure duration, days prescribed, and quantities.
- **Summarises a selected metric:** Calculates the mean, median, and interquartile range (25th and 75th percentiles) for days exposed.

The results are exported as an aggregate CSV file.

```json
{
  "state": 0,
  "name": "Test - DrugUtilisation add metrics",
  "description": "Generate an acetaminophen cohort, add drug utilisation metrics, summarise one metric, then clean up",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Drug utilisation metric summary",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/generateIngredientCohortSet.R",
        "du_add_metrics_test_1",
        "--ingredient=acetaminophen",
        "--gapEra=7"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/addDrugUtilisation.R",
        "du_add_metrics_test_1",
        "--ingredientConceptId=1125315",
        "--gapEra=7",
        "--nameStyle={value}_{concept_name}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/summariseCohort.R",
        "du_add_metrics_test_1",
        "--variables=[\"days_exposed_ingredient_1125315_descendants\"]",
        "--estimates=[\"mean\",\"median\",\"q25\",\"q75\"]",
        "--outputPath=/outputs/drug_utilisation_metrics.csv"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "du_add_metrics_test_1"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```

#### 4. Drug Indication Analysis

This example demonstrates how to investigate the relationship between drug exposure and a selected clinical condition using the OMOP R Toolkit through Five Safes TES.

The analysis uses acetaminophen as the drug of interest and headache as the selected condition.

The analysis:

- **Defines the drug cohort:** Generates a cohort of patients with acetaminophen exposure.
- **Defines the indication cohort:** Creates a headache cohort using OMOP concept ID `378253`.
- **Adds indication information:** Identifies headache cohort records occurring within 30 days before or on the drug exposure index date.
- **Summarises indications:** Calculates aggregate counts and percentages of the recorded indication.

The analysis exports two CSV files containing the cohort characteristic summary and indication analysis results.

A recorded headache event within the selected window indicates a temporal association, not necessarily the confirmed reason for prescribing acetaminophen.

```json
{
  "state": 0,
  "name": "Test - DrugUtilisation indication",
  "description": "Generate drug and indication cohorts, add and summarise indication, then clean up",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Indication summaries",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/generateIngredientCohortSet.R",
        "du_indication_drug_test_1",
        "--ingredient=acetaminophen",
        "--gapEra=7"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/defineConceptCohortSet.R",
        "du_indication_condition_test_1",
        "--conceptSet={\"headache\": [378253]}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/addIndication.R",
        "du_indication_drug_test_1",
        "--indicationCohortName=du_indication_condition_test_1",
        "--indicationCohortId=1",
        "--window=[-30,0]",
        "--mutuallyExclusive=FALSE"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/summariseCohort.R",
        "du_indication_drug_test_1",
        "--variables=[\"indication_m30_to_0_headache\"]",
        "--estimates=[\"count\",\"percentage\"]",
        "--outputPath=/outputs/indication_column_check.csv"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/summariseIndication.R",
        "du_indication_drug_test_1",
        "--indicationCohortName=du_indication_condition_test_1",
        "--indicationCohortId=1",
        "--window=[-30,0]",
        "--mutuallyExclusive=FALSE",
        "--outputPath=/outputs/indication_summary.csv"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "du_indication_drug_test_1",
        "du_indication_condition_test_1"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```

#### 5. Drug Restart Analysis

This example demonstrates how to analyse subsequent drug exposure events following an index drug exposure using the OMOP R Toolkit through Five Safes TES.

The analysis uses acetaminophen as the index drug and metformin as the comparison drug cohort.

The analysis:

- **Generates the index cohort:** Creates an acetaminophen cohort.
- **Generates the comparison cohort:** Creates a metformin drug exposure cohort.
- **Analyses subsequent drug use:** Examines drug restart or switch-related events using the configured comparison cohort and a 365-day follow-up period.

The results are exported as an aggregate CSV file.

This example demonstrates the toolkit's restart-analysis workflow. Acetaminophen and metformin are used as test inputs and should not be interpreted as clinically interchangeable treatments.

```json
{
  "state": 0,
  "name": "Test - DrugUtilisation drug restart",
  "description": "Generate index and switch drug cohorts, summarise restarts, then clean up",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Drug restart summary",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/generateIngredientCohortSet.R",
        "du_restart_index_test_1",
        "--ingredient=acetaminophen",
        "--gapEra=7"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/generateIngredientCohortSet.R",
        "du_restart_switch_test_1",
        "--ingredient=metformin",
        "--gapEra=7"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/summariseDrugRestart.R",
        "du_restart_index_test_1",
        "--switchCohortTable=du_restart_switch_test_1",
        "--followUpDays=365",
        "--outputPath=/outputs/drug_restart.csv"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "du_restart_index_test_1",
        "du_restart_switch_test_1"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```

---

### TreatmentPatterns

This example demonstrates how to analyse treatment pathways using the OMOP R Toolkit through Five Safes TES.

The analysis uses a skin cancer patient cohort and examines recorded exposures to acetaminophen and amoxicillin.

The analysis uses the `TreatmentPatterns` package to investigate:

- **Treatment Sequences:** Identifies the order in which treatments are recorded during patient follow-up.
- **Treatment Switching:** Examines how patients move between different treatments over time.
- **Combination Therapy:** Identifies periods where treatment exposures overlap.
- **Treatment Pathways:** Summarises common treatment sequences, with a maximum of five pathway steps.

The toolkit supports different configurations of treatment pathway analysis, including first treatments, treatment changes, all treatment events, and optional exit cohorts. These are configured through the same `treatmentPatterns.R` script.

This example uses the default `First` treatment-filtering mode, a minimum treatment-era duration of seven days, a seven-day combination window, and a minimum cell count of five for disclosure control.

The analysis creates separate target and treatment-event cohorts, combines them for pathway computation, and exports aggregate results as CSV files. Temporary cohort tables are removed after execution.

```json id="o85hfg"
{
  "state": 0,
  "name": "Test V3 - TreatmentPatterns",
  "description": "Run treatment pathway analysis for skin cancer patients with acetaminophen and amoxicillin exposures",
  "inputs": null,
  "outputs": [
    {
      "name": "Query Results",
      "description": "Treatment pathway results",
      "url": "s3://",
      "path": "/outputs",
      "type": "DIRECTORY"
    }
  ],
  "resources": null,
  "executors": [
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/defineConceptCohortSet.R",
        "tp_target_20261014_test3",
        "--conceptSet={\"skin_cancer\":[139750]}"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/generateIngredientCohortSet.R",
        "tp_events_20261014_test3",
        "--ingredient=acetaminophen,amoxicillin",
        "--gapEra=1"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/treatmentPatterns.R",
        "--targetCohortTable=tp_target_20261014_test3",
        "--eventCohortTable=tp_events_20261014_test3",
        "--combinedCohortTable=tp_combined_20261014_test3",
        "--minEraDuration=7",
        "--combinationWindow=7",
        "--minPostCombinationDuration=7",
        "--maxPathLength=5",
        "--minCellCount=5",
        "--outputPath=/outputs/treatment_patterns_test3"
      ],
      "workdir": null,
      "env": {}
    },
    {
      "image": "ghcr.io/health-informatics-uon/omop-r-tools:edge",
      "command": [
        "Rscript",
        "inst/scripts/cleanUpCohortTables.R",
        "tp_target_20261014_test3",
        "tp_events_20261014_test3"
      ],
      "workdir": null,
      "env": {}
    }
  ],
  "volumes": null,
  "tags": {
    "Project": "DelphiDemo",
    "tres": "Nottingham TRE 01|Nottingham TRE 02"
  }
}
```
