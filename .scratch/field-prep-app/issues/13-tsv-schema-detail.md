Type: grilling
Status: resolved

## Question

[Metadata format is TSV](02-metadata-format.md) settled the file format
and the core columns (`bam_file`, `individual_id`, `group`). What's the
exact schema: is a header row required or forbidden (matching or diverging
from `prepHaplotFiles()`'s existing headerless `label.txt` convention),
are there any optional columns (e.g. a `color` column, mirroring
microhaplot2's metadata CSV precedent), and what are the validation rules
for each column (empty values, allowed characters, uniqueness of
`individual_id`, etc.)?

## Answer

**Header row: required.** Diverges from `prepHaplotFiles()`'s internal
headerless `label.txt` — the app generates that internal file from the
user-facing TSV, so the two formats don't need to match. A downloadable
template (mirroring microhaplot2's `csv_template()`/`downloadButton`
pattern) is part of this decision.

**Columns, in order:**
1. `bam_file` — the BAM's filename as it appears in the selected folder (not a full path). Required, non-empty.
2. `individual_id` — required, non-empty, must be unique across all rows.
3. `group` — may be empty or `"NA"` (matches the existing `label.txt` convention already documented in the README for "no group assigned").
4. `color` — optional. If present, must be empty or a valid `#RRGGBB` hex value; same rule as microhaplot2's `validate_color_column()` (conceptually reused — the two repos are isolated, so this is a rule to reimplement, not shared code).
