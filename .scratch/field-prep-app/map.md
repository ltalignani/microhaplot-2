## Destination

A validated architecture/UX decision set for a new companion Shiny app —
bundled in the microhaplot v1 package alongside the existing visualization
app — that lets non-bioinformatician field technicians turn a local folder
of BAM files, a VCF, and a TSV metadata file into the two `.rds` files
microhaplot's "Data Set" tab consumes, by wrapping the already-shipped BAM
support in `prepHaplotFiles()`. This map ends in a decision set ready to
hand to `/to-spec` — not working code.

## Notes

- Domain: R Shiny, amplicon-sequencing genotyping. Same package/repo as
  microhaplot v1 (`ltalignani/microhaplot-2`), not the microhaplot2
  rewrite (separate, isolated repo).
- Runs entirely locally on the technician's machine — no server/HPC
  deployment, no browser-upload of large file sets (established constraint
  from the prior BAM-input effort, see `notes/2026-07-24-bam-input-decision.md`).
- Target users: non-bioinformatician field technicians genotyping
  thousands of mosquito samples per campaign.
- Skills to consult when resolving tickets: `/grilling` and
  `/domain-modeling` for remaining decisions, `/prototype` for UI mockups.
- Decision-only destination — do not implement in this map.

## Decisions so far

- [Second Shiny app lives in the v1 repo](issues/01-second-app-location.md) — bundled in `ltalignani/microhaplot-2`, calls `prepHaplotFiles()` directly rather than duplicating extraction logic.
- [Metadata file format is TSV](issues/02-metadata-format.md) — `bam_file, individual_id, group`, consistent with the existing tab-separated `label.txt` convention.
- [BAM input via local folder path, not per-file upload](issues/03-bam-input-mechanism.md) — consistent with the no-browser-upload constraint from the prior BAM-input effort.
- [No automatic handoff to microhaplot](issues/04-output-handoff.md) — static success message with next-step info; the two apps stay separate Shiny processes.
- [Upfront batch validation before extraction](issues/05-validation-scope.md) — BAM existence check, VCF↔BAM chromosome-name comparison, truncated-file detection (`samtools quickcheck`), all run before any extraction starts.
- [Progress feedback via intermed/*.summary polling](issues/06-progress-feedback.md) — no changes to `prepHaplotFiles()` needed; poll the count of `.summary` files it already produces.
- [No run history in this app](issues/07-run-history.md) — microhaplot's own Data Set tab already lists available `.rds` files.
- [n.jobs hidden, auto-detected](issues/08-njobs-exposure.md) — via `parallel::detectCores()`, not exposed to the user.
- [UI language is English](issues/09-ui-language.md) — matches the existing microhaplot app.
- [VCF via simple fileInput per run](issues/10-vcf-reuse.md) — no VCF library/reuse mechanism in this effort.
- [Folder picker uses shinyFiles](issues/11-folder-picker-mechanism.md) — purpose-built, cross-platform, stays in-browser; HTML5 `webkitdirectory`, `rstudioapi`, and `tcltk` all ruled out for this audience/setup.
- [Async execution via future/promises](issues/12-async-execution-architecture.md) — `prepHaplotFiles()` wrapped whole in a `future` (`plan(multisession)`), no changes inside it; main Shiny session stays free to poll for progress. Standard RStudio/Posit pattern for long-running Shiny tasks.
- [TSV schema: header row + 4 columns](issues/13-tsv-schema-detail.md) — `bam_file, individual_id, group, color` (optional), header required, downloadable template, validation rules for each column.
- [Chromosome comparison via VCF CHROM column vs union of BAM @SQ headers](issues/14-chromosome-comparison-mechanism.md) — piggybacks on the existing per-BAM truncation-check pass; reports missing VCF contigs and affected-BAM count.
- [UI is a linear step-gated wizard](issues/15-ui-wireframe.md) — chosen over a single-scroll page and a persistent-sidebar layout after an interactive 3-variant prototype review; reference implementation kept at `prototype/app.R`.

## Not yet specified

- Whether/how to support cancelling a long-running extraction once started.
- Performance characteristics of the chosen truncation/chromosome-check approach at genuinely large scale (thousands of BAM files) — may need empirical testing once the mechanism is chosen.
- Package/function naming and app entry-point wiring (e.g. an exported `runShinyHaplotPrep()`-style launcher) — likely falls out naturally during implementation planning rather than needing its own decision.

## Out of scope

- Initial installation/dependency bootstrapping and alternative packaging (standalone executable, Docker image) for non-technical users — deferred to a future Docker-based effort.
- Reference-amplicon-panel comparison / genotyping-by-comparison workflow (users' data compared against a shared reference panel for identification and genotyping) — a distinct, larger future feature, not part of this destination.
