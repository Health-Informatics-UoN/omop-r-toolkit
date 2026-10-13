# 5STES - Darwin & OMOP R Toolkit

OMOP R Toolkit is package created in R Language.

OMOP R Toolkit is a wrapper of Darwin-EU libraries for interacting with **OMOP Common Data Model (CDM)** databases.

It is specifically designed for running **Federated Analysis** inside Trusted Research Environments (TREs) using the Five Safes TES Framework.


## Incidence Prevalence

**Incidence** and **prevalence** are two fundamental epidemiological measures. The Darwin-EU `IncidencePrevalence` package calculates both from OMOP-CDM data.

#### **Incidence**

Incidence calculates ***How many* *new* cases occurred in a population over a specific time period?"**

- Measures the **rate of new events** (e.g., new diagnoses of a disease, new prescriptions).

    ```r
    estimateIncidence(
    cdm = cdm,
    denominatorTable = "denominator",  # population at risk
    outcomeTable = "outcome",          # the condition/event
    interval = "years",                # time buckets
    repeatedEvents = TRUE,             # can one person have multiple events?
    outcomeWashout = 180               # days before a person can re-enter
    )
    ```

#### **Prevalence**

Prevalence calculates ***"What proportion of the population has the condition at a given time?"***

- **Point Prevalence**
    - A specific moment (e.g., "How many people had diabetes on January 1st, 2010?").
    - Calculated as: **people with condition / total population** at that point.

    ```r
    estimatePointPrevalence(
    cdm = cdm,
    denominatorTable = "denominator",
    outcomeTable = "outcome",
    interval = "years",
    timePoint = "start"  # measure at start of each year
    )
    ```

- **Period Prevalence**
    - The proportion over a **span of time** (e.g., "How many people had diabetes at any point during 2010?").
    - Calculated as: **people with condition at any time in period / average population** during that period.

    ```r
    estimatePeriodPrevalence(
    cdm = cdm,
    denominatorTable = "denominator",
    outcomeTable = "outcome",
    interval = "years",
    completeDatabaseIntervals = TRUE,    # only include years with full data
    fullContribution = TRUE              # only count people observed all year
    )
    ```

## **PatientProfiles**

PatientProfiles is a Darwin-EU package for enriching OMOP CDM data with patient characteristics and for finding overlaps between different cohorts.

**PatientProfiles adds these columns** to any patient-level table or cohort table.

- It also lets you **intersect two cohorts** to answer questions like *"How many of my skin cancer patients were also in my diabetes cohort?*

In OMOP-CDM, raw tables like `condition_occurrence` or `drug_exposure` only contain the clinical event. They don't tell you:

- How old was the person when this happened?
- What is their sex?
- How long had they been in the database before this event?
- Did they also have diabetes (another cohort) within 30 days before this event?

PatientProfiles adds characteristics or intersections to a cohort, allowing these questions to be explored before aggregate summaries are produced.

#### Cohort Characterisation

For example, a researcher might want to know:
- What is the age and sex distribution of a skin cancer cohort?
- How many patients have at least 365 days of prior observation?
- How many were in observation on the index date?

    ```r
    Rscript inst/scripts/addCharacteristics.R skin_cancer \
    --addAge \
    --ageGroup='[[0,17],[18,64],[65,150]]' \
    --addSex \
    --addPriorObservation \
    --addInObservation \
    --inObservationWindow='[0,0]'
    ```

#### Cohort Intersections

A researcher defines:

- **Cohort A:** Skin cancer patients (index cohort)
- **Cohort B:** Diabetes patients (comorbidity cohort)

They want to know **"Which skin cancer patients also had diabetes in the year before their cancer diagnosis?"**

