# #6 — Module filter + annotation : seuils par locus et statut Accept/Reject

## What to build

A Shiny module (`filterAnnotationModule`) providing per-locus filtering controls and annotation capabilities. This is the curation core of microhaplot2.

End-to-end: the user selects a locus, adjusts filtering thresholds, applies them, sees updated visualisations, and saves parameters and a comment/status per locus. The filtered dataset is emitted for use by downstream modules.

Key elements:
- Filter parameters: `min.rd`, `min.ar`, `n.alleles`, `max.ar.hm`, `min.ar.hz` — per-locus and global override modes.
- Filter options: global override, minimum baseline override, rely on local locus params.
- Annotation per locus: free-text comment, Accept/Reject status.
- Annotations stored in the session temp directory (not in the app directory — fixes the multi-user write conflict of the legacy code).
- Replace `shinyBS` `createAlert`/`closeAlert` with `bslib`/`shinyWidgets` equivalents.
- Expose the core filtering logic (`filter_by_rd_ar()`, `filter_summary()`) as pure R functions with no Shiny dependency for unit testing.

## Acceptance criteria

- [ ] `testthat` tests cover: correct rows retained/rejected for each filter parameter, global override mode, local locus param mode, edge cases (zero reads, single haplotype)
- [ ] Annotation save writes to session temp dir, not to the app installation directory
- [ ] Two concurrent sessions do not overwrite each other's annotations
- [ ] Changing locus updates filter controls to the saved values for that locus
- [ ] No `shinyBS` calls remain in module code
- [ ] Filter logic functions pass R CMD CHECK with no warnings

## Blocked by

- Issue #5
