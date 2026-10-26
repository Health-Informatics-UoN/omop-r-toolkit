# 5STES – OMOP R Toolkit: TES Message Examples

## Overview

This document provides example Task Execution Service (TES) JSON messages for running analyses using the OMOP R Toolkit within the Five Safes TES framework.

Each section explains the purpose of an analysis, the R scripts and CLI arguments used, and how to configure a TES message to execute the analysis inside a Trusted Research Environment (TRE).

The examples demonstrate how to define cohorts, execute analyses, export results, and clean up temporary cohort tables where required.

For a detailed explanation of the supported analysis types and their research applications, refer to analysis-types.md.


## What This Document Covers

For each analysis, the documentation includes:

- **Analysis Overview:** What the analysis does and the research question it addresses.

- **Execution Workflow:** The sequence of R scripts executed through TES.

- **CLI Commands:** The scripts and key parameters used for the analysis.

- **TES JSON Message:** A complete example that can be adapted for execution.

- **Expected Outputs:** The results produced and where they are stored.

## TES Message Structure

A TES message defines how the analysis is executed, including the container image, commands, inputs, outputs, and TRE configuration.

A single TES task can contain multiple executors to perform sequential steps such as cohort creation, analysis, and cleanup.

The examples use the OMOP R Toolkit container image: `ghcr.io/health-informatics-uon/omop-r-tools:edge`

Analysis results are generally written to `/outputs`, which is configured as a TES output directory for result collection.