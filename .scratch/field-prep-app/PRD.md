Status: ready-for-agent

# Field genotyping prep app

## Problem Statement

microhaplot's existing pipeline turns aligned reads (SAM, and now BAM) plus
a VCF into the `.rds` files its Shiny visualization app consumes — but
getting there means calling `prepHaplotFiles()` from an R console, hand-
writing a tab-separated `label.txt`, and reading R error messages when
something's wrong. That's a reasonable workflow for a bioinformatician,
but the next users of this pipeline are field technicians genotyping
thousands of mosquito samples per campaign, with no bioinformatics
background. They have a folder of BAM files and a VCF in hand; they have
no way to turn that into something microhaplot can open.

## Solution

A second Shiny app, bundled alongside microhaplot's existing visualization
app in the same R package, purpose-built for this handoff: point it at a
local folder of BAM files, upload a metadata TSV and a VCF, and it
validates everything up front, runs the extraction (wrapping the existing
`prepHaplotFiles()`), and reports success with the location of the two
`.rds` files microhaplot needs — all through a guided, step-by-step
interface that assumes no bioinformatics knowledge.

## User Stories

1. As a field technician, I want to point the app at the folder on my computer containing my BAM files, so that I don't have to upload each of potentially thousands of files individually.
2. As a field technician, I want to fill in a metadata TSV with a clear template I can download, so that I know exactly what information the app needs and in what format.
3. As a field technician, I want the app to check that every BAM file my metadata TSV refers to actually exists in the folder I selected, so that I find out about a missing file before I wait hours for an extraction to fail partway through.
4. As a field technician, I want the app to warn me if my VCF's chromosome names don't match my BAM files' reference names, so that I catch a wrong-reference-genome mistake immediately instead of getting an empty result.
5. As a field technician, I want the app to detect corrupted or truncated BAM files before starting extraction, so that a bad file from a flaky transfer doesn't silently produce wrong results.
6. As a field technician, I want to see all validation problems at once before extraction starts, so that I can fix everything in one pass instead of discovering issues one at a time.
7. As a field technician, I want a visible progress indicator while extraction runs, so that I know the app is working and roughly how far along it is, rather than staring at a frozen screen for a long batch.
8. As a field technician, I want the app's interface to stay responsive while extraction runs in the background, so that I'm not left wondering if it has crashed.
9. As a field technician, I want a clear success message telling me where my output files are and what to do next, so that I know how to move on to microhaplot itself.
10. As a field technician, I want to move through the process one step at a time (select folder, then upload files, then review validation, then extract, then done), so that I'm never presented with more decisions than I can handle at once.
11. As a field technician, I want an optional color column in my metadata TSV, so that I can control how my groups are color-coded in microhaplot without extra steps later.
12. As a field technician, I want group labels to be optional in my metadata, so that I can still process my data before I've decided on group assignments.
13. As a package maintainer, I want this new app to call the existing, already-tested `prepHaplotFiles()` rather than reimplementing extraction, so that BAM/SAM handling logic lives in exactly one place.
14. As a package maintainer, I want the app's validation logic to be pure functions decoupled from Shiny, so that it can be unit tested directly without a running Shiny session.
15. As a package maintainer, I want the number of parallel extraction threads chosen automatically, so that non-technical users are never asked to make a decision they have no basis to judge.
16. As a package maintainer, I want this app kept in the same repository as microhaplot v1 rather than a new one, so that installation stays a single step for the field user and extraction logic isn't duplicated.

## Implementation Decisions

