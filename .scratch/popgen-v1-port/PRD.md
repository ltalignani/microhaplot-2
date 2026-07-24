Status: ready-for-agent

# Population Genetics tab for microhaplot v1

## Problem Statement

microhaplot v1 has no way to compute population-level genetics summaries
— F-statistics, allelic diversity, PCA/projection, or an outlier scan —
from extracted haplotype data. Users who want these analyses currently
have to export their data out of microhaplot and run them elsewhere.
microhaplot2 (the bslib-based rewrite) already implements this
functionality, but v1 users — who are on the established shinyBS/
Bootstrap 3 interface — have no equivalent within the tool they're
already using.

## Solution

Add a new "Population Genetics" entry to v1's bottom-fixed navbar,
positioned between "Genotype Call" and "Table", offering four sub-tabs —
F-statistics, Allelic diversity, PCA / Projection, and Outlier scan — each
computed on either the raw or quality-filtered haplotype data. The
underlying computations (hierfstat/pcadapt wrappers, encoding, PCA,
outlier detection) are ported unmodified from microhaplot2's pure-function
layer; only the Shiny UI/server wiring is newly written, in v1's existing
shinyBS/Bootstrap 3 style rather than bslib.

## User Stories

1. As a microhaplot v1 user, I want a "Population Genetics" tab in the main navbar, so that I can compute population-level summaries without leaving the app.
2. As a microhaplot v1 user, I want the new tab positioned between "Genotype Call" and "Table", so that it fits naturally into the existing analysis workflow order.
3. As a microhaplot v1 user, I want to see per-locus Ho/He/Fis/Fst/Fit statistics with a "Global" summary row, so that I can assess differentiation and diversity across my groups.
4. As a microhaplot v1 user, I want to see pairwise Fst between my groups, so that I can compare differentiation between specific group pairs.
5. As a microhaplot v1 user, I want to see BetaS (global and per-locus), so that I get an alternative, less-biased estimator of population structure.
6. As a microhaplot v1 user, I want to see rarefied allelic richness per locus and group, so that I can compare diversity fairly across groups of different sizes.
7. As a microhaplot v1 user, I want to run a PCA on my individuals in two phases — an exploratory scree plot at a fixed K, then a final PCA at a K I choose — so that I can pick a sensible number of components before committing to the full analysis.
8. As a microhaplot v1 user, I want to run a pcadapt outlier scan in the same two-phase pattern (explore, then final scan), with Benjamini-Hochberg-corrected outlier calls and diagnostic QQ/p-value plots, so that I can identify loci that look like they're under selection.
9. As a microhaplot v1 user, I want to toggle each sub-tab's computation between my raw extracted data and my quality-filtered data, so that I can see how filtering affects the population-level results.
10. As a microhaplot v1 user, I want the filtered view to reflect only the quality thresholds I've set (read depth, allele ratio, number of alleles) — not whatever locus/individual/group I currently happen to have selected elsewhere in the app — so that population-level statistics are computed over my whole dataset, not silently narrowed to one detail view.
11. As a microhaplot v1 user, I want to download each result table (per-locus stats, pairwise Fst, BetaS, allelic richness) as CSV, so that I can use the results outside the app.
12. As a microhaplot v1 user, I want the new tab's look and feel (headers, controls, buttons) to match the rest of the app, so that it doesn't feel like a bolted-on, visually inconsistent feature.
13. As a microhaplot maintainer, I want the population-genetics computation logic ported unmodified from microhaplot2's pure-function files, so that I'm not re-deriving or re-debugging already-working statistical code.
14. As a microhaplot maintainer, I want `hierfstat` and `pcadapt` added as hard package dependencies, so that the feature works out of the box without runtime dependency checks.
15. As a microhaplot maintainer, I want this port to explicitly exclude the external reference-panel merge feature (uploading and merging an outside dataset), so that this effort stays scoped to analyses on the user's own data.

## Implementation Decisions

