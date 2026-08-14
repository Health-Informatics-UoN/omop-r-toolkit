# OMOP R toolkit

Packaging OMOP CDM R tools for use in [Five Safes TES](https://docs.federated-analytics.ac.uk/five_safes_tes)(5s-TES)

## How the tools are packaged

### Overview

The tools are made to run as a container, designed for eyes-off analysis using 5s-TES.
5s-TES works by a [Task Execution Service (TES)](https://www.ga4gh.org/product/task-execution-service-tes/) picking up a task sent through a submission layer.
A task is some computation carried out by "executors": containers that run some program, then write an output.
To make a reusable executor, this toolkit has a series of scripts in `/R` which can be run using `Rscript`.
This means users can pass commands to the container when it is running in 5s-TES to control what happens inside a Trusted Research Environment (TRE).

### Commands

For example, [counting a cohort](#count-a-cohort) can be done locally using the command line like so:

```bash
Rscript R/count-cohorts.R skin_cancer_20260713 --conceptSet="{'neoplasm': [139750]}" --output-path=outputs/output.csv
```

This will run the `R/count-cohorts.R` script with the command-line arguments specified.
Running this as a TES task is similar, except the tokens have to be passed as an array:

```json
[
    "Rscript",
    "R/count-cohorts.R",
    "skin_cancer_20260713",
    "--conceptSet={\"neoplasm\": [139750]}",
    "--output-path=outputs/output.csv"
]
```

One "gotcha" here is that where you would use quotes to wrap JSON on the command-line, you don't when specifying a command to a TES executor.

### Running as a TES executor

To fit with this, all the scripts are written to run in three steps:

1. Parse command-line arguments
2. Do something, hopefullly useful
3. Write the output somewhere

#### Parse command-line arguments

To do 1., the scripts have a string at the beginning which defines the help message for the CLI tool, then use [docopt](https://github.com/docopt/docopt.R) so this can be used as arguments to the script's functions.

#### Do something, hopefully useful

To do 2., the scripts use [Darwin-EU](github.com/darwin-eu/) libraries to interact with the OMOP-CDM, following examples in their excellent documentation.

#### Write the output somewhere

When writing the output (3.), the scripts have a CLI argument specifying at least one output path.
A TES message allows you to specify where you can collect your outputs from, for example a directory in an s3 bucket.
If you want to use your outputs afterwards, make sure these match!
In the example above, the `output-path` is `outputs/output.csv`, which means if the `/outputs` directory is described in the TES message, you can pick up your results from there later.


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
                                    "R/count-cohorts.R",
                                    "skin_cancer_20260713",
                                    "--conceptSet={\"neoplasm\": [139750]}",
                                    "--output-path=outputs/output.csv"
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

This starts the version of the container with the hash specified, passing it the command to run `count-cohorts.R`, and configuring the files written to the container's `/outputs` to be passed to an s3 bucket after.
Most of the rest is descriptive, refer to [5s-TES docs](https://docs.federated-analytics.ac.uk/) for more details

## Scripts
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
