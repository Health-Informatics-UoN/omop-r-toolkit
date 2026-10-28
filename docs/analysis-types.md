# 5STES - Darwin & OMOP R Toolkit

The **OMOP R Toolkit** provides R scripts that wrap selected Darwin-EU packages for analysing data stored in the **OMOP Common Data Model (CDM)**.

It is designed to run federated analyses inside **Trusted Research Environments (TREs)** using the **Five Safes TES** framework. This document explains the types of analysis supported by the toolkit's scripts. For command execution and complete TES messages, see `analysis-tes-json.md`.

The analyses run on **cohorts**: groups of people who meet defined criteria, such as having a diagnosis or a drug exposure. Cohorts are created first, for example with `defineConceptCohortSet.R` or `createDeathCohort.R`, and the analyses below are then run on them.

## Incidence and Prevalence

**Incidence** and **prevalence** are fundamental epidemiological measures. The toolkit exposes the Darwin-EU `IncidencePrevalence` package through `inst/scripts/incidencePrevalence.R`.

The wrapper uses an existing **outcome cohort** and generates the **denominator cohort** (the eligible study population) according to the chosen requirements, such as age, sex, observation history, and date range.

### Incidence

Incidence answers: **"How frequently do new cases occur in the population over a specified period?"**

- Measures the occurrence of new events, such as disease diagnoses or new prescriptions, among the population at risk.
- Results can be estimated over intervals such as years.
- An **outcome washout** sets how many days must pass after an outcome before the same person is counted as at risk again.
- **Repeated events** can optionally be included, so one person can contribute more than one new case.

### Prevalence

Prevalence answers: **"How common is a condition in the eligible population?"**

**Point prevalence** measures the proportion of eligible people with a condition at a specific point in time. For example: *What proportion of the study population had diabetes at the start of 2010?*

**Period prevalence** measures the proportion of eligible people with a condition during an interval. For example: *What proportion of the eligible study population had diabetes at any point during 2010?* The denominator is the eligible population observed during the interval.

The denominator cohorts can be restricted by date range, age group, sex, and prior observation, and estimates can be produced for intervals such as years. Results are exported in the OMOP summarised-result format.

### Options

| Option | What it controls |
| --- | --- |
| `--outcomeCohortName` | The existing outcome cohort table. |
| `--denominatorCohortDateRange` | Earliest cohort start date and latest cohort end date for the eligible population. |
| `--denominatorAgeGroup` | Age groups; one denominator cohort is created per group. |
| `--denominatorMale`, `--denominatorFemale`, `--denominatorBothOff` | Which sex-specific denominator cohorts are created. A cohort of both sexes is created unless `--denominatorBothOff` is set. |
| `--denominatorDaysPriorObservation` | Days of prior observation required before a person starts contributing time. |
| `--requirementInteractions` | Whether cohorts are created for every combination of age group, sex, and prior observation, or only the first value of the other factors is used. |
| `--estimateIncidenceOutputPath`, `--estimatePointPrevalenceOutputPath`, `--estimatePeriodPrevalenceOutputPath` | Output file for each estimate. At least one must be given. |
| `--incidenceInterval` | Time interval for incidence, such as years. |
| `--incidenceOutcomeWashout` | Days that must pass after an outcome before a person is at risk again. |
| `--incidenceRepeatedEvents` | Whether repeated events are counted. |
| `--pointPrevalenceInterval`, `--pointPrevalenceTimePoint` | Interval for point prevalence, and where in each interval it is measured (for example, the start). |
| `--periodPrevalenceInterval` | Time interval for period prevalence. |

The upstream `completeDatabaseIntervals` and `fullContribution` options for period prevalence are not available as options in this toolkit.

## PatientProfiles

`PatientProfiles` is a Darwin-EU package for enriching OMOP CDM cohorts with patient characteristics and identifying overlaps between cohorts, concepts, and clinical tables.

In OMOP CDM, clinical-event tables such as `condition_occurrence` and `drug_exposure` describe recorded events. To analyse a study population, researchers may also need to know:

- How old was the person at the event or index date?
- What was their recorded sex?
- How long had they been observed in the database before the event?
- Did they experience another condition or treatment within a specified window?

The toolkit's PatientProfiles scripts add these features to cohort tables. They **do not automatically export aggregate results**; use `summariseCohort.R` after feature generation when a summary is required.

### Cohort Characterisation

For example, a researcher may want to know:

