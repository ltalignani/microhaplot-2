# #7 — Module output : téléchargement tableaux brut et filtré

## What to build

A Shiny module (`outputModule`) providing CSV download of both the raw haplotype table and the filtered/curated diplotype summary.

End-to-end: the user selects which fields to include (field selector), then downloads either the raw table or the final curated microhaplotype table as a CSV file.

Key elements:
- `downloadButton()` for raw haplotype table (all reads, pre-filter).
- `downloadButton()` for filtered diplotype summary (post-filter, diploid calls: `haplotype.1`, `haplotype.2`, `read.depth.1`, `read.depth.2`, `ar`).
- Field selector (checkboxes) controlling which columns appear in the download.
- Downloads reflect the current session filter parameters.
- Downloaded filenames include the run label and download type (e.g. `sebastes_raw.csv`, `sebastes_filtered.csv`).

## Acceptance criteria

- [ ] Raw table download produces a CSV with all haplotypes before filtering
- [ ] Filtered table download produces a CSV matching the diplotype summary visible in the UI
- [ ] Field selector correctly includes/excludes columns in both downloads
- [ ] Downloaded filenames include the run label and download type
- [ ] No `shinyBS` calls remain in module code

## Blocked by

- Issue #6