| Function / Script | What it adds | Example use |
| --- | --- | --- |
| `addCohortIntersectCount` | Number of intersecting cohort records | Number of diabetes episodes in the year before diagnosis |
| `addCohortIntersectFlag` | Flag for an intersecting event | Whether a patient had a prior diabetes record |
| `addCohortIntersectDate` | Date of intersecting event | Date of first relevant comorbidity event |
| `addCohortIntersectDays` | Time relative to an intersecting event | Days between diagnosis and comorbidity event |
| `addTableIntersectCount` / `Flag` / `Date` / `Days` | Intersection with an OMOP table | Prior drug exposure or another clinical record |
| `addConceptIntersectCount` / `Flag` / `Date` / `Days` | Intersection with a concept set | Events matching selected OMOP concepts |

**Note:** An intersection adds patient-level features. To obtain counts, percentages, or distributions suitable for export, summarise the enriched cohort with `summariseCohort.R`.

#### Workflow of PatientProfiles

```text
Step 1: Define a target cohort
   ↓
Step 2: Add age, sex, or observation characteristics
   ↓
Step 3: Add cohort, table, or concept intersections if required
   ↓
Step 4: Summarise the enriched cohort
   ↓
Step 5: Export aggregate cohort characteristics
```


## Drug Exposure Diagnostics

It is a **single-function package** and the main entry point is `executeChecks()`. You give it:

- One or more **ingredient concept IDs** (e.g., acetaminophen = `1125315`)
- A list of **which checks to run**

It returns a **named list of result tables** (14+ tables) covering every aspect of drug exposure quality and distribution.

DrugExposureDiagnostics is **not a study analysis** like incidence/prevalence. It is a **data quality audit** you run it **before** doing a study to answer:

- **Can I trust this drug data (are there any missing data)?**
- **How was this drug recorded in my database (doctor notes)?**
- **Which drug concepts should I include/exclude?**

| Article | Output table | What it diagnoses |
| --- | --- | --- |
| Missingness | `missingValuesOverall` | Are fields like `days_supply`, `quantity`, `sig` empty? |
| Drug Duration | `drugExposureDurationOverall` | Are exposure dates sensible? Any negative durations? |
| Drug Types | `drugTypesOverall` | Are these prescriptions, dispensations, or patient-reported? |
| Routes | `drugRoutesOverall` | Oral, IV, topical — how is the drug administered? |
| Source Concepts | `drugSourceConceptsOverall` | Did source-to-standard mapping work correctly? |
| Days Supply | `drugDaysSupply` | Does `days_supply` match calculated duration? |
| Verbatim End Date | `drugVerbatimEndDate` | Does source end date match OMOP end date? |
| Drug Dose | `drugDose` | Can we estimate daily dose from strength data? |
| Drug Sig | `drugSig` | What do prescription instructions look like? |
| Quantity | `drugQuantity` | How much was dispensed? |
| Diagnostics Summary | `diagnosticsSummary` | One-line quality scorecard per ingredient |

#### Workflow of DrugExposureDiagnostics

```
Step 1: Pick your drug ingredient (e.g., acetaminophen = 1125315)
    ↓
Step 2: Run drugExposureDiagnostics.R
    ↓
Step 3: Read the CSVs to decide:
    - Is the data quality good enough for my study?
    - Which drug concepts should I keep vs exclude?
    - Can I calculate dose, or is quantity too missing?
    - Are durations reliable?
    ↓
Step 4: Define your final drug cohort using what you learned
    ↓
Step 5: Run incidence/prevalence or other analyses
```

## DrugUtilisation

DrugUtilisation is a Darwin-EU package for **conducting Drug Utilisation Studies (DUS)** in data mapped to the OMOP Common Data Model.

Unlike generic cohort tools, it understands **drug exposure logic** era collapsing, days prescribed, dose calculation, and treatment patterns.

It answers questions like:

- **How was the drug used?** (duration, quantity, dose)
- **Why was it prescribed?** (indications)
- **Did patients stay on treatment?** (adherence)
- **After stopping, did they restart or switch?**

