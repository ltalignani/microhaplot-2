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

# Install the dependencies from DESCRIPTION alone, before copying the source.
# Docker keys its layer cache on the build context, so copying the whole repo
# first would make any edit to any file — a script, the README, .dockerignore —
# recompile the entire dependency tree (ggiraph's C++ chain, pcadapt, RSpectra:
# ~20 minutes). Split this way, that only happens when DESCRIPTION changes.
COPY DESCRIPTION /tmp/microhaplot-deps/DESCRIPTION
RUN Rscript -e 'remotes::install_deps("/tmp/microhaplot-deps", dependencies = TRUE, repos = "https://cloud.r-project.org")' \
  && rm -rf /tmp/microhaplot-deps

COPY . /tmp/microhaplot-src
RUN R CMD INSTALL /tmp/microhaplot-src \
  && rm -rf /tmp/microhaplot-src

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
  && useradd --create-home --home-dir /home/appuser appuser

USER appuser
WORKDIR /home/appuser

EXPOSE 3838
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
