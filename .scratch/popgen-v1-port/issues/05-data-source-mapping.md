Type: grilling
Status: open

## Question

microhaplot2's Population Genetics tab has a clean "raw vs filtered" data
source toggle: `haplo_data()` is the full unfiltered extraction result,
`filtered_data()` is the same data with quality thresholds (min. read
depth, allele ratio, n alleles) applied — both span every group/locus/
individual.

v1 doesn't have a direct equivalent. `update.Haplo.file()`
(`inst/shiny/microhaplot/server.R` ~line 82) is the true full-dataset
reactive (readRDS of the selected `.rds`, no narrowing) — this matches
`haplo_data()`. But v1's existing "filtered" reactives,
`Min.filter.haplo()` (~line 1040) and `Filter.haplo.sum()` (~line 1196),
are narrowed by the current group/locus/individual field-selector
(`input$selectGroup`/`selectLocus`/`selectIndiv`) *in addition to*
quality-threshold filtering — because they were built to back the
per-locus/per-individual detail views elsewhere in the app, not a
whole-dataset population-level view. Population genetics statistics (F-stats
across groups, PCA across individuals) need the full breadth of
groups/individuals/loci, not whatever happens to be selected in a detail
pill elsewhere in the UI.

Decide: should the new tab's "filtered" data source (a) reuse
`Filter.haplo.sum()` as-is, accepting that population genetics results
would silently narrow to whatever the user has currently selected in the
top field-selector (surprising/wrong for a population-level analysis), or
(b) introduce a new reactive that applies only the RD/AR/n-alleles quality
thresholds (from `filterParam`) to the full `update.Haplo.file()`,
decoupled from the group/locus/individual selector — mirroring what
v2's `filtered_data()` actually means? If (b), where should that new
reactive live and what exactly should it filter on?
