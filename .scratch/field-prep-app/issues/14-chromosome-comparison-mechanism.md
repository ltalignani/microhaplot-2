Type: grilling
Status: resolved

## Question

[Validation scope](05-validation-scope.md) requires comparing VCF
chromosome/contig names against BAM reference names to catch
reference-mismatch errors, upfront and in batch. What's the exact
mechanism: where do VCF contig names come from (`##contig` header lines
vs. the observed set of column-1 values), where do BAM reference names
come from (`samtools view -H`, presumably sampled from one or a few BAM
files rather than all of them at "thousands of files" scale — how many,
and is sampling safe to assume all BAMs share one reference?), what
exactly counts as a mismatch (any VCF contig absent from the BAM
reference set? the reverse?), and how should a mismatch be reported to a
non-technical user in a way they can act on?

## Answer

- **VCF contig source**: column 1 (CHROM) of the VCF's data rows, not
  `##contig` header lines — matches what `prepHaplotFiles()` itself
  already does at the end of its pipeline (`read.table(vcf.path)[,1:2]`),
  and is more robust: the `sebastes.vcf` fixture (freebayes output) has no
  `##contig` lines at all.
- **BAM reference source**: the `@SQ` header of *every* BAM (`samtools
  view -H`), not a sample. Header-only reads are cheap (no body
  decompression), and since the truncation check
  ([validation scope](05-validation-scope.md)) already iterates every BAM
  via `samtools quickcheck`, this piggybacks on that same pass at
  near-zero extra cost — and catches the real field-work risk of two
  different panels' BAMs accidentally mixed in one batch.
- **Mismatch definition**: a VCF contig name absent from the *union* of
  all BAMs' `@SQ` names. The reverse (BAM references not used by the VCF)
  is normal, not an error.
- **Reporting**: list the missing contig names and how many BAMs are
  affected, with an actionable message (likely wrong reference/panel)
  rather than a raw technical error.