- What is the age and sex distribution of a skin cancer cohort?
- How many patients have at least 365 days of prior observation?
- How many patients were in observation on the index date?

`addCharacteristics.R` adds these features to the cohort. Its options:

| Option | What it controls |
| --- | --- |
| `--indexDate` | The date column used as the reference point (default: `cohort_start_date`). |
| `--addAge`, `--ageGroup` | Add age at the index date, and optionally group it into age bands. |
| `--ageMissingMonth`, `--ageMissingDay`, `--ageImposeMonth`, `--ageImposeDay` | How missing birth month or day is handled when calculating age. |
| `--addSex` | Add recorded sex. |
| `--addPriorObservation`, `--addFutureObservation` | Add days observed before and after the index date. |
| `--addInObservation`, `--inObservationWindow`, `--completeInterval` | Add a flag for being in observation within a window, optionally requiring the whole window to be observed. |
| `--useDemographics` | Add the selected features in one combined step, which is more efficient. |

### Cohort Intersections

Suppose a researcher defines:

- **Cohort A:** Skin cancer patients (index cohort).
- **Cohort B:** Diabetes patients (comorbidity cohort).

They want to know: **"Which skin cancer patients also had diabetes in the year before their cancer diagnosis?"**

| Script / function family | What it adds | Example use |
| --- | --- | --- |
| `addCohortIntersectCount` | Number of intersecting cohort records | Number of diabetes episodes in the year before diagnosis. |
| `addCohortIntersectFlag` | Indicator of cohort overlap | Whether a patient had a previous diabetes record. |
| `addCohortIntersectDate` | Date of an intersecting event | Date of the first relevant comorbidity event. |
| `addCohortIntersectDays` | Time relative to an intersecting event | Days between diagnosis and a comorbidity event. |
| `addTableIntersectCount` / `Flag` / `Date` / `Days` | Intersection with an OMOP clinical table | Previous drug exposure or another clinical record. |
| `addConceptIntersectCount` / `Flag` / `Date` / `Days` | Intersection with selected OMOP concepts | Events matching a concept set. |
| `addCohortEventDate` / `Days` | Timing of events in another cohort | First event date or days relative to index. |
| `addConceptEventDate` / `Days` | Timing of events matching a concept set | First matching concept-event date or days. |

**Note:** These scripts add cohort-level features. To obtain aggregate counts, percentages, or distributions suitable for export, use `summariseCohort.R` on the enriched cohort.

The intersection and event scripts share most of their options:

| Option | What it controls |
| --- | --- |
| `--targetCohortTable`, `--targetCohortId` | The cohort to intersect with, and optionally a single cohort within it (cohort scripts). |
| `--tableName` | The OMOP table to intersect with (table scripts). |
| `--conceptSet` | The concepts to look for, as a named list of concept IDs (concept scripts). |
| `--window` | Time window relative to the index date, such as `[-365,0]` for the year before. The default is any time. |
| `--indexDate` | The date column used as the reference point (default: `cohort_start_date`). |
| `--targetStartDate`, `--targetEndDate`, `--targetDate` | The date columns in the target cohort or table that define the event. |
| `--order` | Whether the first or last matching event is used (event scripts). |
| `--censorDate` | A date column after which events are ignored (event scripts). |
| `--inObservation` | Whether only records within observation are counted (table scripts). |
| `--nameStyle` | How the added columns are named. |

`summariseCohort.R` turns the enriched cohort into summary results:

| Option | What it controls |
| --- | --- |
| `--variables` | The columns to summarise. |
| `--estimates` | The statistics to calculate (default: count and percentage). |
| `--strata` | Columns to break the results down by. |
| `--group` | An optional grouping column. |

### Workflow of PatientProfiles

```text
Step 1: Define a target cohort
   ↓
Step 2: Add age, sex, or observation characteristics
   ↓
Step 3: Add cohort, concept, or table intersections if required
   ↓
Step 4: Summarise the enriched cohort using summariseCohort.R
   ↓
Step 5: Export aggregate cohort characteristics
```

## Drug Exposure Diagnostics

The toolkit provides `inst/scripts/drugExposureDiagnostics.R`, which calls `DrugExposureDiagnostics::executeChecks()` to investigate the quality and distribution of drug-exposure records in an OMOP CDM database.

Unlike incidence or prevalence estimation, this is primarily a **data-quality assessment**, often performed before defining a final drug study cohort.

