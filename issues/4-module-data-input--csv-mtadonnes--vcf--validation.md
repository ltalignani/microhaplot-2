# #4 — Module data input : CSV métadonnées + VCF + validation

## What to build

A Shiny module (`dataInputModule`) that handles all user inputs required before extraction can run: metadata CSV, VCF file, and BAM file resolution.

End-to-end: the user uploads a CSV and a VCF, the module validates both, resolves BAM paths against the configured data directory (a `hostPath` volume in dev, the 4 TB local disk once mounted in prod), and on success triggers the extraction engine (issue #).

Key elements:
- `fileInput()` for CSV metadata upload (columns: `bam_file`, `individual_id`, `group`).
- `downloadButton()` to download a blank CSV template.
- `fileInput()` for VCF upload.
- Server-side validation: required columns present, no duplicate `individual_id`, all referenced BAM files exist in the data directory, corresponding `.bai` index files present.
- Clear inline error messages for each validation failure (replace `shinyBS` alerts with `bslib`/`shinyWidgets` equivalents).
- Progress bar (`shiny::withProgress()`) during extraction, showing per-BAM progress.
- Data directory path configurable via environment variable `MICROHAPLOT_DATA_DIR` (default: `/data/lovelace`).

## Acceptance criteria

- [ ] Valid CSV + VCF triggers extraction and returns a result tibble
- [ ] Missing required CSV column shows a specific error message naming the missing column
- [ ] Referenced BAM file absent from data directory shows an error naming the missing file
- [ ] Missing `.bai` index shows an actionable error message
- [ ] Template CSV download produces a correctly-structured empty file
- [ ] Progress bar updates during multi-BAM extraction
- [ ] `MICROHAPLOT_DATA_DIR` env var controls the BAM lookup directory

## Blocked by

- Issue #3
