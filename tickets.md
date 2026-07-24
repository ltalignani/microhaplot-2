# Tickets: Field genotyping prep app

Builds the field genotyping prep app described in
`.scratch/field-prep-app/PRD.md` — a second Shiny app, bundled alongside
microhaplot's existing visualization app, that lets non-bioinformatician
field technicians turn a local folder of BAM files, a VCF, and a metadata
TSV into the two `.rds` files microhaplot's Data Set tab consumes.

Work the **frontier**: any ticket whose blockers are all done. This chain
is linear — top to bottom.

## Wizard shell with folder and file selection

**What to build:** The app exists (scaffolded alongside the existing
microhaplot Shiny app in the same package, with its own launch entry
point) and its 5-step wizard is navigable end to end: a step indicator
across the top, and Next/Back controls that move between steps. Step 1
("Select folder") uses a real `shinyFiles` folder picker to choose a local
directory of BAM files. Step 2 ("Upload files") uses real `fileInput`s for
the metadata TSV and the VCF, plus a downloadable pre-filled TSV template
(header row: `bam_file`, `individual_id`, `group`, `color`). Steps 3
("Validate"), 4 ("Extract"), and 5 ("Done") render placeholder content for
now — their real behavior lands in later tickets. The selected folder path
and uploaded file references are held in shared wizard state that later
steps will read from.

**Blocked by:** None — can start immediately

- [ ] The 5-step wizard renders with a step indicator and Next/Back navigation matching the reference prototype's structure (`.scratch/field-prep-app/prototype/app.R`)
- [ ] Step 1 lets the user pick a real local folder via `shinyFiles`; the chosen path is held in wizard state and shown back to the user
- [ ] Step 2 accepts a TSV and a VCF via `fileInput`, and offers a downloadable template TSV with the header row `bam_file`, `individual_id`, `group`, `color`
- [ ] Steps 3–5 render placeholder ("coming soon") content without erroring
- [ ] The app has its own launch entry point, installed alongside the existing microhaplot Shiny app in the same package

## Validation module wired to step 3

**What to build:** A set of pure R functions (decoupled from Shiny) that
validate a run's inputs — this is the spec's single test seam. Given the
selected folder, the parsed TSV, and the VCF path, the module checks: (1)
every `bam_file` row exists in the folder and is non-empty/unique on
`individual_id`, with `group` optionally empty/`"NA"` and `color`
optionally empty or a valid `#RRGGBB` hex; (2) every referenced BAM file
passes `samtools quickcheck` (catches truncated/corrupted files); (3) the
VCF's CHROM column values are all present in the union of every BAM's
`@SQ` reference names (a VCF chromosome absent from that union is
reported, with the affected BAM count — the reverse is not an error).
Step 3 of the wizard calls this module on the real state captured in the
prior ticket and displays every pass, warning, and blocking error together
on one screen, not one at a time.

**Blocked by:** Wizard shell with folder and file selection

- [ ] A pure validation function (or small set of functions) exists, callable without a running Shiny session, returning a structured pass/warning/error result
- [ ] TSV schema rules are enforced: `bam_file`/`individual_id` required and non-empty, `individual_id` unique, `group` optionally empty/`"NA"`, `color` optionally empty or valid `#RRGGBB`
- [ ] Every referenced BAM's existence in the selected folder is checked
- [ ] Every referenced BAM passes (or fails) a `samtools quickcheck`-based truncation check
- [ ] VCF CHROM values are compared against the union of all BAM `@SQ` names; missing chromosomes are reported with the count of affected BAM files
- [ ] Step 3 of the wizard calls this module on real inputs and displays all results together
- [ ] Automated tests cover the validation module directly (happy path, missing BAM, truncated BAM, chromosome mismatch), using fixtures derived the same way as `tests/testthat/test-prepHaplotFiles-bam.R`

## Synchronous extraction end-to-end

**What to build:** Once validation passes, step 4 translates the
validated TSV into `prepHaplotFiles()`'s internal headerless `label.txt`
format and calls the real, unmodified `prepHaplotFiles()` with the
selected folder, VCF, and generated label file (with `n.jobs` chosen
automatically via `parallel::detectCores()`, not exposed in the UI). Step
5 shows a success message with the location of the two output `.rds`
files and tells the user to open microhaplot separately — no automatic
handoff. The UI is allowed to be unresponsive while extraction runs in
this ticket; responsiveness is the next ticket's job. The full flow
(folder → files → validation → extraction → success) now produces real
output files, verifiable by opening them.

**Blocked by:** Validation module wired to step 3

- [ ] The validated TSV is translated into `prepHaplotFiles()`'s headerless `label.txt` format correctly (row order, columns)
- [ ] Step 4 calls the real `prepHaplotFiles()` with the selected folder, TSV-derived label file, and uploaded VCF
- [ ] `n.jobs` is set automatically via `parallel::detectCores()` and is not an exposed UI control
- [ ] Step 5 reports the real paths of the two produced `.rds` files and does not attempt to launch microhaplot automatically
- [ ] Running the full wizard against a real BAM/VCF/TSV fixture produces the two `.rds` files with the expected content

## Async execution and progress bar

**What to build:** The `prepHaplotFiles()` call from the previous ticket
is wrapped whole in a `future` (`future`/`promises`, `future::plan(multisession)`),
run as an opaque background call with no changes inside `prepHaplotFiles()`
itself. Step 4 now shows a live progress bar driven by polling the count
of `*.summary` files in `prepHaplotFiles()`'s `intermed/` output directory
against the expected total sample count. The Shiny UI stays responsive
throughout — this is the final, spec-compliant version of the extraction
step.

**Blocked by:** Synchronous extraction end-to-end

- [ ] The `prepHaplotFiles()` call runs inside a `future` under `plan(multisession)`, without modifying `prepHaplotFiles()` itself
- [ ] Step 4 shows a progress bar that updates based on polling `intermed/*.summary` file counts while extraction runs in the background
- [ ] The wizard's UI (navigation, step indicator) remains responsive while extraction is in progress
- [ ] Step 5 is reached automatically once the background extraction resolves, showing the same success info as the prior ticket