| Function / Article | What it does | Key output |
| --- | --- | --- |
| `generateIngredientCohortSet` | Creates a drug cohort from an ingredient name with `gapEra` collapsing | Cohort table in DB |
| `generateAtcCohortSet` | Creates a drug cohort from an ATC code | Cohort table in DB |
| `requirePriorDrugWashout` | Requires unexposed time before entry (incident use) | Filtered cohort |
| `requireIsFirstDrugEntry` | Keeps only the first drug record per person | Filtered cohort |
| `requireObservationBeforeDrug` | Requires N days of prior observation | Filtered cohort |
| `addIndication` / `summariseIndication` | Finds why the drug was prescribed (headache, flu, etc.) | Indication flags / summary CSV |
| `summariseDrugUtilisation` | Summarises exposure duration, quantity, dose, eras, days exposed | `summarised_result` CSV |
| `summariseTreatment` | Describes treatments received during follow-up windows | Treatment pattern summary |
| `summariseProportionOfPatientsCovered` | Measures adherence — % of cohort still on drug over time | PPC summary CSV |
| `summariseDrugRestart` | After discontinuation: restart same drug, switch, or stop? | Restart/switch summary CSV |
| `summariseDoseCoverage` | Validates whether daily dose can be computed from `drug_strength` | Dose coverage check |

#### Workflow of DrugUtilisation

```
Step 1: Generate drug cohort
    ↓
Step 2: Apply inclusion criteria (first entry, washout, observation)
    ↓
Step 3: Define indication cohorts (reuse defineConceptCohortSet)
    ↓
Step 4: Summarise indications
    ↓
Step 5: Summarise drug utilisation (duration, quantity, dose)
    ↓
Step 6: Assess adherence (PPC) or restart/switch patterns
    ↓
Step 7: Bind results + apply min-cell suppression
```

## Treatment Patterns

`TreatmentPatterns` is a Darwin-EU package for **analysing the sequence of treatments patients receive over time**.

Unlike DrugUtilisation, which focuses on **how individual drugs are used**, Treatment Patterns focuses on **how patients move between treatments**, including treatment changes, overlapping therapies, and combinations.

It answers questions like:

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

#### Treatment Pathway Concepts

| Concept / Parameter | What it means | Example |
| --- | --- | --- |
| Target cohort | Population or condition being studied | Sinusitis patients |
| Event cohorts | Treatment events used to construct the pathways | Amoxicillin, acetaminophen |
| Exit cohort | Optional event marking the end of the pathway | Death |
| `filterTreatments` | Selects whether to use first events, changes, or all events | `First`, `Changes`, `All` |
| `minEraDuration` | Minimum treatment-era duration to retain | 7 days |
| `eraCollapseSize` | Gap allowing repeated exposure eras to be merged | 30 days |
| `combinationWindow` | Required overlap for treatments to count as a combination | 7 days |
| `minPostCombinationDuration` | Minimum remaining treatment duration after separating combinations | 7 days |
| `maxPathLength` | Maximum number of treatment steps in a pathway | 5 steps |
| `splitEventCohorts` / `splitTime` | Splits selected events into acute and later therapy phases | Acute vs therapy |
| `minCellCount` / `censorType` | Controls disclosure of low counts in exported summaries | Suppress counts below 5 |

#### Treatment Sequences and Switching

A pathway shows **the order of recorded treatment events**.

```text
Patient A: Treatment A → Treatment B
Patient B: Treatment A → Treatment A + Treatment B
Patient C: Treatment B → Treatment C
```

- **Switching:** A subsequent treatment replaces or follows an earlier treatment.
- **Combination:** Treatment eras overlap for at least the configured combination window.
- **Continuation:** Repeated treatment eras may be merged based on the configured era gap.

The resulting aggregate data can be used to compare the frequencies of different treatment sequences.

#### Workflow of Treatment Patterns

```text
Step 1: Define the target cohort (disease or study population)
   ↓
Step 2: Define event cohorts (treatments, including all relevant occurrences)
   ↓
Step 3: Optionally define an exit cohort
   ↓
Step 4: Configure observation windows, treatment eras, and combinations
   ↓
Step 5: Run computePathways() to build treatment pathways
   ↓
Step 6: Export aggregate results with low-cell disclosure control
   ↓
Step 7: Visualise or compare treatment pathways outside the TRE
```