- **Location**: a second Shiny app bundled under `inst/shiny/` in the microhaplot v1 package (`ltalignani/microhaplot-2`), parallel to the existing `inst/shiny/microhaplot` app, installed via the same package. Not a new repository, and not part of the separate `microhaplot2` rewrite.
- **Core dependency**: the app calls the existing, unmodified `prepHaplotFiles()` (already extended to accept BAM input) as its extraction engine. No extraction logic is reimplemented.
- **BAM input**: a local folder path, selected via `shinyFiles::shinyDirButton()`/`shinyDirChoose()` — not a per-file browser upload (`fileInput`/`webkitdirectory`), which was ruled out for batches of potentially thousands of files. `shinyFiles` was chosen over `rstudioapi::selectDirectory()` (requires RStudio, too fragile as a primary mechanism) and `tcltk::tk_choose.dir()` (native dialog can open behind the browser window, a real confusion risk for this audience) because it's purpose-built for browsing a locally-run Shiny app's own filesystem, is cross-platform, and stays inside the browser window.
- **Metadata format**: a TSV, not CSV, uploaded via a plain `fileInput` — consistent with `prepHaplotFiles()`'s existing tab-separated `label.txt` convention, though the two formats are not identical (see schema below). A header row is required in the user-facing TSV (diverging from the internal, headerless `label.txt` that the app generates from it) — friendlier for a file most technicians will prepare in a spreadsheet tool. A downloadable template (pre-filled header row) is provided in the app, mirroring the equivalent pattern already used in the microhaplot2 rewrite's metadata CSV template.
  - Columns, in order: `bam_file` (filename as it appears in the selected folder, not a full path; required, non-empty), `individual_id` (required, non-empty, must be unique across rows), `group` (may be empty or `"NA"`, matching the existing `label.txt` convention), `color` (optional; if present, must be empty or a valid `#RRGGBB` hex value).
  - The app translates the validated TSV into `prepHaplotFiles()`'s internal headerless `label.txt` format before calling it.
- **VCF input**: a plain `fileInput`, uploaded fresh on every run. No VCF library or reuse-across-campaigns mechanism in this app (see Out of Scope).
- **Validation**: runs as a single upfront batch pass, after the folder, TSV, and VCF have all been provided and before any call to `prepHaplotFiles()` — not discovered lazily mid-extraction. Checks:
  - Every `bam_file` referenced in the TSV exists in the selected folder.
  - Every BAM file passes `samtools quickcheck` (detects truncated/corrupted files via BGZF EOF integrity, without full decompression).
  - VCF chromosome names (read from the VCF's CHROM data column — not `##contig` header lines, matching how `prepHaplotFiles()` itself already derives locus/position info, and more robust since some VCFs, including the package's own `sebastes.vcf` fixture, have no `##contig` lines at all) are compared against the union of all BAM files' `@SQ` reference names (read via `samtools view -H`, piggybacked onto the same per-BAM pass as the truncation check, so no extra file reads are needed). A VCF chromosome name absent from that union is reported as a mismatch, listing the missing names and how many BAM files are affected. The reverse (a BAM referencing more sequences than the VCF uses) is not an error.
  - All results (passes, warnings, and blocking errors) are shown together on a single validation step, not one at a time.
