## Destination

A validated architecture decision set for porting microhaplot2's core
Population Genetics functionality — F-statistics, Allelic diversity,
PCA/Projection, Outlier scan (excluding the external reference-panel merge
feature) — into microhaplot v1, as a new navbar entry positioned between
"Genotype Call" and "Table" in the bottom-fixed navbar, keeping v1's
existing shinyBS/Bootstrap 3 UI style. This map ends in a decision set
ready to hand to `/to-spec` — not working code.

## Notes

- Domain: R Shiny (classic `navbarPage` + shinyBS, Bootstrap 3), population
  genetics (`hierfstat`, `pcadapt`). Same package/repo as microhaplot v1
  (`ltalignani/microhaplot-2`), not the microhaplot2 rewrite.
- Source material: microhaplot2's `app/R/pop_genetics_*.R` (pure logic
  functions, no Shiny/bslib dependency — portable as-is) and
  `app/R/popGeneticsModule.R` (807 lines, bslib-based UI/server, needs
  translating to shinyBS), at
  `/Users/loictalignani/research/project/microhaplot-2/app/R/`.
- v1's relevant existing code: `inst/shiny/microhaplot/ui.R` (navbar
  structure, `navbarMenu("Genotype Call", ...)` around line 461 is the
  pattern to mirror; "Table" tab starts around line 656) and
  `inst/shiny/microhaplot/server.R` (3887 lines; `update.Haplo.file()`
  ~line 82 is the true raw dataset reactive; `Min.filter.haplo()`/
  `Filter.haplo.sum()` ~lines 1040/1196 are the existing "filtered" views,
  but narrowed by the group/locus/individual field-selector, not just
  quality thresholds — see ticket on data source mapping).
- Skills to consult when resolving tickets: `/grilling` and
  `/domain-modeling` for remaining decisions, `/prototype` for UI
  translation mockups if useful.
- Decision-only destination — do not implement in this map.

## Decisions so far

- [Excludes external reference-panel merge](issues/01-scope-exclude-reference-panel.md) — a distinct, larger future effort; this map covers the 4 core sub-tabs on the user's own data only.
- [All 4 core sub-tabs in scope together](issues/02-scope-four-subtabs.md) — F-statistics, Allelic diversity, PCA/Projection, Outlier scan; rollout/implementation ordering left to `/to-tickets`, not decided here.
- [hierfstat/pcadapt added as hard Imports](issues/03-dependencies-imports.md) — consistent with the shinyFiles/future/promises precedent from the field-prep-app effort.
- [hierfstat/pcadapt confirmed CRAN-safe](issues/04-dependency-cran-readiness.md) — both actively maintained on CRAN, GPL(>=2)-compatible with v1's GPL-3; pcadapt has compiled code (Rcpp) but CRAN binaries cover it, no submission blocker.
- [Data source mapping: new selector-decoupled reactive](issues/05-data-source-mapping.md) — "raw" = `update.Haplo.file()` directly; "filtered" = a new `PopGenetics.filtered.haplo()` duplicating `Filter.haplo.by.RDnAR()`'s per-locus threshold logic but sourced from the full dataset, not `Min.filter.haplo()`. Duplicated, not factored/parameterized.

## Not yet specified

(none beyond the open tickets below — everything currently foggy is
already sharp enough to ticket)

## Out of scope

- External reference-panel merge/import feature (mirroring microhaplot2's
  issue #17: upload a reference haplo_data CSV, validate locus overlap,
  merge with the user's data, per-sub-tab "reference" badges). A distinct,
  larger future effort, not part of this destination.
