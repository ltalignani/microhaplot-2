#!/usr/bin/env bash
# Runs *inside* the `prep` container (piped in via `docker compose exec -T
# prep bash -s`). Drives a real prepHaplotFiles() extraction over the
# package's own bundled sebastes BAM fixture, and writes the resulting .rds
# into the shared volume's Shiny app directory. Since the microhaplot-extract
# cutover (wayfinder ticket #36), prepHaplotFiles() reads BAM natively --
# no samtools in this image any more, so this uses the pre-built
# sebastes_bam.tar.gz fixture directly rather than converting from SAM.
set -euo pipefail

work=$HOME/smoke-extraction
app=$HOME/Shiny/microhaplot

rm -rf "$work"
mkdir -p "$work"

fixture=$(Rscript -e 'cat(system.file("extdata", "sebastes_bam.tar.gz", package = "microhaplot"))')
if [ ! -f "$fixture" ]; then
  echo "bundled sebastes BAM fixture not found in the installed package" >&2
  exit 1
fi
tar xzf "$fixture" -C "$work"
cd "$work"

# sebastes_metadata.tsv is the wizard's 4-column, headered format; build
# prepHaplotFiles()'s own 3-column headerless label file from it the same
# way build_prep_label_file() does.
awk -F'\t' 'NR > 1 { print $1 "\t" $2 "\t" $3 }' sebastes_metadata.tsv > label.txt

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
    label.path = file.path(work, "label.txt"),
    vcf.path   = file.path(work, "sebastes.vcf"),
    out.path   = work,
    app.path   = app)
'
