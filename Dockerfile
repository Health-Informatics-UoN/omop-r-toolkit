FROM rocker/r-ver:4.4.1

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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && R CMD javareconf

RUN install2.r --error --ncpus 2 \
    rJava \
    remotes \
    ParallelLogger \
    SqlRender \
    DatabaseConnector \
    FeatureExtraction \
    CohortGenerator \
    CDMConnector \
    CodelistGenerator \
    omopgenerics \
    PatientProfiles \
    CirceR

COPY . .
    
CMD ["Rscript", "hello.R"]
