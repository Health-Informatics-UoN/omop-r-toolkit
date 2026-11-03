
# ----- STAGE 1: BUILDER -----
FROM rocker/r-ver:4.6.1 AS builder

WORKDIR /opt/omop-r-toolkit

# Install build dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl \
       openjdk-11-jdk-headless \
       pkg-config \
       libcurl4-openssl-dev \
       libssl-dev \
       libxml2-dev \
       libpcre2-dev \
       libdeflate-dev \
       liblzma-dev \
       libbz2-dev \
       xz-utils \
       zlib1g-dev \
       libpq-dev \
    && rm -rf /var/lib/apt/lists/* \
    && R CMD javareconf

# Install rv
RUN curl -fsSL https://raw.githubusercontent.com/A2-ai/rv/refs/heads/main/scripts/install.sh | bash \
    && mv /root/.local/bin/rv /usr/local/bin/rv

# Install locked R dependencies
COPY rproject.toml rv.lock ./

RUN rv sync --locked

# rv nests the library by R version, arch and distro; copy it to a fixed path for the runtime stage.
RUN mkdir -p /rlib \
    && cp -a "$(rv library)/." /rlib/ \
    && test -d /rlib/DBI


# ----- STAGE 2: RUNTIME -----
FROM rocker/r-ver:4.6.1 AS runtime

WORKDIR /

# Install runtime libraries and remove development packages
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
       openjdk-11-jre-headless \
       libpq5 \
       libgomp1 \
    && R CMD javareconf \
    && apt-get purge -y --auto-remove linux-libc-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy preinstalled R packages
COPY --from=builder /rlib/ /opt/omop-r-toolkit/library/

# Puts the copied rv library on R's search path - runtime can identify the packages installed by rv.
ENV R_LIBS=/opt/omop-r-toolkit/library

# Copy application files
COPY R/ ./R/
COPY inst/ ./inst/

# Create non-root user and output directory
RUN useradd \
      --uid 10001 \
      --create-home \
      --shell /usr/sbin/nologin omop \
    && mkdir -p /outputs \
    && chown 10001:10001 /outputs \
    && chmod -R a+rX /opt/omop-r-toolkit/library

ENV HOME=/home/omop

USER 10001:10001

CMD ["Rscript", "./inst/scripts/count-cohorts.R"]
