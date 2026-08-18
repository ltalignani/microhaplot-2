# hapture golden regression fixtures

Recorded output of `inst/perl/hapture` — the fatpacked binary
`prepHaplotFiles()` actually invokes, not the raw `hapture.pl` source — on
known inputs, captured before any Rust work started on
[wayfinder map #18](https://github.com/ltalignani/microhaplot-2/issues/18).

No prior test compared `hapture.pl`'s output to an independent oracle;
`tests/testthat/test-prep-extraction-integration.R` only checks that the R
function's return value matches what the same run just wrote to disk. This
directory is that missing oracle: what a Rust reimplementation's output must
match, canonicalized, to be considered behavior-preserving.

## Contents

- `sebastes-all.summary` — the bundled 20-sample `sebastes_sam.tar.gz`
  fixture run through `hapture` against `sebastes.vcf`, concatenated and
  sorted. 616 rows.
- `sebastes-per-sample/<id>.summary` — the same run, one sorted file per
  sample, for isolating which sample a future implementation diverges on
  without re-deriving it from the concatenated file.
- `edge-cases.sam` / `edge-cases.summary` — two hand-built pathological
  reads real sequencing data doesn't produce: a secondary-alignment read
  (SAM flag 256) and a 1-base query. Both must be skipped outright;
  `edge-cases.summary` is empty (0 rows) by design.
- `capture-golden-fixtures.sh` — regenerates the above from scratch. Run for
  provenance or disaster recovery only — **not** to "refresh" these files
  after a behavior change, which would defeat their purpose as a fixed
  baseline. See the script's own header for why.

## What the bundled sebastes fixture already covers

Chosen because, with no synthetic input needed, it already exercises:

- plain SNP resolution (the bulk of the 616 rows);
- **N** marking — a variant position beyond a read's aligned reference span
  (8 occurrences);
- **X** marking — a deletion overlapping a variant site (12 occurrences);
- VCF filtering of the 2 multi-allelic and 2 indel sites out of 56 total
  (54 SNP-only sites make it into the output).

What it does *not* cover, and why that's fine here: BAM input and gzipped
VCF are both handled by shell-level piping into `hapture`'s `-s`/`-v`
arguments (`samtools view -h |`, `gunzip -c |`) — plumbing in
`prepHaplotFiles()`, not in `hapture.pl`'s own per-read logic — and are
already covered by `test-prepHaplotFiles-bam.R` and
`test-prepHaplotFiles-gzip-vcf.R`.

## Row order is not part of the behavior being pinned

Perl's hash key iteration order is randomized per process: running `hapture`
twice on identical input produces the same *set* of rows in a different
order each run (confirmed while building these fixtures). Every file here is
canonicalized with a whole-line `sort` before being written — confirmed
well-defined, since (group, individual, locus, haplotype) is unique across
the full sebastes output (0 duplicate keys). Any future comparison — a
microhaplot-extract run, a re-capture, anything — must sort its own output
the same way before diffing against these files; comparing raw, unsorted
output will show spurious differences that are really just reordering.
