# #3 — Moteur d'extraction Rsamtools (remplacement Perl hapture)

## What to build

Replace the Perl `hapture` script with a pure-R extraction engine based on Rsamtools (Bioconductor). This module is the computational core of microhaplot2.

End-to-end: given a set of indexed BAM files, a VCF defining microhaplotype loci positions, and a metadata table (individual ID, group), the engine returns a tidy tibble with columns: `group`, `id`, `locus`, `haplo`, `depth`, `allele.balance`, `rank`.

Key elements:
- Read VCF locus coordinates with `VariantAnnotation::readVcf()` to build a `GRanges` of target regions.
- For each BAM file, use `Rsamtools::scanBam()` with `ScanBamParam(which = regions)` to fetch only reads overlapping the target loci.
- Parse CIGAR strings to reconstruct haplotype sequences at each locus.
- Compute `allele.balance` (depth / max_depth per locus per individual) and `rank` (1 = most abundant haplotype).
- Parallelise across BAM files using `BiocParallel::bplapply()`.
- Expose the logic as pure R functions (no Shiny dependency) to enable unit testing in isolation.
- Convert the `sebastes` SAM test data in `inst/extdata/` to indexed BAM to serve as reference test fixtures.

## Acceptance criteria

- [ ] Extraction produces identical haplotype calls to the legacy Perl pipeline on the `sebastes` reference dataset (BAM-converted)
- [ ] `testthat` tests cover: correct haplotype reconstruction from known CIGAR/sequence inputs, correct `allele.balance` and `rank` computation, empty-result handling when no reads overlap a locus
- [ ] BiocParallel parallelisation runs without error with `n.jobs > 1`
- [ ] Memory usage does not load entire BAM into RAM (verified by profiling with a 1 GB BAM)
- [ ] No dependency on Perl, shell scripts, or `.Platform$OS.type` checks

## Blocked by

- Issue #2