| Option | What it controls |
| --- | --- |
| `--ingredients` | One or more ingredient concept IDs (for example, acetaminophen: `1125315`). |
| `--checks` | Which diagnostics to run. |
| `--sample` | Number of records sampled; the default is 10,000, and `0` uses all records. |
| `--minCellCount` | Minimum cell count for disclosure control (default: 5). |
| `--byConcept` | Break results down by drug concept. |
| `--subsetToConceptId` | Concept IDs to include or exclude. |
| `--exposureTypeId` | Restrict to one drug exposure type. |
| `--earliestStartDate` | Earliest drug exposure start date to include. |

**By default, the toolkit runs three checks:** `missing`, `exposureDuration`, and `quantity`.

| Default check | What it investigates |
| --- | --- |
| `missing` | Missing values in relevant drug-exposure fields, such as quantities or days supplied. |
| `exposureDuration` | Distribution and plausibility of recorded drug-exposure durations. |
| `quantity` | Recorded drug quantities and their distribution. |

Further checks, such as drug types, routes, and dose, can also be selected. The results depend on the checks chosen, so the set of output tables varies.

### Workflow of Drug Exposure Diagnostics

```text
Step 1: Select a drug ingredient and the required checks
   ↓
Step 2: Run drugExposureDiagnostics.R
   ↓
Step 3: Review the generated diagnostic CSVs
        - Are important values missing?
        - Are exposure durations plausible?
        - Are recorded quantities usable for the study?
   ↓
Step 4: Use the findings to inform drug cohort selection
   ↓
Step 5: Run the relevant downstream analysis
```

## DrugUtilisation

`DrugUtilisation` is a Darwin-EU package for conducting **drug utilisation studies (DUS)** using OMOP CDM data. The toolkit exposes selected package functions through scripts for cohort generation, feature creation, and aggregate analysis.

These analyses can help answer questions such as:

- **How was a drug used?** Exposure duration, number of exposures, quantities, and dose-related metrics.
- **What indications were recorded?** Conditions associated with a drug exposure.
- **Did a patient restart or switch treatment?** Events following discontinuation, using the supported restart analysis.
- **Can dose-related measures be calculated?** Availability of data needed for dose calculations.

### Supported toolkit scripts

| Script | What it does |
| --- | --- |
| `generateIngredientCohortSet.R` | Generates drug cohorts from ingredient names or an ATC name. An **era gap** merges exposures separated by a short gap into one continuous period of use. |
| `addDrugUtilisation.R` | Adds drug-utilisation measures to an existing cohort. |
| `addIndication.R` | Adds indication-related variables using an indication cohort. |
| `summariseIndication.R` | Summarises recorded indications associated with drug cohorts. |
| `summariseDrugUtilisation.R` | Summarises exposure counts, eras, duration, quantity, and dose-related measures. |
| `summariseDoseCoverage.R` | Summarises availability or coverage of dose information. |
| `summariseDrugRestart.R` | Summarises drug restarts and switching to specified drug cohorts after discontinuation. |
| `finaliseDrugUtilisationResults.R` | Combines result files into one, optionally suppressing counts or grouping columns. |

### Options

| Option | Used by | What it controls |
| --- | --- | --- |
| `--ingredient` or `--atc` | Cohort generation | The ingredient names or ATC name that define the drug cohort. |
| `--subsetCohort`, `--subsetCohortId` | Cohort generation | Restrict the drug cohort to people in another cohort. |
| `--ingredientConceptId` | Utilisation, dose coverage | The drug, given as ingredient concept IDs. |
| `--conceptSet` | Utilisation | A custom concept set, as an alternative to ingredient IDs. |
| `--gapEra` | Cohort generation, utilisation | Days between exposures that are merged into one era. |
| `--indexDate` | Utilisation, indication | The date column used as the reference point. |
| `--censorDate` | Utilisation, indication, restart | A date column after which follow-up stops. |
| `--restrictIncident` | Utilisation, indication | Count only incident (new) exposures or indication events. |
| `--numberExposures`, `--numberEras`, `--daysExposed`, `--daysPrescribed`, `--timeToExposure`, `--initialExposureDuration`, `--initialQuantity`, `--cumulativeQuantity`, `--initialDailyDose`, `--cumulativeDose` | Utilisation | Switch individual measures on or off. |
| `--strata`, `--estimates` | Summaries | Columns to break results down by, and the statistics calculated (for example, mean and standard deviation). |
| `--indicationCohortName`, `--indicationCohortId` | Indication | The cohort that defines the indications. |
| `--window` | Indication | Time window around the index date in which indications are sought. |
| `--unknownIndicationTable` | Indication | A table used to flag people with a recorded condition that is not one of the listed indications. |
| `--mutuallyExclusive` | Indication | Whether each person is given only one indication label. |
| `--sampleSize` | Dose coverage | Number of records sampled. |
| `--switchCohortTable`, `--switchCohortId` | Restart | The cohort of drugs that count as a switch. |
| `--followUpDays` | Restart | Follow-up window after discontinuation (default: 365). |
| `--incident`, `--restrictToFirstDiscontinuation` | Restart | Restrict to incident restarts, or to each person's first discontinuation. |
| `--suppressCounts`, `--suppressGroup` | Finalising results | Suppress counts, or grouping columns, in the combined output. |

