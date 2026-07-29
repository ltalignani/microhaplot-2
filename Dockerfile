FROM rocker/r-ver:4.5.0

# samtools: BAM support. perl: hapture.pl. build-essential/gfortran:
# compiling pcadapt/RSpectra. The rest: ggiraph's graphics/network
# dependency chain (svglite/gdtools and friends).
RUN apt-get update && apt-get install -y --no-install-recommends \
    perl \
    samtools \
    build-essential \
    gfortran \
    cmake \
    libuv1-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libcairo2-dev \
    libfreetype6-dev \
    libfontconfig1-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

RUN Rscript -e 'install.packages("remotes", repos = "https://cloud.r-project.org")'

COPY . /tmp/microhaplot-src
RUN Rscript -e 'remotes::install_deps("/tmp/microhaplot-src", dependencies = TRUE, repos = "https://cloud.r-project.org")'
RUN R CMD INSTALL /tmp/microhaplot-src \
  && rm -rf /tmp/microhaplot-src

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
  && useradd --create-home --home-dir /home/appuser appuser

USER appuser
WORKDIR /home/appuser

EXPOSE 3838
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
