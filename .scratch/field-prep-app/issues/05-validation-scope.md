Type: grilling
Status: resolved

## Question

What validation should the app perform on the uploaded BAM/VCF/TSV inputs,
and when — is this in scope for this map at all, or deferred?

## Answer

In scope, and run as a single upfront batch pass before any call to
`prepHaplotFiles()` — not discovered lazily mid-extraction. At genuinely
large scale (thousands of samples), failing late into a long extraction
would be far more costly than failing fast up front.

Required checks:
- Every BAM file referenced in the TSV exists in the selected folder.
- VCF chromosome/contig names are compared against BAM reference names to
  catch reference-mismatch errors. Exact mechanism left to
  [chromosome-comparison mechanism](14-chromosome-comparison-mechanism.md).
- Truncated/corrupted BAM files are detected, via `samtools quickcheck`
  (checks BGZF EOF integrity without full decompression — fast even across
  thousands of files).

Detailed error-message wording/UX for non-technical users is fog, not
decided here — see the map's "Not yet specified".
