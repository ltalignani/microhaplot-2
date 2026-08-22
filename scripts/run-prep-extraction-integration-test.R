#!/usr/bin/env Rscript
# Runs test-prep-extraction-integration.R in a lightweight R session --
# used by .github/workflows/rust-tests.yml's cargo-test job (wayfinder
# ticket #35), and runnable locally the same way for debugging.
#
# Deliberately not the R package's own dependency set (Imports:
# ggiraph/pcadapt/hierfstat/shinyFiles/... -- a from-source compile heavy
# enough that docker-publish.yml budgets ~19 minutes for a cold build) and
# deliberately not the whole testthat suite: sources just the few files
# this one test needs, with only dplyr/magrittr/testthat/withr installed,
# so this stays fast enough for rust-tests.yml's own fail-fast purpose.
#
# Run from the repo root. Point MICROHAPLOT_EXTRACT_BIN at a built binary
# first if devtools::load_all()'s own auto-detection doesn't apply --
# system.file(package = "microhaplot") can't resolve anything here, since
# the package itself is deliberately not installed.

library(dplyr)
library(magrittr)
library(testthat)

source("R/prep_extraction.R")
source("R/microhaplot_extract_binary.R")
source("R/run_microhaplot_extract.R")
source("R/runHaplot.R")

result <- test_file("tests/testthat/test-prep-extraction-integration.R")
summary <- as.data.frame(result)
if (any(summary$failed > 0) || any(summary$error)) {
  quit(status = 1)
}