### Workflow of DrugUtilisation

```text
Step 1: Generate an ingredient- or ATC-based drug cohort
   ↓
Step 2: Run the required toolkit analysis
        - Drug utilisation summary
        - Indication analysis (define an indication cohort if required)
        - Dose coverage
        - Drug restart / switch summary (requires a switch cohort)
   ↓
Step 3: Export the corresponding aggregate results
   ↓
Step 4: Optionally combine results using finaliseDrugUtilisationResults.R
   ↓
Step 5: Review the output for the TRE's disclosure requirements
```

## Treatment Patterns

`TreatmentPatterns` is a Darwin-EU package for **analysing the sequence of treatments patients receive over time**.

Unlike DrugUtilisation, which focuses on **how individual drugs are used**, Treatment Patterns focuses on **how patients move between treatments**, including treatment changes, overlapping therapies, and combinations.

It answers questions such as:

- **What treatment did patients receive first?**
- **Which treatment did they receive next?**
- **How frequently did patients switch treatments?**
- **Which treatments were used together?**
- **What were the most common treatment pathways?**

For example, for a cohort of patients with sinusitis:

- **Target cohort:** Patients diagnosed with sinusitis.
- **Event cohorts:** Amoxicillin and acetaminophen treatment records.
- **Exit cohort (optional):** An event such as death that terminates follow-up.

A possible pathway might be **Amoxicillin → Acetaminophen → Combination therapy**. This represents a sequence of recorded exposures, not necessarily the clinician's reason for a change.

### Treatment Pathway Concepts

| Concept / Parameter | What it means | Example value |
| --- | --- | --- |
| Target cohort | Population or condition being studied | Sinusitis patients |
| Event cohorts | Treatment events used to construct pathways | Amoxicillin, acetaminophen |
| Exit cohort | Optional event marking the end of a pathway | Death |
| `filterTreatments` | Selects first events, changes, or all events | `First`, `Changes`, `All` |
| `minEraDuration` | Minimum treatment-era duration to retain | 7 days |
| `eraCollapseSize` | Gap allowing repeated exposure eras to be merged | 30 days |
| `combinationWindow` | Required overlap for treatments to count as a combination | 7 days |
| `minPostCombinationDuration` | Minimum remaining treatment duration after separating combinations | 7 days |
| `maxPathLength` | Maximum number of treatment steps in a pathway | 5 steps |
| `splitEventCohorts` / `splitTime` | Splits selected events into acute and later therapy phases | Acute vs therapy |
| `minCellCount` / `censorType` | Controls disclosure of small counts in exported summaries | Minimum cell count of 5 |

Each parameter above is set with an option of the same name, for example `--minEraDuration`. The defaults are 30 days for the era and combination settings, 5 for the maximum path length and minimum cell count, and `First` for `filterTreatments`.

Other options:

| Option | What it controls |
| --- | --- |
| `--targetCohortTable`, `--eventCohortTable`, `--exitCohortTable` | The cohort tables holding the target, event, and optional exit cohorts. |
| `--startAnchor`, `--windowStart`, `--endAnchor`, `--windowEnd` | The observation window around the target cohort dates in which events are considered. |
| `--overlapWithKeep` | Keep both records for a non-significant overlap, instead of truncating the first. |
| `--concatTargets` | Whether several entries in the target cohort for one person are joined together. |
| `--ageWindow` | The age group width, or the age breaks, used in the exported results. |
| `--nonePaths` | Include pathways where no events occurred. |

### Treatment Sequences and Switching

A pathway shows **the order of recorded treatment events**.

```text
Patient A: Treatment A → Treatment B
Patient B: Treatment A → Treatment A + Treatment B
Patient C: Treatment B → Treatment C
```

