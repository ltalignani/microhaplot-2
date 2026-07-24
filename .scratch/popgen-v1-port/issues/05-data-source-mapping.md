Type: grilling
Status: resolved

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

## Answer

Option (b): a new reactive, decoupled from the group/locus/individual
selector.

`Filter.haplo.by.RDnAR()` (`server.R` ~line 1057) already has exactly the
right per-locus threshold logic — it joins `annotateTab$tbl` for
per-locus `min.rd`/`min.ar`/`n.alleles`, honors the 3 `filterParam$opts`
override modes ("1" = raise-if-below-baseline, "2" = override-all, else
broad-stroke), then filters on `allele.balance >= min.ar`, `rank <=
n.alleles`, and summed `depth >= min.rd` per group/id/locus. The only
change needed is its *source*: `Min.filter.haplo()` (selector-narrowed) →
`update.Haplo.file()` (the full dataset).

**Decision**: duplicate `Filter.haplo.by.RDnAR()` as a new reactive (name
suggestion: `PopGenetics.filtered.haplo()`) living right next to it in
`server.R`, identical logic, swapping only the source reactive. Not
factored into a parameterized shared function — `Filter.haplo.by.RDnAR()`
is a zero-argument Shiny reactive hard-wired to `Min.filter.haplo()`;
turning it into a parameterized function touches existing, fragile code
in a 3887-line file for a ~25-line duplication saved. Not worth the risk.

Output shape: same as the existing reactive — standard `haplo_data`
columns (`group`, `id`, `locus`, `haplo`, `depth`, `allele.balance`,
`rank`) plus the joined `min.rd`/`min.ar`/`n.alleles` annotation columns.
The extra columns are harmless for `pop_genetics_encoding.R`'s
`encode_hierfstat()`/`encode_onehot()`, which only reference specific
named columns — no `select()` cleanup is strictly required, though one
can be added for tidiness.

The "raw" data source is simply `update.Haplo.file()` directly (already
decoupled from the selector — no new reactive needed for that side).
