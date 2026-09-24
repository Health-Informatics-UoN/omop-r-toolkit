FROM rocker/r-ver:4.6.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
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
RUN curl -sSL https://raw.githubusercontent.com/A2-ai/rv/refs/heads/main/scripts/install.sh | bash

RUN mv ~/.local/bin/rv /usr/local/bin/rv

COPY rproject.toml rproject.toml

COPY rv.lock rv.lock

RUN rv sync

RUN rv activate

RUN mkdir -p /output /jdbc \
    && R -e 'DatabaseConnector::downloadJdbcDrivers("postgresql", pathToDriver = "/jdbc")'

COPY . .
    
CMD ["Rscript", "./R/count-cohorts.R"]
