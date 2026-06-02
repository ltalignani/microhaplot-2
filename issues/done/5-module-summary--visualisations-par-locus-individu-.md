# #5 — Module summary : visualisations par locus, individu et groupe

## What to build

A Shiny module (`summaryModule`) providing the main exploratory visualisations across loci, individuals, and groups. Replaces the monolithic BY LOCUS and BY INDIVIDUAL panels from the legacy `server.R`.

End-to-end: after extraction completes, the user can browse all loci and individuals via interactive plots, switch between group/individual/locus selectors, and navigate loci with prev/next buttons.

Key elements (rewrite of legacy deprecated code with bslib layout):
- **By locus**: haplotype density per locus, number of unique haplotypes per locus, fraction of callable individuals per locus, read depth violin plot per locus.
- **By individual**: allele balance ratio per individual, number of unique haplotypes per locus per individual, fraction of callable loci per individual.
- **By group**: group-level aggregation of the above.
- Group / Individual / Locus selectors with prev/next navigation buttons.
- Paginated display (configurable items per page).
- Fix all deprecated ggplot2 calls: `guide = FALSE` → `guide = "none"`, `element_rect(size=)` → `element_rect(linewidth=)`.
- Replace `tidyverse` bulk import with explicit `dplyr::`, `tidyr::`, `ggplot2::` calls.

## Acceptance criteria

- [ ] All four locus-level plots render correctly on the `sebastes` dataset
- [ ] All individual-level plots render correctly
- [ ] Group selector filters individuals correctly
- [ ] Locus prev/next navigation updates all plots
- [ ] No deprecated ggplot2 warnings in R console
- [ ] No `library(tidyverse)` calls remain in module code
- [ ] UI built with `bslib` components (no `shinyBS` dependency)

## Blocked by

- Issue #4
