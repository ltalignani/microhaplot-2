FROM rocker/r-ver:4.5.0

# samtools: BAM support. perl: hapture.pl. build-essential/gfortran:
# compiling pcadapt/RSpectra. libclang-dev/curl: microhaplot-extract's Rust
# build (bindgen, via hts-sys, needs libclang; curl fetches rustup below —
# see research/rust-htslib-build-requirements.md). The rest: ggiraph's
# graphics/network dependency chain (svglite/gdtools and friends).
RUN apt-get update && apt-get install -y --no-install-recommends \
    perl \
    samtools \
    build-essential \
    gfortran \
    cmake \
    libclang-dev \
    curl \
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

# A current, rustup-managed toolchain, not whatever (stale) rustc Debian's
# own apt repo ships — see research/rust-htslib-build-requirements.md for
# why toolchain age broke the very first build attempt.
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal --default-toolchain stable

# Build microhaplot-extract's dependencies in their own layer, before its
# source is copied in — same cache-ordering principle as R's
# install_deps() below: a source-only edit doesn't retrigger the
# dependency compile (htslib's own C source, vendored and compiled by
# hts-sys, is the expensive part — see
# research/rust-htslib-build-requirements.md). The stub src/ is only
# there to give this layer something to compile against; the real source
# copied in afterwards reuses this layer's already-built dependency
# artifacts in the same target/ directory, and only recompiles the
# workspace crate itself.
WORKDIR /opt/microhaplot-extract
COPY rust/microhaplot-extract/Cargo.toml rust/microhaplot-extract/Cargo.lock ./
RUN mkdir src \
  && echo "fn main() {}" > src/main.rs \
  && echo "" > src/lib.rs \
  && cargo build --release \
  && rm -rf src

COPY rust/microhaplot-extract/src ./src
RUN touch src/main.rs src/lib.rs \
  && cargo build --release \
  && cp target/release/microhaplot-extract /usr/local/bin/microhaplot-extract
WORKDIR /
RUN rm -rf /opt/microhaplot-extract /usr/local/cargo/registry

# Nothing calls this yet — prepHaplotFiles()/prep_validation.R still drive
# the Perl/samtools pipeline below unchanged (wayfinder ticket #34 is
# "expand", not "cut over"; that's ticket #36). MICROHAPLOT_EXTRACT_BIN
# just makes the binary discoverable the same way
# find_microhaplot_extract_bin() already resolves a local dev build,
# for whenever something does start calling it.
ENV MICROHAPLOT_EXTRACT_BIN=/usr/local/bin/microhaplot-extract

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