- **Extraction execution**: the whole `prepHaplotFiles()` call is wrapped in a `future` (`future`/`promises` packages, `future::plan(multisession)`), run as an opaque background call with no internal modification. This keeps the Shiny session's UI responsive while extraction runs, since it executes in a separate background R worker process on the same machine (no server infrastructure). `n.jobs` (`prepHaplotFiles()`'s parallel-thread parameter) is not exposed in the UI; it's set automatically via `parallel::detectCores()` (with a safety margin).
- **Progress feedback**: a progress bar driven by polling the count of `*.summary` files in `prepHaplotFiles()`'s `intermed/` output directory, compared against the expected total sample count — this works because `prepHaplotFiles()` already produces exactly one `.summary` file per processed SAM/BAM row, and filesystem polling from the main Shiny session is independent of whichever process is blocked running the extraction. No changes to `prepHaplotFiles()` are needed for this.
- **UI structure**: a linear, step-gated wizard (chosen via an interactive 3-variant prototype review — a single-scroll page and a persistent-sidebar layout were both built and rejected in favor of the wizard's lower per-screen cognitive load). Five steps, one visible at a time, with a step indicator and forward/back navigation: (1) Select folder, (2) Upload files [TSV + VCF], (3) Validate, (4) Extract, (5) Done. A structural reference implementation of this wizard (UI shell only, no real backend wiring) exists at `.scratch/field-prep-app/prototype/app.R`.
- **Output handoff**: on success, the app shows a static message reporting where the two output files were written and instructs the user to open microhaplot separately. It does not launch microhaplot automatically — the two apps remain separate Shiny processes.
- **No run history**: this app does not show a list of previously produced runs. microhaplot's own "Data Set" tab already lists every `.rds` file present in `app.path`, so prior runs remain visible there.
- **UI language**: English, matching the existing microhaplot app.
- **Validation module**: the checks above live in a set of pure R functions (e.g. `validate_prep_inputs(folder, tsv_df, vcf_path)` returning a structured `list(ok, errors, warnings)`), fully decoupled from Shiny — this is the seam this spec's tests target. The Shiny module itself (wizard steps, `shinyFiles` integration, `future`/`promises` orchestration, progress polling) is a thin layer around this module and is not the target of detailed automated testing.

## Testing Decisions

- The single test seam is the pure validation module described above (`validate_prep_inputs()` and its component checks) — tested directly with `testthat`, extending the test infrastructure already bootstrapped for `prepHaplotFiles()`'s BAM support (`tests/testthat/`).
- A good test here proves the validation module's external behavior — given a folder of BAM files, a parsed TSV, and a VCF path, does it report the right errors/warnings/passes — not its internal implementation. Tests should not require a running Shiny session.
- Fixtures: derive from the same `inst/extdata/sebastes_sam.tar.gz`-based BAM/VCF fixtures already used for `prepHaplotFiles()`'s BAM equivalence tests, extended with deliberately broken cases: a TSV row referencing a missing BAM filename, a truncated BAM file, and a VCF with a chromosome name absent from the BAM references — each should produce the expected error/warning without needing a real large-scale dataset.
- Prior art: `tests/testthat/test-prepHaplotFiles-bam.R` (fixture derivation pattern, `samtools`-based setup) and, conceptually, microhaplot2's `validate_metadata_csv()`/`resolve_bam_paths()` tests (pure-function validation separated from its Shiny module) — not shared code, since the two repos are isolated, but the same architectural pattern.
- The Shiny orchestration layer (wizard navigation, `shinyFiles`, `future` wrapping, progress-bar polling) is not covered by automated tests in this spec; manual verification against the reference prototype's flow is expected instead.

## Out of Scope

- **Initial installation/dependency bootstrapping and alternative packaging** (standalone executable, Docker image) for non-technical users. Deferred to a future Docker-based effort; this app assumes R, Perl, `samtools`, and the package's R dependencies are already installed by someone technical.
- **Reference-amplicon-panel comparison / genotyping-by-comparison workflow** — a future direction where users' data would be compared against a shared reference panel for identification and genotyping. A distinct, larger feature, not part of this app.
- **VCF reuse/library mechanism** across campaigns — every run uploads its VCF fresh via a plain `fileInput`.
- **Run history** — no list of previously produced runs inside this app.
- **Cancelling a running extraction** once started.
- **Automatic handoff into microhaplot** — the app reports success and stops; opening microhaplot is a separate, manual step.
- **Windows support for BAM input** — inherited from `prepHaplotFiles()`'s existing BAM support, which explicitly does not cover Windows.

## Further Notes

- This spec builds directly on the wayfinder map "Field genotyping prep app" (`.scratch/field-prep-app/map.md`) and its 15 resolved tickets, which hold the full rationale behind each decision above.
- Two items were deliberately left open by that map rather than decided here, and remain open for whoever implements this spec: (1) the exact package/function naming for this app's entry point (e.g. an exported `runShinyHaplotPrep()`-style launcher, mirroring `runShinyHaplot()`) — expected to fall out naturally during implementation; (2) empirical performance characteristics of the `samtools quickcheck`/`@SQ`-comparison validation pass at genuinely large scale (thousands of BAM files) — worth a quick sanity check with a realistically large fixture during implementation, though the mechanism itself (header-only reads) is expected to be fast.
- The reference wizard UI at `.scratch/field-prep-app/prototype/app.R` is explicitly throwaway/reference code (fake data, no real backend wiring) — a real implementation should be written fresh against this spec's decisions, not extended in place.
