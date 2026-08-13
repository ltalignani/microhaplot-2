# microhaplot 2.0.0

First release under the microhaplot 2 name. The version jumps from 1.0.x
because this is no longer a patch series on the original package: it adds
whole capabilities and a second application, and the 1.0.x numbering
suggested otherwise.

## New

* **Population Genetics** module, with four views: F-statistics (per-locus
  Ho/He/Fis/Fst/Fit, pairwise Fst, BetaS), rarefied allelic diversity,
  PCA / Projection, and an outlier scan built on `pcadapt`. Each offers a
  choice between raw and filtered genotypes, and exports to CSV.
* **Field Genotyping Prep** app (`runShinyHaplotPrep()`), a five-step wizard
  around `prepHaplotFiles()` for people who would rather not use the R
  console. It validates everything up front — BAM presence and integrity,
  metadata schema, VCF/BAM chromosome agreement — and reports every problem
  at once rather than stopping at the first.
* **BAM input** for `prepHaplotFiles()`. BAM and SAM files can be mixed
  freely in one label file; BAMs are streamed through `samtools` rather than
  converted on disk, and need no `.bai` index. Gzipped VCFs are accepted
  the same way.
* **Docker distribution.** One image serves both apps, orchestrated by
  `docker-compose.yml`, published multi-arch (amd64 and arm64) to
  `ghcr.io/ltalignani/microhaplot-2`. No R, Perl or samtools installation is
  required, and BAM input works on Windows this way, which it does not
  natively. `MICROHAPLOT_INPUT_DIR` mounts a folder of alignments from
  anywhere on the host, read-only.
* **Documentation.** A vignette covering extraction under Docker end to end,
  a Population Genetics section in the walkthrough, and a documentation site
  built and published by CI.

## Fixes

* The main viewer attached the `tidyverse` meta-package, which is not a
  declared dependency and is therefore missing from any clean installation.
  Every session died on startup and the Data Set dropdown stayed empty.
* The Docker entrypoint installed the Shiny app into the shared volume only
  on first start, so pulling a newer image left existing users running the
  app version that first created their data folder.
* The prep wizard's progress bar never reached the browser: the extraction
  promise was created in the same Shiny flush cycle as the screen meant to
  report on it, so that screen was withheld until the work had finished.
* Uploads were capped at Shiny's 5 MB default, which rejects any realistic
  VCF. The ceiling is now 2 GB, and `MICROHAPLOT_MAX_UPLOAD_MB` raises it
  further.

# microhaplot 1.0.0

* added new parameter for `prepHaplotFiles`: `n.jobs`. For any non-window OS, you can specific the number of SAM files to be parallel processed. We recommend two times the number of processors/cores. (9/18/19)
* Introduces 3 main functions: `prepHaplotFiles`, `runShinyHaplot`, `mvShinyHaplot`