- **Switching:** A subsequent treatment replaces an earlier treatment.
- **Combination:** Treatment eras overlap for at least the configured combination window.
- **Continuation:** Repeated treatment eras may be merged based on the configured era gap.

The resulting aggregate data can be used to compare the frequencies of different treatment sequences.

### Workflow of Treatment Patterns

```text
Step 1: Define the target cohort (disease or study population)
   ↓
Step 2: Define event cohorts (treatments, including relevant occurrences)
   ↓
Step 3: Optionally define an exit cohort
   ↓
Step 4: Configure observation windows, treatment eras, and combinations
   ↓
Step 5: Run treatmentPatterns.R to compute treatment pathways
   ↓
Step 6: Export aggregate results with low-cell disclosure control
   ↓
Step 7: Clean up intermediate cohort tables
   ↓
Step 8: Visualise or compare aggregate pathways outside the TRE
```

## CohortSurvival

`CohortSurvival` is a Darwin-EU package for **time-to-event analysis** in OMOP CDM populations. It can be used to study when an outcome occurs after entry into a target cohort, accounting for follow-up and censoring.

The toolkit includes wrappers for three related operations:

| Script | What it does | Output |
| --- | --- | --- |
| `estimateSingleEventSurvival.R` | Estimates survival or event occurrence over follow-up for an outcome of interest. | Aggregate survival results exported to CSV. |
| `estimateCompetingEventSurvival.R` | Estimates outcomes when a competing event can prevent the event of interest. | Aggregate competing-event results exported to CSV. |
| `addCohortSurvival.R` | Adds follow-up time and event-status variables to a cohort. | Enriched cohort table in the database; not an aggregate export by itself. |

### Single-event survival

Answers: **"How does the probability of remaining free from a specified outcome change over time?"**

For example, a study might estimate the proportion of patients who have not experienced hospital readmission at different points within a year of cohort entry.

Follow-up can be limited to a maximum length, people with a prior outcome can be excluded using a washout, and follow-up can be **censored** (stopped) when a person leaves the target cohort.

### Competing-event survival

Answers: **"How does the risk of an outcome change when another event can prevent it from occurring?"**

For example, death may be treated as a competing event when studying another clinical outcome. The toolkit includes `estimateCompetingEventSurvival.R`, which takes target, outcome, and competing-outcome cohorts.

### Adding survival variables to a cohort

The `addCohortSurvival.R` wrapper adds follow-up time and event status to a cohort for further analysis. Because it creates cohort-level data rather than an aggregate summary, researchers must use an appropriate downstream analysis before exporting results from a TRE.

### Options

| Option | What it controls |
| --- | --- |
| `--targetCohortTable`, `--targetCohortId` | The cohort whose members are followed, and optionally which cohorts in it are used. |
| `--outcomeCohortTable`, `--outcomeCohortId` | The cohort holding the outcome of interest. |
| `--competingOutcomeCohortTable`, `--competingOutcomeCohortId` | The cohort holding the competing event (competing-event script). |
| `--outcomeDateVariable`, `--competingOutcomeDateVariable` | The date column that gives the event date (default: `cohort_start_date`). |
| `--outcomeWashout`, `--competingOutcomeWashout` | Days before cohort entry in which a prior outcome excludes the person; the default excludes anyone with any prior outcome. |
| `--followUpDays` | Maximum follow-up; follow-up is censored at this point (default: no limit). |
| `--censorOnCohortExit`, `--censorOnDate` | Stop follow-up when the person leaves the target cohort, or on a given date. |
| `--weight` | A column of weights used in the estimation. |
| `--strata` | Target cohort columns to break results down by. |
| `--eventGap`, `--estimateGap` | Days between the time points at which events (default: 30) and estimates (default: 1) are reported. |
| `--restrictedMeanFollowUp` | Follow-up length used for restricted mean survival. |
| `--minimumSurvivalDays` | Minimum number of days required for a cohort to contribute to the analysis. |
| `--name` | Name of the new table (cohort-survival script). |

### Workflow of CohortSurvival

```text
Step 1: Define the target cohort
   ↓
Step 2: Define the outcome cohort
   ↓
Step 3: Define a competing-outcome cohort if required
   ↓
Step 4: Choose follow-up, washout, and censoring settings
   ↓
Step 5: Run the relevant CohortSurvival wrapper
   ↓
Step 6: Export and review aggregate survival results
```