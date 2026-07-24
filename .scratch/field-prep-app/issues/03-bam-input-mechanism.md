Type: grilling
Status: resolved

## Question

For potentially thousands of BAM files, should the app use a local folder
path picker (like today's `sam.path`), or a per-file browser upload
(`fileInput`, drag-and-drop)?

## Answer

Local folder path picker, not per-file upload. Consistent with the
no-browser-upload-for-large-batches constraint already established in the
prior BAM-input effort (`notes/2026-07-24-bam-input-decision.md`) — this
app runs locally, not on a server. The TSV metadata and VCF (small, single
files) remain plain `fileInput` uploads. Exact Shiny mechanism for the
folder picker itself is left to
[folder-picker mechanism](11-folder-picker-mechanism.md).
