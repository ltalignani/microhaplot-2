Status: ready-for-agent

# Accept BAM input in `prepHaplotFiles()`

## Problem Statement

`microhaplot`'s haplotype-extraction entry point, `prepHaplotFiles()`, only
accepts sequence alignments as plain-text SAM files. The Perl script it
drives, `hapture`, opens the file given by its `-s` argument and parses it
line by line — it has no BAM awareness at all.

Users who already have their reads aligned and stored as BAM (the normal
output of any modern aligner + `samtools sort`) must first convert every
file to SAM by hand before they can run `prepHaplotFiles()`. For a large
amplicon panel — the motivating case here has ~660 individual BAM files,
~25 MB each — converting all of them to flat SAM text ahead of time would
multiply their on-disk footprint 3–10×, turning ~16.5 GB of BAM into
50–150 GB of temporary SAM files. That's the actual blocker: not that BAM
can't be read, but that the obvious way to make it readable is wasteful at
this scale, on a local machine with no server/HPC storage to absorb it.

## Solution

Teach `prepHaplotFiles()` to accept BAM files directly in its `sam.path` /
`label.path` inputs, transparently alongside the SAM files it already
supports — with no intermediate SAM file ever materialized on disk, and no
change to `hapture.pl` itself.

The mechanism: Perl's two-argument `open` treats a filename string ending
in `|` as a shell command to execute, streaming its stdout as the file's
contents. `hapture.pl` already reads its input as a single forward pass
(`open SAM, $opt{s}; while (<SAM>) {...}`), so if `prepHaplotFiles()`
passes it `"samtools view -h /path/to/sample.bam |"` instead of a plain SAM
path when a row's file is a `.bam`, the script needs no modification at
all — it will stream the SAM-formatted output of `samtools view` exactly as
if it were reading a real SAM file, with memory and disk usage flat
regardless of file count or size.

Full-file streaming via `samtools view -h` does not require a `.bai` index
(only region-restricted queries do), so users do not need to pre-index
their BAMs either.

## User Stories

1. As a microhaplot user with a large panel of already-aligned BAM files, I want to call `prepHaplotFiles()` pointing directly at my BAMs, so that I don't have to hand-convert hundreds of files to SAM first.
2. As a microhaplot user with 660 BAM files of ~25 MB each, I want the conversion to not blow up my local disk with temporary SAM files, so that I can run the extraction on my own machine without provisioning extra storage.
3. As an existing microhaplot user with a `.sam`-based `label.txt` and scripts built around today's `prepHaplotFiles()` signature, I want my existing workflow to keep working unchanged, so that this change doesn't break anything I already have running.
4. As a microhaplot user with a mix of `.sam` and `.bam` files across the same run, I want `prepHaplotFiles()` to handle both correctly based on each file's extension, so that I don't have to pre-sort my inputs by format.
5. As a microhaplot user, I want a clear error message if `samtools` isn't installed or isn't on my `PATH`, so that a missing dependency doesn't fail silently or produce a cryptic Perl error.
6. As a microhaplot maintainer, I want the BAM-handling logic to live inside the existing `prepHaplotFiles()` function rather than a new parallel function, so that there's a single documented entry point and no API surface to keep in sync.
7. As a microhaplot user running on Windows, I want to know explicitly that BAM input isn't supported on my platform yet (rather than have it silently fail), so that I'm not left debugging an unsupported code path.
8. As a microhaplot maintainer, I want an automated test that proves BAM and SAM input produce identical extraction results for the same underlying reads, so that I have confidence the piped path is behaviorally equivalent to the existing one before shipping it.

## Implementation Decisions

