#!/usr/bin/env bash
# Regenerates inst/extdata/sebastes_bam.tar.gz — the demo dataset the Field
# Genotyping Prep wizard is documented against in the
# "microhaplot-docker-extraction" vignette.
#
# The wizard only accepts BAM files, and validates them with `samtools
# quickcheck` plus a CHROM/@SQ comparison against the VCF. The SAM fixtures in
# sebastes_sam.tar.gz have no header at all, so they fail both checks — hence
# this conversion, and hence the out-of-band reference-size list, which is the
# same idiom tests/testthat/test-prepHaplotFiles-bam.R uses.
#
# Run from anywhere:  scripts/make-bam-fixture.sh
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

command -v samtools >/dev/null || { echo "samtools is required" >&2; exit 1; }

work=$(mktemp -d "${TMPDIR:-/tmp}/sebastes-bam.XXXXXX")
trap 'rm -rf "$work"' EXIT

tar xzf inst/extdata/sebastes_sam.tar.gz -C "$work"
cd "$work"

# Reference lengths for the @SQ header samtools has to write. Every BAM gets
# the full list, so each one's @SQ names cover all of the VCF's CHROM values
# and the wizard's chromosome-agreement check passes.
awk -F'\t' '!seen[$3]++ { print $3 "\t" 1000000 }' ./*.sam > ref_sizes.txt

for sam in ./*.sam; do
  samtools view -bt ref_sizes.txt -o "${sam%.sam}.bam" "$sam"
done

# label.txt is prepHaplotFiles()'s own headerless format (file, id, group).
# The wizard wants a header and a fourth colour column instead.
{
  printf 'bam_file\tindividual_id\tgroup\tcolor\n'
  awk -F'\t' 'BEGIN {
        OFS = "\t"
        colour["gr"] = "#1f77b4"; colour["cu"] = "#ff7f0e"
        colour["p"]  = "#2ca02c"; colour["w"]  = "#d62728"
      }
      { sub(/\.sam$/, ".bam", $1); print $1, $2, $3, colour[$3] }' label.txt
} > sebastes_metadata.tsv

tar czf "$repo_root/inst/extdata/sebastes_bam.tar.gz" \
  ./*.bam sebastes_metadata.tsv sebastes.vcf

echo "wrote inst/extdata/sebastes_bam.tar.gz"
tar tzf "$repo_root/inst/extdata/sebastes_bam.tar.gz" | wc -l | xargs echo "  entries:"
du -h "$repo_root/inst/extdata/sebastes_bam.tar.gz" | cut -f1 | xargs echo "  size:"
