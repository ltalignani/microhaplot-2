Type: grilling
Status: open

## Question

[Metadata format is TSV](02-metadata-format.md) settled the file format
and the core columns (`bam_file`, `individual_id`, `group`). What's the
exact schema: is a header row required or forbidden (matching or diverging
from `prepHaplotFiles()`'s existing headerless `label.txt` convention),
are there any optional columns (e.g. a `color` column, mirroring
microhaplot2's metadata CSV precedent), and what are the validation rules
for each column (empty values, allowed characters, uniqueness of
`individual_id`, etc.)?