- **Navbar placement**: a new `navbarMenu("Population Genetics", ...)` inserted into `inst/shiny/microhaplot/ui.R`'s bottom-fixed `navbarPage`, positioned after the existing `navbarMenu("Genotype Call", ...)` and before the `tabPanel("Table", ...)`.
- **Sub-tab structure**: four `tabPanel`s inside that `navbarMenu`, each titled with `h5(...)` (matching every other multi-part `navbarMenu` in the app, e.g. `tabPanel(h5("Global Scope"), ...)` in "Criteria Cutoff"): "F-statistics", "Allelic diversity", "PCA / Projection", "Outlier scan".
- **Ported pure-function modules**: microhaplot2's `pop_genetics_encoding.R` (`encode_hierfstat()`, `encode_onehot()`), `pop_genetics_stats.R` (`compute_fstats()` and its internal helpers), `pop_genetics_pca.R` (`run_pca()`, `project_onto_pca()`, `align_query_to_reference()`), `pop_genetics_pcadapt.R` (`run_pcadapt_scan()`, `locus_names_from_onehot()`, `get_outliers_bh()`), and `pop_genetics_tables.R` (the table-shaping helpers: `fstats_perloc_table()`, `pairwise_fst_long()`, `betas_table()`, `allelic_richness_table()`) are copied into v1's `R/` directory unmodified — no Shiny dependency, no behavioral changes. `align_query_to_reference()` is ported for completeness even though the reference-panel feature that used it is out of scope; it's inert until that future effort wires it up.
- **Data source mapping**:
  - "Raw" data source = `update.Haplo.file()` (v1's existing full-dataset reactive — no group/locus/individual narrowing).
  - "Filtered" data source = a new reactive, `PopGenetics.filtered.haplo()`, added to `server.R` next to the existing `Filter.haplo.by.RDnAR()`. It duplicates that reactive's per-locus threshold logic (joins `annotateTab$tbl` for per-locus `min.rd`/`min.ar`/`n.alleles`, honors the existing `filterParam$opts` override modes, filters on `allele.balance >= min.ar`, `rank <= n.alleles`, and summed `depth >= min.rd`) but is sourced from `update.Haplo.file()` instead of the selector-narrowed `Min.filter.haplo()` — deliberately duplicated rather than refactoring the existing reactive into a parameterized function, to avoid touching already-fragile shared code.
  - Each of the 4 sub-tabs gets its own raw/filtered toggle control (a `radioButtons`), repeated per sub-tab rather than shared, since v1 has no persistent sidebar/cross-tab control area.
- **UI layout conventions** (all resolved by direct precedent from the existing "Criteria Cutoff"/"Genotype Call" `navbarMenu`s, not new patterns):
  - No card/`wellPanel` wrapper around sections — section headers are plain `h4()`/`h5()` calls directly inside a `column()`, matching e.g. `column(6, h4("Individual list:"))` in "Criteria Cutoff".
  - Controls (the raw/filtered toggle, K inputs, explore/final-scan action buttons) laid out via `fluidRow`/`column` with explicit widths/offsets, matching the "Quality Profiling" sub-tab's existing pattern.
  - Download buttons use plain `downloadButton(...)` with no custom class, matching the "Table" tab's `downloadButton('downloadData', 'Download')`.
- **PCA / Outlier scan two-phase interaction**: preserved from microhaplot2 — an "Explore" phase (fixed K = 10, screeplot) triggered by an `actionButton`, followed by a "Final" phase where the user picks their own K for the committed PCA/scan or outlier call. Exact input widgets (numeric K entry, etc.) follow v1's existing conventions for similar numeric parameters (e.g. `numericInput` usage in "Criteria Cutoff"'s Quality Profiling sub-tab).
- **hierfstat's two-or-more-groups requirement**: `compute_fstats()` already short-circuits pairwise Fst/BetaS to `NA`/empty when fewer than 2 groups are present (existing behavior, unchanged by the port). The new tab surfaces this the same way microhaplot2 does — a visible warning when fewer than 2 groups are present, rather than a silent empty result or a hard error.
- **Dependencies**: `hierfstat` and `pcadapt` added to `DESCRIPTION`'s `Imports` (both on CRAN, actively maintained, `GPL (>= 2)`-licensed — compatible with v1's `GPL-3`; `pcadapt` has compiled code but CRAN provides binaries for major platforms, no CRAN-submission concern).

## Testing Decisions

- A good test here proves the ported functions' external behavior (given an encoded matrix/haplo_data input, does it produce statistically correct output) — not Shiny wiring, not implementation details of how the UI calls them.
- The single test seam is the ported pure-function layer: `encode_hierfstat()`, `encode_onehot()`, `compute_fstats()` and its helpers, `run_pca()`, `project_onto_pca()`, `run_pcadapt_scan()`, `get_outliers_bh()`, and the `pop_genetics_tables.R` shaping helpers — tested directly with `testthat`, the same infrastructure already bootstrapped in v1 for `prepHaplotFiles()`'s BAM support and the field-prep-app's `validate_prep_inputs()`.
- The new `PopGenetics.filtered.haplo()` Shiny reactive and all other UI/server wiring (the `navbarMenu`, sub-tab layout, raw/filtered toggles, two-phase PCA/outlier-scan interaction, plot/table rendering) are not covered by automated tests in this spec — v1's `server.R` has no existing Shiny-reactive test infrastructure to extend, consistent with how the field-prep-app spec treated its own Shiny orchestration layer. Manual verification against a real extracted dataset is expected instead.
- Prior art: `tests/testthat/test-validate-prep-inputs.R` (pure-function testing pattern, fixtures independent of any Shiny session) is the model to follow for the new population-genetics tests.

## Out of Scope

- **External reference-panel merge feature** (microhaplot2's reference-panel upload, locus-overlap validation, merge with the user's data, per-sub-tab "reference" badges). A distinct, larger future effort — `align_query_to_reference()` is ported now but stays unused until that effort picks it up.
- **Any change to `hapture.pl`, `prepHaplotFiles()`, or the extraction pipeline.** This spec is purely additive downstream of already-extracted haplotype data.
- **Changes to the microhaplot2 rewrite.** This is a v1-only port; the source files in microhaplot2 are read as reference material, not modified.

## Further Notes

- This spec synthesizes the 6 decisions from the wayfinder map "Population
  Genetics v1 port" (`.scratch/popgen-v1-port/map.md`), whose tickets hold
  the full rationale behind each decision above, including the direct
  code precedents cited for the UI layout choices.
- A suggested implementation rollout order (e.g. F-statistics + Allelic
  diversity first, since they share `compute_fstats()`, then PCA/
  Projection, then Outlier scan) was deliberately left for `/to-tickets`
  to decide, not fixed here.
