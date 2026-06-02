FROM rocker/shiny:4.4.1

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libbz2-dev \
    liblzma-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('bslib', 'shinyWidgets', 'DT', 'dplyr', 'ggplot2', 'tidyr', 'ggiraph'), repos = 'https://cloud.r-project.org')"

RUN R -e "if (!require('BiocManager', quietly = TRUE)) install.packages('BiocManager', repos = 'https://cloud.r-project.org'); BiocManager::install(c('Rsamtools', 'VariantAnnotation', 'BiocParallel'), ask = FALSE)"

COPY app/ /srv/shiny-server/microhaplot2/

RUN chown -R shiny:shiny /srv/shiny-server/microhaplot2

EXPOSE 3838
