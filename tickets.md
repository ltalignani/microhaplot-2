# Tickets: Accept BAM input in prepHaplotFiles()

Breaks down the spec at `.scratch/bam-input-prephaplotfiles/PRD.md` — teaching
`prepHaplotFiles()` to accept BAM files (streamed through `samtools view -h`
via Perl's piped-open idiom, no `hapture.pl` changes, no intermediate SAM
files) alongside the SAM files it already supports.

Work the **frontier**: any ticket whose blockers are all done. This chain is
linear — top to bottom.

## Support BAM input in prepHaplotFiles()

**What to build:** `prepHaplotFiles()` accepts `.bam` rows in its
`label.txt` in addition to the `.sam` rows it already supports, detected by
file extension. For `.bam` rows, it streams the file through `samtools view
-h` (piped into Perl's `open`, per the spec's mechanism) instead of passing
a plain file path — no intermediate SAM file is ever written, and no `.bai`
index is required. A run with a mix of `.sam` and `.bam` rows in the same
label file works correctly. If `samtools` isn't on `PATH` and at least one
`.bam` row is present, `prepHaplotFiles()` stops with a clear error message
(mirroring the existing Perl-version check), rather than failing silently
or surfacing a raw Perl error. `hapture.pl` itself is unmodified; the
function signature of `prepHaplotFiles()` is unchanged.

This repo has no test infrastructure today — bootstrapping it (`testthat`
added to `DESCRIPTION`'s `Suggests`, a `tests/testthat/` directory) is part
of this ticket, not a separate one.

**Blocked by:** None — can start immediately

- [ ] `.bam` rows in `label.txt` are detected by extension (case-insensitive) and routed through a piped `samtools view -h` command; `.sam` rows continue to work exactly as before
- [ ] No intermediate `.sam` file is ever written to disk for a `.bam` input, and no `.bai` index is required
- [ ] A label file mixing `.sam` and `.bam` rows in the same run produces correct combined output
- [ ] Missing `samtools` on `PATH` (when at least one `.bam` row is present) produces a clear, explicit error message rather than a silent failure or raw Perl error
- [ ] `testthat` is added to `DESCRIPTION`'s `Suggests` and a `tests/testthat/` directory exists
- [ ] A `.bam` test fixture is derived from the existing `inst/extdata/sebastes_sam.tar.gz` SAM fixture (e.g. via `samtools view -bS`) for a subset of samples
- [ ] An automated test proves behavioral equivalence: running `prepHaplotFiles()` against `.sam` files and against the equivalent derived `.bam` files (same underlying reads, same VCF) produces identical resulting data (same rows, columns, values)

## Document BAM support in the vignette and README

**What to build:** `vignettes/microhaplot-data-prep.Rmd` and `README.md`
describe BAM as a supported entry type in `sam.path`/`label.txt`, with an
example reflecting the actual behavior shipped in the prior ticket
(extension-based detection, no indexing required, `samtools` as a new
runtime dependency for BAM users).

**Blocked by:** Support BAM input in prepHaplotFiles()

- [ ] `vignettes/microhaplot-data-prep.Rmd` documents BAM as an accepted `sam.path` entry type, with a worked example
- [ ] `README.md` mentions BAM support and the new `samtools` runtime dependency for users relying on it
- [ ] Docs do not claim Windows support for BAM input (explicitly out of scope per the spec)
