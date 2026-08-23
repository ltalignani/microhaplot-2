# Benchmark: microhaplot-extract vs. the Perl pipeline on a real dataset

Research for [wayfinder map #18](https://github.com/ltalignani/microhaplot-2/issues/18)
— ticket [#37](https://github.com/ltalignani/microhaplot-2/issues/37).

The bundled `sebastes` fixture (20 samples, 8 loci) is too small to say
anything meaningful about performance — it doesn't produce enough reads
per locus to stress either pipeline. This benchmark instead times both
pipelines against a real, production-scale dataset: the same one used for
[ticket #36](https://github.com/ltalignani/microhaplot-2/issues/36)'s
correctness validation, so the write-up below can point at the identical
9-sample subset, VCF, and result-agreement check rather than repeating
that work.

Because this is real (and possibly sensitive) research data, the dataset
is described only by its shape (sample count, VCF complexity) — no
population codes, sample IDs, or genotype content appear below or in any
committed file. The BAM/VCF/metadata inputs themselves are not part of
this repository.

## Methodology

- **Dataset**: 9 real BAM files spanning 3 population groups, against a
  real VCF of ~36,000 variant sites across 190 contigs (73 MB gzipped).
  Not the bundled `sebastes` toy fixture.
- **What's measured**: wall-clock time of the full `prepHaplotFiles()`
  call (not just raw extraction) — this is what a user actually waits on,
  and it's the same call both pipelines share, so it's an apples-to-apples
  comparison of the two backends `prepHaplotFiles()` can drive.
- **Hardware**: Apple M1 Pro, 10 cores, 32 GB RAM, macOS (Darwin 25.3.0,
  arm64).
- **Software**: R 4.5.0, samtools 1.15.1 (only needed by the Perl side),
  Perl 5.34.1, `microhaplot-extract` built in `--release` mode.
- **Concurrency**: `n.jobs = 9` for both runs (one worker per sample —
  the dataset's full sample count, so neither pipeline is left
  under-parallelized relative to the other).
- **Two checkouts, one script**: `scripts/benchmark-real-data-extraction.R`
  is checked into the repo and takes the dataset paths as arguments, so
  the exact same driver script times both pipelines. It was run once from
  a `git worktree` at
  [`45c6546`](https://github.com/ltalignani/microhaplot-2/commit/45c6546)
  (last commit before #36's cutover — Perl still present) and once from
  this branch's `HEAD` (the `microhaplot-extract` cutover).

### Reproducing this

```sh
# Perl baseline, from a worktree checked out at the pre-cutover commit
git worktree add /tmp/microhaplot-perl-worktree 45c6546
cd /tmp/microhaplot-perl-worktree
Rscript scripts/benchmark-real-data-extraction.R \
  --data-dir <path-to-bams> --label-tsv <path-to-metadata.tsv> \
  --vcf <path-to-vcf.gz> --out-dir /tmp/bench-perl \
  --run-label perl_bench --n-jobs 9

# microhaplot-extract, from this branch
cd /path/to/microhaplot
MICROHAPLOT_EXTRACT_BIN=$(pwd)/rust/microhaplot-extract/target/release/microhaplot-extract \
Rscript scripts/benchmark-real-data-extraction.R \
  --data-dir <path-to-bams> --label-tsv <path-to-metadata.tsv> \
  --vcf <path-to-vcf.gz> --out-dir /tmp/bench-rust \
  --run-label rust_bench --n-jobs 9
```

`--label-tsv` is the field prep wizard's 4-column metadata format
(`bam_file`, `individual_id`, `group`, `color`).

## Results

| Pipeline | Wall-clock time | Speedup |
|---|---|---|
| Perl (`hapture.pl`, commit 45c6546) | 367.6 s | 1x (baseline) |
| `microhaplot-extract` (this branch) | 30.7 s | **~12x** |

Both runs produced the same result: 34,924 rows, 9 individuals, 190 loci.
Canonicalizing (sorting) the raw extraction columns from both runs'
output and comparing them confirmed the two are identical — the same
check ticket #36 already established, repeated here alongside the timing
for completeness.

## Interpretation

The ~12x figure is specific to this dataset's shape (amplicon panel,
190 loci, real per-sample read depth and haplotype diversity) and this
machine; it is not a universal constant. It is, however, consistent with
the ~13x measured on the same subset during #36's independent validation
run (measured separately, with a different `n.jobs` value and a
freshly-rebuilt binary) — the two measurements agree closely enough to
trust the order of magnitude. The speedup comes from two sources that
this benchmark doesn't separate: native BAM decoding (vs. Perl parsing
`samtools view` text output) and avoiding a fresh Perl process launch per
sample.
