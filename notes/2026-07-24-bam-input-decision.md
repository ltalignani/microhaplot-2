# Decision: accepting BAM input in `prepHaplotFiles()`

## Context

`microhaplot` v1's extraction pipeline (`prepHaplotFiles()` → Perl `hapture.pl`)
only accepts plain-text SAM files: `hapture.pl` does `open SAM, $opt{s}; while
(<SAM>) {...}` — a single-pass, line-by-line parse with no seek/rewind and no
buffering into memory. Today's workflow requires the user to have already
converted their aligned reads to SAM (typically via `bwa mem ... > *.sam`)
before calling `prepHaplotFiles()`.

The user's actual data: ~660 BAM files (one per individual, ~25 MB each,
amplicon panel), already aligned, plus a corresponding VCF defining the
target SNP positions. Goal: let `prepHaplotFiles()` accept these BAM files
directly, without a separate manual conversion step.

Runs entirely locally (not a server/HPC deployment) — a `Shiny` app run on
the user's own machine.

## Decisions

1. **Extraction mechanism — streamed pipe, not a materialized SAM file.**
   Converting all 660 BAMs to flat `.sam` text first was considered and
   rejected: SAM text is typically 3–10× the size of compressed BAM, so 660
   × 25 MB could produce 50–150 GB of temporary files. Instead, exploit
   Perl's two-argument `open` idiom: a filename argument ending in `|` is
   executed as a shell command and its output streamed in, e.g. `open SAM,
   "samtools view -h sample.bam |"`. `hapture.pl` needs **no changes** — it
   already reads line-by-line — only the R wrapper needs to construct this
   piped command instead of a plain file path when the input is a BAM. No
   intermediate file is ever written; memory/disk usage stays flat
   regardless of file count.

   Full-file streaming via `samtools view -h` does not require a `.bai`
   index (only region-restricted queries do), so no pre-indexing step is
   needed either.

2. **Architecture — independent module, not a Shiny UI change.**
   The conversion stays a function called from the R console (as
   `prepHaplotFiles()` is used today), producing a `.rds` file that the
   existing "Data Set" tab (`ui.R:186`, a `selectInput` over `.rds` files
   already present in the app directory) picks up unchanged. No new
   upload/import module is added to the Shiny app in this effort.

3. **Backward compatibility — both `.sam` and `.bam` accepted.**
   Per-file format is detected by extension in `label.txt` (already a
   tab-separated file listing filename / individual ID / group per row —
   no format change needed there). `.sam` entries continue to be opened
   directly as today; `.bam` entries get the piped `samtools view -h`
   treatment. Existing callers with `.sam`-based label files are
   unaffected.

4. **API — modify `prepHaplotFiles()` in place.**
   No new function name (e.g. no `prepHaplotFilesV2`). Since the change is
   fully backward-compatible and the function signature doesn't need to
   change, there's no reason to introduce a parallel API to maintain.

## Out of scope

- **Windows support for BAM/pipe input.** `prepHaplotFiles()` currently
  generates a `runHapture.bat` on Windows via a separate code branch. This
  effort does not extend that branch to handle the piped-BAM case — Windows
  users remain on the `.sam`-only path for now. Revisit as a separate
  effort if the need arises.
- **Rewriting the extraction engine in R/Rsamtools** (mirroring
  microhaplot2's `extraction.R`). Rejected in favor of the minimal-change
  streaming-pipe approach (decision 1), which fully addresses the
  memory/disk concern without abandoning the Perl engine.

## Next steps (not yet implemented)

- Modify `prepHaplotFiles()` (`R/runHaplot.R`) to detect `.bam` vs `.sam`
  by extension per label-file row and construct the `-s` argument
  accordingly (piped `samtools view -h` command for `.bam`, plain path for
  `.sam`).
- Add a `samtools`-on-`PATH` check (mirroring the existing Perl-version
  check) with a clear error message if missing.
- Add a small BAM test fixture (e.g. a handful of reads against the
  existing `sebastes.vcf`/`sebastes_sam.tar.gz` reference) to validate the
  piped path end-to-end.
- Update `vignettes/microhaplot-data-prep.Rmd` and `README.md` to document
  BAM as a supported `sam.path` entry type.
