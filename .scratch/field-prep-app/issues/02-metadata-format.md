Type: grilling
Status: resolved

## Question

Should the sample metadata (BAM filename, individual ID, group) be
uploaded as CSV or TSV, and what columns does it need?

## Answer

TSV, not CSV — consistent with the existing `label.txt` format already
consumed by `prepHaplotFiles()` (itself tab-separated: filename,
individual ID, group). Exact column set/header-row question is left to
[TSV schema detail](13-tsv-schema-detail.md).
