Type: grilling
Status: open

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
