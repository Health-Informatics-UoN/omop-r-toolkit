FROM rocker/r-ver:4.4.1

RUN /rocker_scripts/setup_R.sh https://packagemanager.posit.co/cran/__linux__/jammy/2023-01-29

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openjdk-11-jdk \
        libxml2-dev \
        libpcre2-dev \
        libdeflate-dev \
        liblzma-dev \
        libbz2-dev \
        zlib1g-dev \
        pkg-config \
        libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && R CMD javareconf

RUN install2.r --error --ncpus -1 \
    rJava \
    RPostgres \
    remotes \
    ParallelLogger \
    jsonlite \
    docopt \
    SqlRender \
    DatabaseConnector \
    omopgenerics \
    CDMConnector \
    CohortGenerator \
    CodelistGenerator \
    PatientProfiles \
    IncidencePrevalence \
    CohortCharacteristics \
    CohortSurvival \
    DrugUtilisation \
    DrugExposureDiagnostics

RUN mkdir -p /output /jdbc \
    && R -e 'DatabaseConnector::downloadJdbcDrivers("postgresql", pathToDriver = "/jdbc")'

COPY . .
    
CMD ["Rscript", "./R/count-cohorts.R"]
