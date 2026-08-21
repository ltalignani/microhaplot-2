#!/usr/bin/env bash
# Runs *inside* the `prep` container (piped in via `docker compose exec -T
# prep bash -s`). Proves microhaplot-extract (wayfinder tickets #28-#34)
# actually works inside the fully-built image, not just that the image
# builds: a real `validate` call against a known-good BAM, and a real
# `extract` batch run over the package's own bundled sebastes BAM fixture,
# written into the shared volume so the host-side smoke test script can
# diff it against the golden fixture. Independent of, and doesn't touch,
# the Perl/samtools pipeline prep-extraction.sh already exercises.
set -euo pipefail

work=$HOME/microhaplot-extract-check
out=$work/intermed

rm -rf "$work"
mkdir -p "$work" "$out"

fixture=$(Rscript -e 'cat(system.file("extdata", "sebastes_bam.tar.gz", package = "microhaplot"))')
if [ ! -f "$fixture" ]; then
  echo "bundled sebastes BAM fixture not found in the installed package" >&2
  exit 1
fi
tar xzf "$fixture" -C "$work"
cd "$work"

echo "--- microhaplot-extract validate ---"
microhaplot-extract validate --bam s11.bam > validate-out.txt
if ! grep -qx "tag_id_2301" validate-out.txt; then
  echo "validate did not report the expected @SQ reference name:" >&2
  cat validate-out.txt >&2
  exit 1
fi

echo "--- microhaplot-extract extract ---"
awk -F'\t' 'NR > 1 { print $1 "\t" $2 "\t" $3 }' sebastes_metadata.tsv > label.txt
microhaplot-extract extract \
  --label-file label.txt \
  --sample-dir "$work" \
  --vcf sebastes.vcf \
  --output-dir "$out" \
  --threads 4

if [ ! -f "$out/all.summary" ]; then
  echo "microhaplot-extract extract did not produce all.summary" >&2
  exit 1
fi

echo "microhaplot-extract check passed inside the container"
