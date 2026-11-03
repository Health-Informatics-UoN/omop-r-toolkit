# 5STES - Darwin & OMOP R Toolkit

The **OMOP R Toolkit** provides R scripts that wrap selected Darwin-EU packages for analysing data stored in the **OMOP Common Data Model (CDM)**.

It is designed to run federated analyses inside **Trusted Research Environments (TREs)** using the **Five Safes TES** framework. This document explains the supported analysis types, their research applications, and example workflows. For implementation-specific guidance, refer to the [R Scripts and CLI Reference](./analysis-r-script.md) and [TES Message Examples](./analysis-tes-json.md).

## Darwin-EU Documentation and Vignettes

The analyses documented here are based on R packages developed and maintained by the Darwin-EU community.

This document provides an accessible overview of the supported analyses, their research applications, and practical examples. For more detailed explanations of the underlying methods, statistical considerations, and R package functionality, refer to the official Darwin-EU documentation and vignettes below.

| Analysis | Description | Documentation |
|---|---|---|
| **IncidencePrevalence** | Estimate incidence rates, point prevalence, and period prevalence for selected clinical outcomes. | [Incidence](https://darwin-eu.github.io/IncidencePrevalence/articles/a05_Calculating_incidence.html) / [Prevalence](https://darwin-eu.github.io/IncidencePrevalence/articles/a04_Calculating_prevalence.html) |
| **PatientProfiles** | Characterise patient cohorts using demographics, observation history, and intersections with other cohorts, clinical concepts, and OMOP CDM tables. | [PatientProfiles Documentation](https://darwin-eu.github.io/PatientProfiles/) |
| **DrugExposureDiagnostics** | Assess the quality and completeness of drug exposure records, including missing values, exposure duration, and recorded quantities. | [DrugExposureDiagnostics Documentation](https://darwin-eu.github.io/DrugExposureDiagnostics/) |
| **DrugUtilisation** | Analyse drug exposure, treatment duration, indications, quantities, doses, and subsequent drug use. | [DrugUtilisation Vignette](https://darwin-eu.github.io/DrugUtilisation/articles/drug_utilisation.html) |
| **TreatmentPatterns** | Analyse treatment sequences, switching, overlapping therapies, and treatment combinations. | [Computing Treatment Pathways](https://darwin-eu.github.io/TreatmentPatterns/articles/a010_Computing_Pathways.html) |
| **CohortSurvival** | Perform time-to-event analyses, including single-event survival and competing-risk analysis. | [CohortSurvival Documentation](https://darwin-eu.github.io/CohortSurvival/) |


### 5STES Notebook Examples

In addition to the official Darwin-EU documentation, there are Jupyter notebooks demonstrating the use of Darwin-EU analyses within the Five Safes TES.

- [5STES Darwin-EU Notebook Examples](https://github.com/Health-Informatics-UoN/5s-TES-notebooks/tree/main/Darwin-EU)


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

## PatientProfiles

`PatientProfiles` is a Darwin-EU package for enriching OMOP CDM cohorts with patient characteristics and identifying overlaps between cohorts, concepts, and clinical tables.

In OMOP CDM, clinical-event tables such as `condition_occurrence` and `drug_exposure` describe recorded events. To analyse a study population, researchers may also need to know:

- How old was the person at the event or index date?
- What was their recorded sex?
- How long had they been observed in the database before the event?
- Did they experience another condition or treatment within a specified window?

The toolkit's PatientProfiles scripts add these features to cohort tables. They **do not automatically export aggregate results**; use `summariseCohort.R` after feature generation when a summary is required.

PatientProfiles also supports different ways of analysing clinical events:

- **Cohort Intersections:** Compare a study cohort against another cohort to identify overlapping events.
- **Concept Intersections:** Identify events matching selected OMOP concepts, such as diagnoses or procedures.
- **Table Intersections:** Analyse records from OMOP CDM tables, such as `visit_occurrence` or `drug_exposure`.

These analyses can calculate event counts, dates, time intervals, and presence or absence flags. The generated characteristics can then be summarised into aggregate results using `summariseCohort.R`.


### Cohort Characterisation

For example, a researcher may want to know:

- What is the age and sex distribution of a skin cancer cohort?
- How many patients have at least 365 days of prior observation?
- How many patients were in observation on the index date?

### Cohort Intersections

Suppose a researcher defines:

- **Cohort A:** Skin cancer patients (index cohort).
- **Cohort B:** Diabetes patients (comorbidity cohort).

They want to know: **"Which skin cancer patients also had diabetes in the year before their cancer diagnosis?"**

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

By default, the toolkit performs three diagnostic checks:

- **Missing Values:** Identifies missing information in drug exposure records, such as quantities or days supplied.
- **Exposure Duration:** Examines recorded exposure durations to identify potential inconsistencies.
- **Quantity:** Analyses the distribution of recorded drug quantities.

Additional diagnostic checks can be configured depending on the research requirements.


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

### Single-event survival

Answers: **"How does the probability of remaining free from a specified outcome change over time?"**

For example, a study might estimate the proportion of patients who have not experienced hospital readmission at different points within a year of cohort entry.

Follow-up can be limited to a maximum length, people with a prior outcome can be excluded using a washout, and follow-up can be **censored** (stopped) when a person leaves the target cohort.

### Competing-event survival

Answers: **"How does the risk of an outcome change when another event can prevent it from occurring?"**

For example, death may be treated as a competing event when studying another clinical outcome. The toolkit includes `estimateCompetingEventSurvival.R`, which takes target, outcome, and competing-outcome cohorts.

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