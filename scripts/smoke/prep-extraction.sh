#!/usr/bin/env bash
# Runs *inside* the `prep` container (piped in via `docker compose exec -T
# prep bash -s`). Drives a real prepHaplotFiles() extraction over the
# package's own bundled sebastes fixture, converted to BAM so that samtools
# is genuinely exercised, and writes the resulting .rds into the shared
# volume's Shiny app directory.
set -euo pipefail

work=$HOME/smoke-extraction
app=$HOME/Shiny/microhaplot

rm -rf "$work"
mkdir -p "$work"

fixture=$(Rscript -e 'cat(system.file("extdata", "sebastes_sam.tar.gz", package = "microhaplot"))')
if [ ! -f "$fixture" ]; then
  echo "bundled sebastes fixture not found in the installed package" >&2
  exit 1
fi
tar xzf "$fixture" -C "$work"
cd "$work"

# The bundled SAM fixtures have no header (no @SQ lines), which hapture.pl
# doesn't need but `samtools view -bt` does. Supply reference lengths
# out-of-band, as tests/testthat/test-prepHaplotFiles-bam.R does.
awk -F'\t' '!seen[$3]++ { print $3 "\t" 1000000 }' ./*.sam > ref_sizes.txt

for sam in ./*.sam; do
  samtools view -bt ref_sizes.txt "$sam" > "${sam%.sam}.bam"
done

# Point the label file at the BAMs so prepHaplotFiles() takes its BAM path.
awk -F'\t' 'BEGIN { OFS = "\t" } { sub(/\.sam$/, ".bam", $1); print }' \
  label.txt > label_bam.txt

if [ ! -d "$app" ]; then
  echo "shared Shiny app dir $app does not exist; is the main service up?" >&2
  exit 1
fi

Rscript -e '
  work <- file.path(Sys.getenv("HOME"), "smoke-extraction")
  app  <- file.path(Sys.getenv("HOME"), "Shiny", "microhaplot")
  microhaplot::prepHaplotFiles(
    run.label  = Sys.getenv("SMOKE_RUN_LABEL", "smoke"),
    sam.path   = work,
    label.path = file.path(work, "label_bam.txt"),
    vcf.path   = file.path(work, "sebastes.vcf"),
    out.path   = work,
    app.path   = app)
'
