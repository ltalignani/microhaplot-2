# Install all microhaplot2 dependencies.
# Run this script once on a fresh machine before launching the app.
#
#   source("install_deps.R")
#   OR: Rscript install_deps.R

if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

BiocManager::install(c("Rsamtools", "VariantAnnotation", "BiocParallel"))

install.packages(c(
  "shiny",
  "bslib",
  "shinyWidgets",
  "DT",
  "dplyr",
  "ggplot2",
  "tidyr",
  "ggiraph",
  "here"
))
