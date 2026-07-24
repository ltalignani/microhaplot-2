# Tickets: Population Genetics tab for microhaplot v1

Breaks down the spec at `.scratch/popgen-v1-port/PRD.md` — porting
microhaplot2's core Population Genetics functionality (F-statistics,
Allelic diversity, PCA/Projection, Outlier scan) into microhaplot v1, as a
new `navbarMenu("Population Genetics", ...)` entry between "Genotype Call"
and "Table", in v1's existing shinyBS/Bootstrap 3 style.

Work the **frontier**: any ticket whose blockers are all done. Ticket 1 is
the foundation; tickets 2 and 3 are independent of each other and can run
in parallel once ticket 1 is done.

## F-statistics and Allelic diversity sub-tabs (foundation)

**What to build:** The new "Population Genetics" entry appears in the
bottom navbar between "Genotype Call" and "Table", with its 4 sub-tabs
(F-statistics, Allelic diversity, PCA / Projection, Outlier scan — the
last two as placeholders for now). The **F-statistics** sub-tab shows a
per-locus Ho/He/Fis/Fst/Fit table (with a "Global" summary row), a
pairwise Fst heatmap, and BetaS (global + per-locus) — each downloadable
as CSV. The **Allelic diversity** sub-tab shows rarefied allelic richness
per locus and group, as both a table and a plot, also downloadable. Both
sub-tabs let the user toggle between raw and quality-filtered data, and
show a clear warning instead of a blank/broken result when fewer than 2
groups are present in the data.

**Blocked by:** None — can start immediately

- [ ] `hierfstat` and `pcadapt` are added to `DESCRIPTION`'s `Imports`
- [ ] `pop_genetics_encoding.R`, `pop_genetics_stats.R`, and `pop_genetics_tables.R` are ported from microhaplot2 into v1's `R/` directory unmodified, with `testthat` tests covering `encode_hierfstat()`, `encode_onehot()`, `compute_fstats()`, and the table-shaping helpers
- [ ] A new `PopGenetics.filtered.haplo()` reactive exists in `server.R`, duplicating `Filter.haplo.by.RDnAR()`'s per-locus threshold logic but sourced from `update.Haplo.file()` (the full dataset) instead of the selector-narrowed `Min.filter.haplo()`
- [ ] `navbarMenu("Population Genetics", ...)` appears between "Genotype Call" and "Table", with 4 `tabPanel(h5(...), ...)` sub-tabs matching the app's existing `navbarMenu` title convention
- [ ] The F-statistics sub-tab shows the per-locus table (with Global row), pairwise Fst heatmap, and BetaS, each with a working CSV download button, and a raw/filtered toggle
- [ ] The Allelic diversity sub-tab shows the rarefied richness table and plot, with CSV download and a raw/filtered toggle
- [ ] Both sub-tabs show a visible warning (not a silent empty result or hard error) when fewer than 2 groups are present
- [ ] PCA / Projection and Outlier scan render as non-erroring placeholders

## PCA / Projection sub-tab

**What to build:** The PCA / Projection sub-tab's placeholder is replaced
with the real two-phase flow: an "Explore" phase (fixed K = 10, screeplot)
triggered by an action button, followed by a "Final" phase where the user
picks their own K for the committed PCA. Same raw/filtered toggle as the
other sub-tabs.

**Blocked by:** F-statistics and Allelic diversity sub-tabs (foundation)

- [ ] `pop_genetics_pca.R` is ported from microhaplot2 into v1's `R/` directory unmodified, with `testthat` tests covering `run_pca()` and `project_onto_pca()`
- [ ] The Explore phase runs a K=10 PCA on button click and shows a screeplot
- [ ] The Final phase lets the user choose their own K and shows the resulting PCA
- [ ] The raw/filtered data source toggle works the same way as the other sub-tabs
- [ ] Layout (headers, controls, buttons) follows the same shinyBS conventions established in the foundation ticket

## Outlier scan sub-tab

**What to build:** The Outlier scan sub-tab's placeholder is replaced with
the real two-phase flow: an "Explore" phase (fixed K = 10, screeplot),
followed by a "Final" phase running the committed pcadapt scan with
Benjamini-Hochberg-corrected outlier calls, plus diagnostic QQ and
p-value-histogram plots. Same raw/filtered toggle as the other sub-tabs.

**Blocked by:** F-statistics and Allelic diversity sub-tabs (foundation)

- [ ] `pop_genetics_pcadapt.R` is ported from microhaplot2 into v1's `R/` directory unmodified, with `testthat` tests covering `run_pcadapt_scan()`, `locus_names_from_onehot()`, and `get_outliers_bh()`
- [ ] The Explore phase runs a K=10 scan on button click and shows a screeplot
- [ ] The Final phase runs the committed scan and shows BH-corrected outlier calls
- [ ] QQ-plot and p-value-histogram diagnostic plots are shown
- [ ] The raw/filtered data source toggle works the same way as the other sub-tabs
- [ ] Layout (headers, controls, buttons) follows the same shinyBS conventions established in the foundation ticket