- **Module touched**: `prepHaplotFiles()` in `R/runHaplot.R`. `inst/perl/hapture.pl` / the packed `inst/perl/hapture` binary are **not** modified — the piped-input trick works entirely from the calling side.
- **Per-row format detection**: for each row of the label file (SAM/BAM filename, individual ID, group), `prepHaplotFiles()` inspects the file extension of column 1. `.sam` (case-insensitive) keeps today's behavior — the plain file path is passed as `hapture`'s `-s` argument. `.bam` (case-insensitive) instead builds the `-s` argument as a piped `samtools view -h` command over that file's path.
- **No new function, no signature change**: the existing `prepHaplotFiles(run.label, sam.path, label.path, vcf.path, out.path, add.filter, app.path, n.jobs)` signature is unchanged. The `sam.path` parameter's role — "directory containing all sequence alignment files" — now covers both SAM and BAM files by extension.
- **`samtools` dependency check**: `prepHaplotFiles()` already checks the system Perl version before running and messages clearly if it's missing/outdated (see the existing `perl -v` / `perl.version` check). Add an equivalent check for `samtools` on `PATH` — only required/checked when at least one `.bam` row is present in the label file — that stops with a clear error message (mirroring the existing Perl-version error) if `samtools` can't be found, rather than letting the pipe silently fail inside Perl.
- **No `.bai` index requirement**: since extraction only ever does a full linear `samtools view -h` over each file (no region queries), BAM files do not need to be indexed before use.
- **Parallelism (`n.jobs`)**: the existing parallel-execution model — writing one `hapture.pl` invocation per row into a generated shell script, backgrounded and `wait`-ed on in batches of `n.jobs` — is unaffected by this change. Each backgrounded `hapture.pl` process spawns its own `samtools view` subprocess when reading a `.bam` row; this composes the same way plain-file rows do today.
- **Windows**: the existing Windows branch (which builds a `runHapture.bat` instead of a bash script) is left untouched and is not extended to support the piped-BAM case in this effort — see Out of Scope.

## Testing Decisions

- A good test here proves **behavioral equivalence**: that extracting from a BAM produces the same haplotype table as extracting from the equivalent SAM, not that any particular internal function was called. Test through the public `prepHaplotFiles()` entry point end-to-end — this package has no unit-test infrastructure today and validates itself via runnable roxygen `@examples` that exercise the full pipeline; this is the existing prior art and this feature follows the same shape rather than introducing a new testing style.
- **Fixture**: derive from the existing `inst/extdata/sebastes_sam.tar.gz` (SAM files + `label.txt` + `sebastes.vcf`, already used by the current `@examples` blocks). For a subset of its sample SAM files, generate the equivalent BAM with `samtools view -bS s6.sam > s6.bam` (etc.) as part of test setup — no new sequencing data needs to be sourced.
- **The core test**: run `prepHaplotFiles()` twice against the same underlying reads and VCF — once with a label file pointing at the original `.sam` files, once with a label file pointing at the derived `.bam` files for the same samples — and assert the two resulting `.rds`/data frames are identical (same rows, same columns, same values).
- **Secondary tests**: a mixed label file (some `.sam` rows, some `.bam` rows in the same run) produces the union of both correctly; a missing-`samtools` scenario (e.g. with `PATH` stubbed to exclude it) produces the clear error message described above rather than a silent failure or a raw Perl error.
- This work also requires bootstrapping test infrastructure that doesn't yet exist in this repo: adding `testthat` to `Suggests` in `DESCRIPTION` and creating a `tests/testthat/` directory, since there is no existing test suite to extend.

## Out of Scope

- **Windows support for BAM/piped input.** The existing `.bat`-based Windows code path in `prepHaplotFiles()` is not extended to handle `.bam` rows. Windows users remain on the `.sam`-only path; this can be revisited as a separate effort if needed.
- **Rewriting the extraction engine in R/Rsamtools** (mirroring the approach used in the separate `microhaplot2` rewrite's `extraction.R`). Explicitly rejected in favor of the minimal-change streaming-pipe approach — `hapture.pl` stays as-is.
- **Any change to the Shiny app's "Data Set" tab UI** (`inst/shiny/microhaplot/ui.R`). This spec covers only the R-console-facing `prepHaplotFiles()` conversion step; the tab continues to just list `.rds` files already present in the app directory, unchanged.
- **Region-restricted / indexed BAM reading.** Only full linear streaming is in scope; no support for reading a subset of reads via an index.

## Further Notes

- This spec is scoped to `microhaplot` v1 (the `ltalignani/microhaplot-2` fork of `ngthomas/microhaplot`), not the separate `microhaplot2` rewrite (`ltalignani/microhaplot2`), which already has independent, unrelated BAM-reading support in its own extraction module.
- Once implemented, `vignettes/microhaplot-data-prep.Rmd` and `README.md` should be updated to document BAM as a supported `sam.path` entry type — not required for the code change itself to be complete, but should land in the same effort so the docs don't go stale.
- Decision context and rationale were captured in full during a prior grilling session; see `notes/2026-07-24-bam-input-decision.md` in this repo for the original discussion trail.
